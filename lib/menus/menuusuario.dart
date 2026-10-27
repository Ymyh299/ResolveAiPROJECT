import 'dart:io';

import '../models/usuario.dart';
import '../dao/usuario_dao.dart';
import '../dao/setor_dao.dart';
import '../dao/ordem_servico_dao.dart';
import '../models/sessao.dart';
import '../models/setor.dart';

/// Menus do módulo de Usuários (apenas interface de console).
/// Toda persistência é delegada aos DAOs.
class MenuUsuario {
  // ===========================================================================
  // 5.1 MENU DE USUÁRIOS
  // ===========================================================================

  static Future<void> menuUsuarios() async {
    while (true) {
      _cabecalho('Usuários');
      print('1. Cadastrar Usuário');
      print('2. Consultar Usuário');
      print('3. Listar Usuários');
      print('4. Atualizar Usuário');
      print('5. Excluir Usuário');
      print('0. Voltar para Home');
      final op = _ler('\nSelecione uma opção:');

      switch (op) {
        case '1':
          await cadastrarUsuario();
        case '2':
          await consultarUsuario();
        case '3':
          await listarUsuarios();
        case '4':
          await atualizarUsuario();
        case '5':
          await excluirUsuario();
        case '0':
          return; // volta para quem chamou (Home)
        default:
          _opcaoInvalida();
      }
    }
  }

  // ===========================================================================
  // 5.2 CADASTRAR USUÁRIO
  // ===========================================================================

  static Future<void> cadastrarUsuario() async {
    while (true) {
      _cabecalho('Cadastrar Usuário');

      final setores = await SetorDao().listar();

      final nome = _ler('Nome completo:');
      final cpf = _ler('\nCPF:');
      final telefone = _ler('\nTelefone:');
      final email = _ler('\nE-mail:');
      final senhaHash = Usuario.gerarHash(_ler('\nSenha:'));
      final setor = _escolherSetor(setores);
      final tipo = _escolherTipo();

      final dados =
          _DadosCadastro(nome, cpf, telefone, email, senhaHash, setor, tipo);

      // Resumo + confirmação
      while (true) {
        _cabecalho('Resumo do Usuário');
        print('Nome: ${dados.nome}');
        print('CPF: ${dados.cpf}');
        print('Telefone: ${dados.telefone}');
        print('E-mail: ${dados.email}');
        print('Setor: ${dados.setor.nome}');
        print('Tipo: ${dados.tipo.descricao}');
        print('\n=================================');
        print('[1] Editar informações');
        print('[2] Confirmar cadastro');
        print('[0] Cancelar');
        final op = _ler('');

        if (op == '0') return;
        if (op == '2') break;
        if (op == '1') {
          _editarDadosCadastro(dados, setores);
        } else {
          _opcaoInvalida();
        }
      }

      // Salva via DAO
      final novo = Usuario(
        nome: dados.nome,
        cpf: dados.cpf,
        telefone: dados.telefone,
        email: dados.email,
        senhaHash: dados.senhaHash,
        setorId: dados.setor.id!,
        tipoUsuario: dados.tipo,
      );
      final id = await UsuarioDao().inserir(novo);

      _cabecalho('Usuário cadastrado com sucesso!');
      print('ID: #$id');
      print('Nome: ${novo.nome}');
      print('Setor: ${dados.setor.nome}');
      print('Perfil: ${novo.tipoUsuario.descricao}');
      print('\n=================================');
      print('[1] Cadastrar outro usuário');
      print('[2] Visualizar usuário');
      print('[0] Voltar para Home');
      final op = _ler('');

      if (op == '1') continue;
      if (op == '2') await _visualizarUsuario(id);
      return;
    }
  }

  /// Pergunta qual campo editar no resumo e relê só esse campo.
  static void _editarDadosCadastro(_DadosCadastro d, List<Setor> setores) {
    print('\nQual campo deseja editar?');
    print('1. Nome  2. CPF  3. Telefone  4. E-mail');
    print('5. Senha  6. Setor  7. Tipo');
    switch (_ler('>')) {
      case '1':
        d.nome = _ler('Nome completo:');
      case '2':
        d.cpf = _ler('CPF:');
      case '3':
        d.telefone = _ler('Telefone:');
      case '4':
        d.email = _ler('E-mail:');
      case '5':
        d.senhaHash = Usuario.gerarHash(_ler('Senha:'));
      case '6':
        d.setor = _escolherSetor(setores);
      case '7':
        d.tipo = _escolherTipo();
      default:
        _opcaoInvalida();
    }
  }

  // ===========================================================================
  // 5.3 CONSULTAR USUÁRIO
  // ===========================================================================

