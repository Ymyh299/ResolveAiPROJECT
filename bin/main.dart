import 'dart:io';

import 'package:dotenv/dotenv.dart';

import 'package:projeto_resolveai/database/conexao.dart';

import 'package:projeto_resolveai/models/usuario.dart';
import 'package:projeto_resolveai/models/setor.dart';
import 'package:projeto_resolveai/models/sessao.dart';

import 'package:projeto_resolveai/dao/usuario_dao.dart';
import 'package:projeto_resolveai/dao/setor_dao.dart';
import 'package:projeto_resolveai/dao/localizacao_dao.dart';
import 'package:projeto_resolveai/dao/material_dao.dart';
import 'package:projeto_resolveai/dao/ordem_servico_dao.dart';
import 'package:projeto_resolveai/dao/ordem_servico_material_dao.dart';
import 'package:projeto_resolveai/dao/os_apoio_dao.dart';

// ATENÇÃO: ajuste o nome da pasta "menus" se a sua for diferente.
import 'package:projeto_resolveai/menus/menu_setor.dart';
import 'package:projeto_resolveai/menus/menuusuario.dart';
import 'package:projeto_resolveai/menus/menu_patrimonio.dart';
import 'package:projeto_resolveai/menus/menulocalizacao.dart';
import 'package:projeto_resolveai/menus/menumaterial.dart';
import 'package:projeto_resolveai/menus/menuordemservico.dart';
import 'package:projeto_resolveai/menus/menuordemservicomaterial.dart';

/// Estoque menor ou igual a este valor é considerado "baixo".
const double limiteEstoqueBaixo = 10;

/// Setores e Usuários só aparecem na Home para administradores.
/// Para liberar para todos, troque para false.
const bool setoresEUsuariosSomenteAdmin = true;

// =============================================================================
// PONTO DE ENTRADA
// =============================================================================

Future<void> main() async {
  _cabecalho('Resolve Aí');
  print('Iniciando o sistema...');

  if (!await _prepararBanco()) exit(1);

  try {
    await _primeiroAcesso();
  } catch (e) {
    print('\nErro ao verificar os usuários cadastrados: $e');
    exit(1);
  }

  // Cada volta = um login. Trocar de usuário volta para cá.
  while (true) {
    final usuario = await _telaLogin();
    if (usuario == null) {
      _despedida();
      return;
    }

    Sessao.iniciar(usuario);
    await _home(usuario);
    Sessao.encerrar();
  }
}

// =============================================================================
// BANCO DE DADOS
// =============================================================================

/// Confere o .env e testa a conexão. Retorna false se não deu para conectar.
Future<bool> _prepararBanco() async {
  const obrigatorias = ['DB_HOST', 'DB_PORT', 'DB_USER', 'DB_PASSWORD', 'DB_NAME'];

  try {
    final env = DotEnv()..load();
    final faltando = obrigatorias.where((k) => (env[k] ?? '').isEmpty).toList();
    if (faltando.isNotEmpty) {
      print('\nArquivo .env ausente ou incompleto.');
      print('Faltam as variáveis: ${faltando.join(', ')}');
      print('Use o .env.example como modelo e execute o programa');
      print('a partir da pasta do projeto.');
      return false;
    }
  } catch (e) {
    print('\nNão foi possível ler o arquivo .env: $e');
    return false;
  }

  try {
    await Conexao.get();
    return true;
  } catch (e) {
    print('\nNão foi possível conectar ao banco de dados.');
    print('Verifique se o servidor está no ar e se os dados do .env estão corretos.');
    print('\nDetalhe: $e');
    return false;
  }
}

// =============================================================================
// PRIMEIRO ACESSO (nenhum usuário cadastrado)
// =============================================================================

/// Sem nenhum usuário ninguém consegue logar, então o primeiro administrador
/// é criado aqui. Se já existir algum usuário, não faz nada.
Future<void> _primeiroAcesso() async {
  final usuarioDao = UsuarioDao();
  if ((await usuarioDao.listar(limite: 1)).isNotEmpty) return;

  final setores = await SetorDao().listar();

  _cabecalho('Primeiro acesso');
  print('Nenhum usuário cadastrado ainda.');
  print('Vamos criar o administrador do sistema.');
  print('Os demais usuários podem ser cadastrados depois.');

  final d = _NovoAdmin();
  d.nome = _lerObrigatorio('\nNome completo:');
  d.cpf = _lerObrigatorio('\nCPF:');
  d.telefone = _ler('\nTelefone (opcional):');
  d.email = _lerEmail('\nE-mail:');
  d.senha = _lerNovaSenha();
  _definirSetor(d, setores);

  while (true) {
    _cabecalho('Resumo do Administrador');
    print('Nome: ${d.nome}');
    print('CPF: ${d.cpf}');
    print('Telefone: ${d.telefone.isEmpty ? '-' : d.telefone}');
    print('E-mail: ${d.email}');
    print('Senha: ********');
    print('Setor: ${d.setor?.nome ?? d.setorNovo}');
    print('Tipo: ${TipoUsuario.administrador.descricao}');
    print('\n=================================');
    print('[1] Editar informações');
    print('[2] Confirmar cadastro');
    print('[0] Cancelar (sair do sistema)');

    switch (_ler('')) {
      case '0':
        if (_confirmar('Deseja cancelar e sair do sistema?')) exit(0);
      case '1':
        _editarNovoAdmin(d, setores);
      case '2':
        if (await _salvarPrimeiroAdmin(d)) return;
      default:
        _opcaoInvalida();
    }
  }
}

/// Dados temporários do primeiro administrador (permite editar antes de salvar).
class _NovoAdmin {
  String nome = '', cpf = '', telefone = '', email = '', senha = '';
  Setor? setor; // setor já existente (ou recém-criado)
  String setorNovo = 'Administração'; // usado quando ainda não existe setor
}

void _definirSetor(_NovoAdmin d, List<Setor> setores) {
  if (setores.isEmpty) {
    final nome = _ler('\nNome do setor (ENTER = Administração):');
    d.setorNovo = nome.isEmpty ? 'Administração' : nome;
    return;
  }

  while (true) {
    print('\nEscolha o setor do administrador:');
    for (var i = 0; i < setores.length; i++) {
      print('[${i + 1}] ${setores[i].nome}');
    }
    final n = int.tryParse(_ler(''));
    if (n != null && n >= 1 && n <= setores.length) {
      d.setor = setores[n - 1];
      return;
    }
    _opcaoInvalida();
  }
}

void _editarNovoAdmin(_NovoAdmin d, List<Setor> setores) {
  print('\nQual campo deseja editar?');
  print('1. Nome  2. CPF  3. Telefone  4. E-mail');
  print('5. Senha  6. Setor');
  switch (_ler('>')) {
    case '1':
      d.nome = _lerObrigatorio('Nome completo:');
    case '2':
      d.cpf = _lerObrigatorio('CPF:');
    case '3':
      d.telefone = _ler('Telefone (opcional):');
    case '4':
      d.email = _lerEmail('E-mail:');
    case '5':
      d.senha = _lerNovaSenha();
    case '6':
      _definirSetor(d, setores);
    default:
      _opcaoInvalida();
  }
}

/// Retorna true se salvou.
Future<bool> _salvarPrimeiroAdmin(_NovoAdmin d) async {
  try {
    if (d.setor == null) {
      final setorId = await SetorDao().inserir(Setor(nome: d.setorNovo));
      // Guarda o setor criado: se o usuário falhar, não cria o setor de novo.
      d.setor = Setor(id: setorId, nome: d.setorNovo);
    }

    final id = await UsuarioDao().inserir(
      Usuario(
        nome: d.nome,
        cpf: d.cpf,
        telefone: d.telefone,
        email: d.email,
        senhaHash: Usuario.gerarHash(d.senha),
        setorId: d.setor!.id!,
        tipoUsuario: TipoUsuario.administrador,
      ),
    );

    _cabecalho('Administrador cadastrado!');
    print('ID: #$id');
    print('Nome: ${d.nome}');
    print('\nAgora entre com o e-mail e a senha cadastrados.');
    _ler('\n[0] Continuar');
    return true;
  } catch (e) {
    print('\nNão foi possível cadastrar: $e');
    _ler('Pressione ENTER para voltar ao resumo...');
    return false;
  }
}

// =============================================================================
// LOGIN
// =============================================================================

/// Retorna o usuário autenticado, ou null se a pessoa escolheu sair.
Future<Usuario?> _telaLogin() async {
  final dao = UsuarioDao();

  while (true) {
    _cabecalho('Resolve Aí - Login');
    print('Digite 0 no e-mail para sair.\n');

    final email = _ler('E-mail:');
    if (email == '0') {
      if (_confirmar('Deseja sair do sistema?')) return null;
      continue;
    }
    if (email.isEmpty) {
      print('\nInforme o e-mail.');
      continue;
    }
    final senha = _lerSenha('\nSenha:');

    try {
      final usuario = await dao.buscarPorEmail(email);
      // Mesma mensagem para e-mail inexistente e senha errada.
      if (usuario == null || !Usuario.verificarSenha(senha, usuario.senhaHash)) {
        print('\nE-mail ou senha incorretos.');
        _ler('Pressione ENTER para tentar novamente...');
        continue;
      }

      print('\nBem-vindo(a), ${usuario.nome}!');
      return usuario;
    } catch (e) {
      print('\nErro ao acessar o banco de dados: $e');
      _ler('Pressione ENTER para tentar novamente...');
    }
  }
}