  static Future<void> consultarUsuario() async {
    while (true) {
      _cabecalho('Consultar Usuário');
      print('1. Buscar por ID');
      print('2. Buscar por nome');
      print('3. Buscar por CPF');
      print('4. Buscar por setor');
      print('0. Voltar');
      final op = _ler('\nSelecione uma opção:');

      final dao = UsuarioDao();
      List<Usuario> resultado = [];

      switch (op) {
        case '1':
          final id = int.tryParse(_ler('Digite o ID:'));
          if (id == null) {
            _opcaoInvalida();
            continue;
          }
          final u = await dao.buscarPorId(id);
          if (u != null) resultado = [u];
        case '2':
          resultado = await dao.buscarPorNome(_ler('Digite o nome:'));
        case '3':
          final u = await dao.buscarPorCpf(_ler('Digite o CPF:'));
          if (u != null) resultado = [u];
        case '4':
          final setor = _escolherSetor(await SetorDao().listar());
          resultado = await dao.buscarPorSetor(setor.id!);
        case '0':
          return;
        default:
          _opcaoInvalida();
          continue;
      }

      if (resultado.isEmpty) {
        print('\nNenhum usuário encontrado.');
        _ler('Pressione ENTER para continuar...');
        continue;
      }
      if (resultado.length == 1) {
        await _visualizarUsuario(resultado.first.id!);
      } else {
        await _imprimirTabela(resultado);
        final id =
            int.tryParse(_ler('\nDigite o ID para visualizar (0 = voltar):'));
        if (id != null && id != 0) await _visualizarUsuario(id);
      }
    }
  }

  // ===========================================================================
  // 5.4 LISTAR USUÁRIOS (paginado)
  // ===========================================================================

  static Future<void> listarUsuarios() async {
    const porPagina = 10;
    var pagina = 0;
    final dao = UsuarioDao();

    while (true) {
      final lista =
          await dao.listar(limite: porPagina, offset: pagina * porPagina);

      _cabecalho('Listar Usuários');
      if (lista.isEmpty) {
        print('Nenhum usuário nesta página.');
      } else {
        await _imprimirTabela(lista, comCabecalho: false);
      }
      print('\nPágina ${pagina + 1}');
      print('-----------------------------------------');
      print('[1] Visualizar usuário');
      print('[2] Próxima página');
      print('[3] Página anterior');
      print('[0] Voltar');
      final op = _ler('\nSelecione uma opção:');

      switch (op) {
        case '1':
          final id = int.tryParse(_ler('Digite o ID:'));
          if (id != null) await _visualizarUsuario(id);
        case '2':
          if (lista.length == porPagina) {
            pagina++;
          } else {
            print('Esta é a última página.');
          }
        case '3':
          if (pagina > 0) pagina--;
        case '0':
          return;
        default:
          _opcaoInvalida();
      }
    }
  }

  // ===========================================================================
  // 5.5 ATUALIZAR USUÁRIO
  // ===========================================================================

  static Future<void> atualizarUsuario() async {
    _cabecalho('Atualizar Usuário');
    final id = int.tryParse(_ler('Digite o ID do usuário:'));
    if (id == null) return _opcaoInvalida();

    final dao = UsuarioDao();
    var usuario = await dao.buscarPorId(id);
    if (usuario == null) {
      print('\nUsuário não encontrado.');
      _ler('Pressione ENTER para continuar...');
      return;
    }

    while (true) {
      print('\nUsuário: ${usuario!.nome}\n');
      print('1. Nome');
      print('2. Telefone');
      print('3. E-mail');
      print('4. Senha');
      print('5. Setor');
      print('6. Tipo de usuário');
      print('0. Voltar');
      final campo = _ler('\nSelecione o campo:');

      if (campo == '0') return;
      if (!const ['1', '2', '3', '4', '5', '6'].contains(campo)) {
        _opcaoInvalida();
        continue;
      }

      // Alteração de perfil restrita a administradores
      if (campo == '6' && !(Sessao.usuarioLogado?.isAdmin ?? false)) {
        print('\nApenas administradores podem alterar o tipo de usuário.');
        _ler('Pressione ENTER para continuar...');
        continue;
      }

      Usuario atualizado;
      switch (campo) {
        case '1':
          atualizado = usuario.copyWith(nome: _ler('\nNovo valor:'));
        case '2':
          atualizado = usuario.copyWith(telefone: _ler('\nNovo valor:'));
        case '3':
          atualizado = usuario.copyWith(email: _ler('\nNovo valor:'));
        case '4':
          atualizado =
              usuario.copyWith(senhaHash: Usuario.gerarHash(_ler('\nNovo valor:')));
        case '5':
          final setor = _escolherSetor(await SetorDao().listar());
          atualizado = usuario.copyWith(setorId: setor.id);
        default: // '6'
          atualizado = usuario.copyWith(tipoUsuario: _escolherTipo());
      }

      if (_confirmar('Deseja salvar a alteração?')) {
        await dao.atualizar(atualizado);
        usuario = atualizado;
        print('\nAlteração salva com sucesso!');
      } else {
        print('\nAlteração descartada.');
      }
    }
  }