// =============================================================================
// HOME
// =============================================================================

/// Tela inicial. Retorna quando o usuário escolhe "Trocar de usuário".
Future<void> _home(Usuario usuario) async {
  final menus = _montarMenus(usuario);
  final liberaAdmin = usuario.isAdmin || !setoresEUsuariosSomenteAdmin;

  while (true) {
    _cabecalho('Resolve Aí');
    print('Usuário: ${usuario.nome}');
    print('Perfil: ${usuario.tipoUsuario.descricao}\n');
    print('1. Ordens de Serviço');
    print('2. Patrimônio');
    print('3. Localizações');
    print('4. Materiais e Estoque');
    if (liberaAdmin) {
      print('5. Setores');
      print('6. Usuários');
    }
    print('9. Trocar de usuário');
    print('0. Encerrar sistema');
    final op = _ler('\nSelecione uma opção:');

    // Um erro dentro de um menu não derruba o programa: volta para a Home.
    try {
      switch (op) {
        case '1':
          await menus.ordemServico.menuPrincipal();
        case '2':
          await MenuPatrimonio.menuPatrimonio();
        case '3':
          await menus.localizacao.menuPrincipal();
        case '4':
          await menus.material.menuPrincipal();
        case '5' when liberaAdmin:
          await MenuSetor.menuSetores();
        case '6' when liberaAdmin:
          await MenuUsuario.menuUsuarios();
        case '5' || '6':
          print('\nAcesso restrito a administradores.');
        case '9':
          if (_confirmar('Deseja trocar de usuário?')) return;
        case '0':
          MenuUsuario.encerrarSistema(); // pergunta S/N; se S, encerra o programa
        default:
          _opcaoInvalida();
      }
    } catch (e) {
      print('\nOcorreu um erro inesperado: $e');
      _ler('Pressione ENTER para voltar ao menu...');
    }
  }
}

// =============================================================================
// LIGAÇÃO ENTRE OS MENUS
// =============================================================================

class _Menus {
  final OrdemDeServicoMenu ordemServico;
  final LocalizacaoMenu localizacao;
  final MaterialMenu material;
  _Menus(this.ordemServico, this.localizacao, this.material);
}

/// Cria os menus que dependem do usuário logado e conecta os callbacks.
_Menus _montarMenus(Usuario usuario) {
  final osDao = OrdemDeServicoDao();
  final apoio = OsApoioDao();
  final localizacaoDao = LocalizacaoDao();
  final materialDao = MaterialDao();
  final usoDao = OrdemDeServicoMaterialDao();

  // O menu de OS e o de materiais da OS dependem um do outro.
  late final OrdemDeServicoMenu osMenu;

  final usoMenu = OrdemServicoMaterialMenu(
    usoDao,
    materialDao,
    usuarioId: usuario.id!,
    isAdmin: usuario.isAdmin,
    limiteEstoqueBaixo: limiteEstoqueBaixo,
    // "Visualizar OS" no histórico de materiais -> detalhes da OS
    abrirOs: (osId) async {
      final os = await osDao.buscarPorId(osId);
      if (os == null) {
        print('\nOS não encontrada.');
        return;
      }
      await osMenu.detalhes(os);
    },
  );

  osMenu = OrdemDeServicoMenu(
    osDao,
    apoio,
    localizacaoDao,
    usuarioId: usuario.id!,
    usuarioNome: usuario.nome,
    isAdmin: usuario.isAdmin,
    // Detalhes da OS -> registrar materiais
    registrarMateriais: usoMenu.registrarMateriais,
    // Detalhes da OS -> consultar patrimônio
    abrirPatrimonio: MenuPatrimonio.detalhesPatrimonio,
  );

  final localizacaoMenu = LocalizacaoMenu(
    localizacaoDao,
    // Detalhes da localização -> patrimônios daquela localização
    abrirPatrimonios: MenuPatrimonio.mostrarPorLocalizacao,
  );

  final materialMenu = MaterialMenu(
    materialDao,
    limiteEstoqueBaixo: limiteEstoqueBaixo,
    historicoPorMaterial: usoMenu.historicoPorMaterial,
    historicoPorOs: usoMenu.historicoPorOs,
    historicoPorPeriodo: usoMenu.historicoPorPeriodo,
  );

  // O menu de patrimônio é estático: seus ganchos são ligados aqui.
  // Cadastro de patrimônio -> "cadastrar nova localização"
  MenuPatrimonio.cadastrarLocalizacao = localizacaoMenu.cadastrarERetornarId;
  // Detalhes do patrimônio -> ordens de serviço dele
  MenuPatrimonio.consultarOrdensPorPatrimonio =
      (patrimonioId) => _ordensDoPatrimonio(osDao, osMenu, patrimonioId);

  return _Menus(osMenu, localizacaoMenu, materialMenu);
}

/// Lista as OS de um patrimônio e abre a escolhida.
Future<void> _ordensDoPatrimonio(
  OrdemDeServicoDao dao,
  OrdemDeServicoMenu osMenu,
  int patrimonioId,
) async {
  while (true) {
    // Recarrega a cada volta: a OS pode ter sido alterada nos detalhes.
    final lista = await dao.listarPorPatrimonio(patrimonioId);

    _cabecalho('OS do Patrimônio #$patrimonioId');
    if (lista.isEmpty) {
      print('Nenhuma ordem de serviço vinculada a este patrimônio.\n');
      _ler('[0] Voltar');
      return;
    }

    for (var i = 0; i < lista.length; i++) {
      final os = lista[i];
      print('[${i + 1}] #${os.id} - ${os.titulo} (${os.status})');
    }
    print('\n[0] Voltar');

    final n = int.tryParse(_ler('\nSelecione uma OS:'));
    if (n == 0) return;
    if (n != null && n >= 1 && n <= lista.length) {
      await osMenu.detalhes(lista[n - 1]);
    } else {
      _opcaoInvalida();
    }
  }
}

// =============================================================================
// HELPERS DE CONSOLE
// =============================================================================

void _despedida() {
  _cabecalho('Sessão encerrada!');
  print('Obrigado por utilizar o Resolve Aí.\n');
  print('Até a próxima!');
  print('=================================');
}

String _ler(String prompt) {
  if (prompt.isNotEmpty) print(prompt);
  stdout.write('> ');
  final linha = stdin.readLineSync();
  if (linha == null) {
    // Entrada fechada (Ctrl+D): sem isso os laços ficariam rodando sem parar.
    print('\nEntrada encerrada. Saindo...');
    exit(0);
  }
  return linha.trim();
}

/// Lê a senha sem mostrar na tela (se o terminal permitir).
String _lerSenha(String prompt) {
  print(prompt);
  stdout.write('> ');

  var escondeu = false;
  try {
    stdin.echoMode = false;
    escondeu = true;
  } on StdinException {
    // Terminal sem suporte: a senha aparece normalmente.
  }

  final linha = stdin.readLineSync();

  if (escondeu) {
    stdin.echoMode = true;
    print('');
  }

  if (linha == null) {
    print('\nEntrada encerrada. Saindo...');
    exit(0);
  }
  return linha.trim();
}

String _lerObrigatorio(String prompt) {
  while (true) {
    final v = _ler(prompt);
    if (v.isNotEmpty) return v;
    print('\nEste campo é obrigatório.');
  }
}

String _lerEmail(String prompt) {
  while (true) {
    final v = _lerObrigatorio(prompt);
    if (v.contains('@') && v.contains('.')) return v;
    print('\nE-mail inválido.');
  }
}

/// Pede a senha duas vezes (mínimo de 6 caracteres).
String _lerNovaSenha() {
  while (true) {
    final s1 = _lerSenha('\nSenha (mínimo 6 caracteres):');
    if (s1.length < 6) {
      print('\nA senha precisa ter pelo menos 6 caracteres.');
      continue;
    }
    final s2 = _lerSenha('\nConfirme a senha:');
    if (s1 == s2) return s1;
    print('\nAs senhas não conferem. Tente novamente.');
  }
}

/// Pergunta S/N até receber resposta válida.
bool _confirmar(String pergunta) {
  while (true) {
    print('\n$pergunta');
    print('[S] Sim');
    print('[N] Não');
    final r = _ler('>').toUpperCase();
    if (r == 'S') return true;
    if (r == 'N') return false;
    _opcaoInvalida();
  }
}

void _cabecalho(String titulo) {
  const largura = 33;
  final pad = ((largura - titulo.length) / 2).floor().clamp(0, largura);
  print('\n=================================');
  print('${' ' * pad}$titulo');
  print('=================================\n');
}

void _opcaoInvalida() => print('\nOpção inválida. Tente novamente.');