  // ===========================================================================
  // 5.6 EXCLUIR USUÁRIO
  // ===========================================================================

  static Future<void> excluirUsuario() async {
    _cabecalho('Excluir Usuário');
    final id = int.tryParse(_ler('Digite o ID do usuário:'));
    if (id == null) return _opcaoInvalida();

    final usuario = await UsuarioDao().buscarPorId(id);
    if (usuario == null) {
      print('\nUsuário não encontrado.');
      _ler('Pressione ENTER para continuar...');
      return;
    }

    print('\nUsuário: ${usuario.nome}\n');
    print('ATENÇÃO: a exclusão pode ser impedida');
    print('se o usuário estiver associado a OS.');

    if (!_confirmar('Deseja Excluir este usuário?')) return;

    if (await OrdemDeServicoDao().existePorUsuario(id)) {
      print('\nNão foi possível excluir o usuário.');
      print('Existem ordens de serviço relacionadas.\n');
      print('Considere manter o registro para preservar');
      print('o histórico do sistema.\n');
    } else {
      await UsuarioDao().excluir(id);
      print('\nUsuário excluído com sucesso!\n');
    }
    print('[0] Voltar');
    _ler('');
  }

  // ===========================================================================
  // 9.2 ENCERRAR O SISTEMA
  // ===========================================================================

  /// Retorna normalmente se responder N (volta à Home).
  /// Encerra o processo se responder S.
  static void encerrarSistema() {
    _cabecalho('Encerrar Resolve Aí');
    if (!_confirmar('Deseja realmente sair do sistema?')) return;

    _cabecalho('Sessão encerrada!');
    print('Obrigado por utilizar o Resolve Aí.\n');
    print('Até a próxima!');
    print('=================================');
    exit(0);
  }

  // ===========================================================================
  // HELPERS PRIVADOS
  // ===========================================================================

  static Future<void> _visualizarUsuario(int id) async {
    final u = await UsuarioDao().buscarPorId(id);
    if (u == null) {
      print('\nUsuário não encontrado.');
      _ler('Pressione ENTER para continuar...');
      return;
    }
    final setor = await SetorDao().buscarPorId(u.setorId);
    final d = u.dataCadastro;
    _cabecalho('Dados do Usuário');
    print('ID: #${u.id}');
    print('Nome: ${u.nome}');
    print('CPF: ${u.cpf}');
    print('Telefone: ${u.telefone}');
    print('E-mail: ${u.email}');
    print('Setor: ${setor?.nome ?? '-'}');
    print('Perfil: ${u.tipoUsuario.descricao}');
    print('Cadastro: ${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}');
    _ler('\n[0] Voltar');
  }

  static Future<void> _imprimirTabela(List<Usuario> lista,
      {bool comCabecalho = true}) async {
    if (comCabecalho) _cabecalho('Resultado');
    print('ID    Nome                 Setor');
    print('-----------------------------------------');
    final setorDao = SetorDao();
    for (final u in lista) {
      final setor = await setorDao.buscarPorId(u.setorId);
      print('${u.id.toString().padRight(6)}'
          '${u.nome.padRight(21)}'
          '${setor?.nome ?? '-'}');
    }
  }

  static Setor _escolherSetor(List<Setor> setores) {
    while (true) {
      print('\nSetor:');
      for (var i = 0; i < setores.length; i++) {
        print('[${i + 1}] ${setores[i].nome}');
      }
      final n = int.tryParse(_ler('>'));
      if (n != null && n >= 1 && n <= setores.length) return setores[n - 1];
      _opcaoInvalida();
    }
  }

  static TipoUsuario _escolherTipo() {
    while (true) {
      print('\nTipo de usuário:');
      for (final t in TipoUsuario.values) {
        print('[${t.codigo}] ${t.descricao}');
      }
      final n = int.tryParse(_ler('>'));
      if (n == 1 || n == 2) return TipoUsuario.fromCodigo(n!);
      _opcaoInvalida();
    }
  }

  /// Pergunta S/N até receber resposta válida.
  static bool _confirmar(String pergunta) {
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

  static String _ler(String prompt) {
    if (prompt.isNotEmpty) print(prompt);
    stdout.write('> ');
    return (stdin.readLineSync() ?? '').trim();
  }

  static void _cabecalho(String titulo) {
    const largura = 33;
    final pad = ((largura - titulo.length) / 2).floor().clamp(0, largura);
    print('\n=================================');
    print('${' ' * pad}$titulo');
    print('=================================\n');
  }

  static void _opcaoInvalida() => print('\nOpção inválida. Tente novamente.');
}

/// Dados temporários usados durante o cadastro (permite editar antes de salvar).
class _DadosCadastro {
  String nome, cpf, telefone, email, senhaHash;
  Setor setor;
  TipoUsuario tipo;
  _DadosCadastro(this.nome, this.cpf, this.telefone, this.email, this.senhaHash,
      this.setor, this.tipo);
}