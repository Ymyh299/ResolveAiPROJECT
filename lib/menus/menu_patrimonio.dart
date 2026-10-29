import 'dart:io';

import 'package:projeto_resolveai/utils/utils.dart'; // limparTela() e pausar()

import '../models/patrimonio.dart';
import '../models/localizacao.dart';
import '../dao/patrimonio_dao.dart';
import '../dao/localizacao_dao.dart';
import '../dao/ordem_servico_dao.dart';

class MenuPatrimonio {
  static Future<int?> Function() cadastrarLocalizacao = () async => null;
  static Future<void> Function(int patrimonioId) consultarOrdensPorPatrimonio =
      (_) async {};

  static Future<void> mostrarPorLocalizacao(Localizacao loc) =>
      _navegarPorLocalizacao(loc);

  // ===========================================================================
  // 3.1 MENU DE PATRIMÔNIO
  // ===========================================================================

  static Future<void> menuPatrimonio() async {
    while (true) {
      _cabecalho('Patrimônio');
      print('1. Cadastrar Patrimônio');
      print('2. Consultar Patrimônio');
      print('3. Listar todos os Patrimônios');
      print('4. Atualizar Patrimônio');
      print('5. Excluir Patrimônio');
      print('0. Voltar para Home');
      final op = _ler('\nSelecione uma opção:');

      switch (op) {
        case '1':
          await cadastrarPatrimonio();
        case '2':
          await consultarPatrimonio();
        case '3':
          await listarPatrimonios();
        case '4':
          await atualizarPatrimonio();
        case '5':
          await excluirPatrimonio();
        case '0':
          return; // volta para quem chamou (Home)
        default:
          _opcaoInvalida();
      }
    }
  }

  // ===========================================================================
  // 3.2 CADASTRAR PATRIMÔNIO
  // ===========================================================================

  static Future<void> cadastrarPatrimonio() async {
    while (true) {
      _cabecalho('Cadastrar Patrimônio');

      final nome = _lerObrigatorio('Nome do patrimônio:');
      final descricao = _ler('\nDescrição:');
      final valor = _lerValor('\nValor do bem (R\$):');
      final dataCompra = _lerData('\nData da compra (DD/MM/AAAA):');
      final estado = _escolherEstado();

      final localizacaoId = await _escolherLocalizacaoNoCadastro();
      if (localizacaoId == null) return; // cancelou o cadastro

      final d = _DadosCadastro(
        nome,
        descricao,
        valor,
        dataCompra,
        estado,
        localizacaoId,
      );

      // Resumo + confirmação
      while (true) {
        final caminho = await LocalizacaoDao().caminhoCompleto(d.localizacaoId);

        _cabecalho('Resumo do Patrimônio');
        print('Nome: ${d.nome}');
        print('Descrição: ${_texto(d.descricao)}');
        print('Valor: R\$ ${_moeda(d.valor)}');
        print('Data da compra: ${_formatarData(d.dataCompra)}');
        print('Estado de conservação: ${d.estado}');
        print('Localização: $caminho');
        print('\n=================================');
        print('[1] Editar informações');
        print('[2] Confirmar cadastro');
        print('[0] Cancelar');
        final op = _ler('');

        if (op == '0') return;
        if (op == '2') break;
        if (op == '1') {
          await _editarDadosCadastro(d);
        } else {
          _opcaoInvalida();
        }
      }

      // Salva via DAO.
      final dao = PatrimonioDao();

      final novo = Patrimonio(
        nome: d.nome,
        localizacaoId: d.localizacaoId,
        descricao: d.descricao.isEmpty ? null : d.descricao,
        valor: d.valor,
        estadoConservacao: d.estado,
        dataCompra: d.dataCompra,
      );

      final id = await dao.inserir(novo);
      final caminho = await LocalizacaoDao().caminhoCompleto(d.localizacaoId);

      _cabecalho('Patrimônio cadastrado com sucesso!');
      print('Código do patrimônio: ${_codigo(id)}');
      print('Nome: ${novo.nome}');
      print('Localização: $caminho');

      print('\n=================================');
      print('[1] Visualizar patrimônio');
      print('[2] Cadastrar outro');
      print('[0] Voltar para Home');

      final op = _ler('');

      if (op == '2') continue;
      if (op == '1') await detalhesPatrimonio(id);

      return;
    }
  }

  /// Pergunta qual campo editar no resumo e relê só esse campo.
  static Future<void> _editarDadosCadastro(_DadosCadastro d) async {
    print('\nQual campo deseja editar?');
    print('1. Nome  2. Descrição  3. Valor');
    print('4. Data da compra  5. Estado  6. Localização');
    switch (_ler('>')) {
      case '1':
        d.nome = _lerObrigatorio('Nome do patrimônio:');
      case '2':
        d.descricao = _ler('Descrição:');
      case '3':
        d.valor = _lerValor('Valor do bem (R\$):');
      case '4':
        d.dataCompra = _lerData('Data da compra (DD/MM/AAAA):');
      case '5':
        d.estado = _escolherEstado();
      case '6':
        final id = await _escolherLocalizacaoNoCadastro();
        if (id != null) d.localizacaoId = id;
      default:
        _opcaoInvalida();
    }
  }

  /// Etapa "Localização" do cadastro: selecionar existente ou cadastrar nova.
  /// Retorna o id da localização, ou null se o usuário cancelar.
  static Future<int?> _escolherLocalizacaoNoCadastro() async {
    while (true) {
      _cabecalho('Localização do Patrimônio');
      print('[1] Selecionar localização cadastrada');
      print('[2] Cadastrar nova localização');
      print('[0] Cancelar');
      final op = _ler('\nSelecione uma opção:');

      switch (op) {
        case '1':
          final id = await _selecionarLocalizacao();
          if (id != null) return id;
        case '2':
          // Abre o formulário do módulo de Localizações (seção 6).
          // Ao terminar, volta aqui com os demais campos preservados.
          final id = await cadastrarLocalizacao();
          if (id != null) return id;
        case '0':
          return null;
        default:
          _opcaoInvalida();
      }
    }
  }

  /// Navega pelos níveis da hierarquia de localizações.
  /// A cada nível há a opção "Não especificar", que escolhe o nível atual.
  /// Retorna o id escolhido, ou null se o usuário voltar do primeiro nível.
  static Future<int?> _selecionarLocalizacao() async {
    final dao = LocalizacaoDao();
    final caminho = <Localizacao>[]; // pilha dos níveis já percorridos

    while (true) {
      final atual = caminho.isEmpty ? null : caminho.last;
      final filhos = atual == null
          ? await dao.buscarRaizes()
          : await dao.buscarFilhos(atual.id!);

      if (atual == null && filhos.isEmpty) {
        print('\nNenhuma localização cadastrada.');
        _ler('Pressione ENTER para continuar...');
        return null;
      }

      _cabecalho('Selecionar Localização');
      if (caminho.isNotEmpty) {
        print('Local: ${caminho.map((l) => l.nome).join(' > ')}\n');
      }
      for (var i = 0; i < filhos.length; i++) {
        print('[${i + 1}] ${filhos[i].nome}');
      }
      final naoEspecificar = filhos.length + 1;
      if (atual != null) print('[$naoEspecificar] Não especificar');
      print('[0] Voltar');

      final n = int.tryParse(_ler('\nSelecione uma opção:'));
      if (n == null) {
        _opcaoInvalida();
        continue;
      }
      if (n == 0) {
        if (caminho.isEmpty) return null;
        caminho.removeLast();
        continue;
      }
      if (atual != null && n == naoEspecificar) return atual.id;

      if (n >= 1 && n <= filhos.length) {
        final escolhida = filhos[n - 1];
        final sub = await dao.buscarFilhos(escolhida.id!);
        if (sub.isEmpty) return escolhida.id; // último nível
        caminho.add(escolhida); // abre o próximo nível
        continue;
      }
      _opcaoInvalida();
    }
  }

  // ===========================================================================
  // 3.3 CONSULTAR PATRIMÔNIO
  // ===========================================================================

  static Future<void> consultarPatrimonio() async {
    while (true) {
      _cabecalho('Consultar Patrimônio');
      print('1. Buscar por código');
      print('2. Buscar por nome');
      print('3. Buscar por localização');
      print('4. Buscar por estado de conservação');
      print('0. Voltar');
      final op = _ler('\nSelecione uma opção:');

      final dao = PatrimonioDao();
      List<Patrimonio> resultado = [];

      switch (op) {
        case '1':
          final id = _lerCodigo('Digite o código:');
          if (id == null) {
            _opcaoInvalida();
            continue;
          }
          final p = await dao.buscarPorId(id);
          if (p != null) resultado = [p];
        case '2':
          resultado = await dao.buscarPorNome(_ler('Digite o nome:'));
        case '3':
          final locId = await _selecionarLocalizacao();
          if (locId == null) continue;
          resultado = await dao.buscarPorLocalizacao(
            locId,
            incluirSubniveis: true,
          );
        case '4':
          resultado = await dao.buscarPorEstado(_escolherEstado());
        case '0':
          return;
        default:
          _opcaoInvalida();
          continue;
      }

      if (resultado.isEmpty) {
        print('\nNenhum patrimônio encontrado.');
        _ler('Pressione ENTER para continuar...');
        continue;
      }
      final escolhido = await _escolherPatrimonio(resultado);
      if (escolhido != null) await detalhesPatrimonio(escolhido.id!);
    }
  }

  /// Tela "Patrimônios Encontrados". Retorna o escolhido (null = voltar).
  static Future<Patrimonio?> _escolherPatrimonio(List<Patrimonio> lista) async {
    final locDao = LocalizacaoDao();
    while (true) {
      _cabecalho('Patrimônios Encontrados');
      for (var i = 0; i < lista.length; i++) {
        final p = lista[i];
        final caminho = await locDao.caminhoCompleto(p.localizacaoId);
        print('[${i + 1}] ${_codigo(p.id)} - ${p.nome}');
        print('    Localização: $caminho\n');
      }
      print('[0] Voltar');
      final n = int.tryParse(_ler('\nSelecione um patrimônio:'));
      if (n == 0) return null;
      if (n != null && n >= 1 && n <= lista.length) return lista[n - 1];
      _opcaoInvalida();
    }
  }

  // ===========================================================================
  // DETALHES DO PATRIMÔNIO
  // ===========================================================================

  static Future<void> detalhesPatrimonio(int id) async {
    while (true) {
      // Recarrega a cada volta, para refletir edições feitas na própria tela.
      final p = await PatrimonioDao().buscarPorId(id);
      if (p == null) {
        print('\nPatrimônio não encontrado (pode ter sido excluído).');
        _ler('Pressione ENTER para continuar...');
        return;
      }
      final caminho = await LocalizacaoDao().caminhoCompleto(p.localizacaoId);

      _cabecalho('Patrimônio ${_codigo(p.id)}');
      print('Nome: ${p.nome}');
      print('Descrição: ${_texto(p.descricao)}');
      print('Valor: R\$ ${_moeda(p.valor)}');
      print('Data da compra: ${_formatarData(p.dataCompra)}');
      print('Estado de conservação: ${p.estadoConservacao}');
      print('Localização: $caminho');
      print('\n=================================');
      print('[1] Editar patrimônio');
      print('[2] Alterar localização');
      print('[3] Consultar ordens de serviço');
      print('[4] Excluir patrimônio');
      print('[0] Voltar');
      final op = _ler('\nSelecione uma opção:');

      switch (op) {
        case '1':
          await _editarPatrimonio(p);
        case '2':
          await _alterarLocalizacao(p);
        case '3':
          await consultarOrdensPorPatrimonio(p.id!);
        case '4':
          final excluido = await _excluirPatrimonio(p);
          if (excluido) return; // patrimônio não existe mais
        case '0':
          return;
        default:
          _opcaoInvalida();
      }
    }
  }

  // ===========================================================================
  // 3.4 LISTAR PATRIMÔNIOS POR LOCALIZAÇÃO
  // ===========================================================================

  static Future<void> listarPatrimonios() async {
    await _navegarPorLocalizacao(null);
  }

  /// [atual] == null significa o nível raiz ("Selecione a localização").
  /// Em níveis com sublocalizações, mostra-as + a opção de ver os patrimônios
  /// diretamente na localização. Sem sublocalizações, mostra os patrimônios.
  static Future<void> _navegarPorLocalizacao(Localizacao? atual) async {
    final dao = LocalizacaoDao();

    while (true) {
      final filhos = atual == null
          ? await dao.buscarRaizes()
          : await dao.buscarFilhos(atual.id!);

      if (atual == null && filhos.isEmpty) {
        print('\nNenhuma localização cadastrada.');
        _ler('Pressione ENTER para continuar...');
        return;
      }
      if (atual != null && filhos.isEmpty) {
        await _mostrarPatrimoniosDaLocalizacao(atual);
        return;
      }

      _cabecalho(atual == null ? 'Patrimônios' : 'Patrimônios — ${atual.nome}');
      if (atual == null) print('Selecione a localização:\n');
      for (var i = 0; i < filhos.length; i++) {
        print('[${i + 1}] ${filhos[i].nome}');
      }
      final verDiretos = filhos.length + 1;
      if (atual != null) {
        print('[$verDiretos] Ver patrimônios diretamente nesta localização');
      }
      print('[0] Voltar');

      final n = int.tryParse(_ler('\nSelecione uma opção:'));
      if (n == null) {
        _opcaoInvalida();
        continue;
      }
      if (n == 0) return;
      if (atual != null && n == verDiretos) {
        await _mostrarPatrimoniosDaLocalizacao(atual);
        continue;
      }
      if (n >= 1 && n <= filhos.length) {
        await _navegarPorLocalizacao(filhos[n - 1]);
        continue;
      }
      _opcaoInvalida();
    }
  }

  static Future<void> _mostrarPatrimoniosDaLocalizacao(Localizacao loc) async {
    while (true) {
      // Recarrega a cada volta (o patrimônio pode ter sido editado/excluído).
      final lista = await PatrimonioDao().buscarPorLocalizacao(loc.id!);

      if (lista.isEmpty) {
        limparTela();
        print('\n=================================');
        print('Nenhum patrimônio cadastrado nesta');
        print('localização.');
        print('=================================\n');
        _ler('[0] Voltar');
        return;
      }

      _cabecalho('Patrimônios — ${loc.nome}');
      for (var i = 0; i < lista.length; i++) {
        print('[${i + 1}] ${lista[i].nome}');
      }
      print('[0] Voltar');
      print('\nSelecione um patrimônio para consultar os detalhes');
      final n = int.tryParse(_ler('ou 0 para voltar:'));

      if (n == 0) return;
      if (n != null && n >= 1 && n <= lista.length) {
        await detalhesPatrimonio(lista[n - 1].id!);
      } else {
        _opcaoInvalida();
      }
    }
  }

  // ===========================================================================
  // 3.5 ATUALIZAR PATRIMÔNIO
  // ===========================================================================

  /// Opção 4 do menu: pede o código e abre a edição.
  static Future<void> atualizarPatrimonio() async {
    _cabecalho('Atualizar Patrimônio');
    final id = _lerCodigo('Digite o código do patrimônio:');
    if (id == null) return _opcaoInvalida();

    final p = await PatrimonioDao().buscarPorId(id);
    if (p == null) {
      print('\nPatrimônio não encontrado.');
      _ler('Pressione ENTER para continuar...');
      return;
    }
    await _editarPatrimonio(p);
  }

  /// Edição de campos (usada pelo menu e pela tela de detalhes).
  static Future<void> _editarPatrimonio(Patrimonio inicial) async {
    final dao = PatrimonioDao();
    var atual = inicial;

    while (true) {
      _cabecalho('Editar Patrimônio');
      print('Patrimônio: ${atual.nome}\n');
      print('1. Nome');
      print('2. Descrição');
      print('3. Valor');
      print('4. Data da compra');
      print('5. Estado de conservação');
      print('6. Localização');
      print('0. Voltar');
      final campo = _ler('\nSelecione o campo:');

      if (campo == '0') return;

      if (campo == '6') {
        await _alterarLocalizacao(atual);
        final recarregado = await dao.buscarPorId(atual.id!);
        if (recarregado == null) return;
        atual = recarregado;
        continue;
      }

      Patrimonio atualizado;
      switch (campo) {
        case '1':
          print('\nValor atual: ${atual.nome}');
          atualizado = atual.copyWith(nome: _lerObrigatorio('Novo valor:'));
        case '2':
          print('\nValor atual: ${_texto(atual.descricao)}');
          atualizado = atual.copyWith(descricao: _ler('Novo valor:'));
        case '3':
          print('\nValor atual: R\$ ${_moeda(atual.valor)}');
          atualizado = atual.copyWith(valor: _lerValor('Novo valor:'));
        case '4':
          print('\nValor atual: ${_formatarData(atual.dataCompra)}');
          atualizado = atual.copyWith(
            dataCompra: _lerData('Novo valor (DD/MM/AAAA):'),
          );
        case '5':
          print('\nValor atual: ${atual.estadoConservacao}');
          atualizado = atual.copyWith(estadoConservacao: _escolherEstado());
        default:
          _opcaoInvalida();
          continue;
      }

      if (_confirmar('Deseja salvar a alteração?')) {
        await dao.atualizar(atualizado);
        atual = atualizado;
        print('\nAlteração salva com sucesso!');
      } else {
        print('\nAlteração descartada.');
      }
      pausar();
    }
  }

  /// Altera só a localização (usada na edição e nos detalhes).
  static Future<void> _alterarLocalizacao(Patrimonio p) async {
    final atual = await LocalizacaoDao().caminhoCompleto(p.localizacaoId);
    print('\nValor atual: $atual');

    final novoId = await _escolherLocalizacaoNoCadastro();
    if (novoId == null) return;

    if (_confirmar('Deseja salvar a alteração?')) {
      await PatrimonioDao().atualizar(p.copyWith(localizacaoId: novoId));
      print('\nAlteração salva com sucesso!');
    } else {
      print('\nAlteração descartada.');
    }
    pausar();
  }

  // ===========================================================================
  // 3.6 EXCLUIR PATRIMÔNIO
  // ===========================================================================

  /// Opção 5 do menu: pede o código e executa a exclusão.
  static Future<void> excluirPatrimonio() async {
    _cabecalho('Excluir Patrimônio');
    final id = _lerCodigo('Digite o código do patrimônio:');
    if (id == null) return _opcaoInvalida();

    final p = await PatrimonioDao().buscarPorId(id);
    if (p == null) {
      print('\nPatrimônio não encontrado.');
      _ler('Pressione ENTER para continuar...');
      return;
    }
    await _excluirPatrimonio(p);
  }

  /// Retorna true se o patrimônio foi excluído.
  /// Regra: com OS associada, a exclusão é impedida.
  static Future<bool> _excluirPatrimonio(Patrimonio p) async {
    final caminho = await LocalizacaoDao().caminhoCompleto(p.localizacaoId);
    print('\nPatrimônio: ${p.nome}');
    print('Localização: $caminho\n');
    print('ATENÇÃO: a exclusão pode ser impedida');
    print('se o patrimônio estiver associado a OS.');

    if (!_confirmar('Deseja realmente excluir?')) return false;

    if (await OrdemDeServicoDao().existePorPatrimonio(p.id!)) {
      print('\nNão foi possível excluir o patrimônio.');
      print('Existem ordens de serviço relacionadas.\n');
      print('Considere manter o registro para preservar');
      print('o histórico do sistema.\n');
      _ler('[0] Voltar');
      return false;
    }

    await PatrimonioDao().deletar(p.id!);
    print('\nPatrimônio excluído com sucesso!\n');
    _ler('[0] Voltar');
    return true;
  }

  // ===========================================================================
  // HELPERS PRIVADOS
  // ===========================================================================

  static String _escolherEstado() {
    while (true) {
      print('\nEstado de conservação:\n');
      for (var i = 0; i < Patrimonio.estados.length; i++) {
        print('[${i + 1}] ${Patrimonio.estados[i]}');
      }
      final n = int.tryParse(_ler('>'));
      if (n != null && n >= 1 && n <= Patrimonio.estados.length) {
        return Patrimonio.estados[n - 1];
      }
      _opcaoInvalida(pausa: false); // a lista é repetida logo abaixo
    }
  }

  /// Lê um valor monetário. Aceita "1500", "1500,50", "1.500,50" e "R$ 1500".
  static double _lerValor(String prompt) {
    while (true) {
      var t = _ler(prompt).replaceAll('R\$', '').replaceAll(' ', '');
      if (t.contains(',')) t = t.replaceAll('.', '').replaceAll(',', '.');
      final v = double.tryParse(t);
      if (v != null && v >= 0) return v;
      print('\nValor inválido. Exemplo: 1500,50');
    }
  }

  /// Lê uma data no formato DD/MM/AAAA e valida (ex: rejeita 31/02/2024).
  static DateTime _lerData(String prompt) {
    while (true) {
      final partes = _ler(prompt).split('/');
      if (partes.length == 3) {
        final d = int.tryParse(partes[0]);
        final m = int.tryParse(partes[1]);
        final a = int.tryParse(partes[2]);
        if (d != null && m != null && a != null && a >= 1900) {
          final data = DateTime(a, m, d);
          if (data.day == d && data.month == m && data.year == a) return data;
        }
      }
      print('\nData inválida. Use o formato DD/MM/AAAA.');
    }
  }

  /// Aceita "1", "001" ou "#001".
  static int? _lerCodigo(String prompt) =>
      int.tryParse(_ler(prompt).replaceAll('#', ''));

  static String _codigo(int? id) => '#${id.toString().padLeft(3, '0')}';

  static String _moeda(double? v) =>
      v == null ? '-' : v.toStringAsFixed(2).replaceAll('.', ',');

  static String _formatarData(DateTime? d) => d == null
      ? '-'
      : '${d.day.toString().padLeft(2, '0')}/'
            '${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _texto(String? valor) =>
      (valor == null || valor.isEmpty) ? '-' : valor;

  /// Lê um texto e repete a pergunta enquanto vier vazio.
  static String _lerObrigatorio(String prompt) {
    while (true) {
      final v = _ler(prompt);
      if (v.isNotEmpty) return v;
      print('\nEste campo é obrigatório.');
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
      _opcaoInvalida(pausa: false); // a pergunta é repetida logo abaixo
    }
  }

  static String _ler(String prompt) {
    if (prompt.isNotEmpty) print(prompt);
    stdout.write('> ');
    return (stdin.readLineSync() ?? '').trim();
  }

  /// Limpa a tela e mostra o título: é isso que separa uma tela da outra.
  static void _cabecalho(String titulo) {
    limparTela();
    const largura = 33;
    final pad = ((largura - titulo.length) / 2).floor().clamp(0, largura);
    print('\n=================================');
    print('${' ' * pad}$titulo');
    print('=================================\n');
  }

  /// Com [pausa] = true espera um ENTER, para a mensagem não sumir
  /// quando a próxima tela limpar o terminal.
  static void _opcaoInvalida({bool pausa = true}) {
    print('\nOpção inválida. Tente novamente.');
    if (pausa) pausar();
  }
}

/// Dados temporários usados durante o cadastro (permite editar antes de salvar).
class _DadosCadastro {
  String nome, descricao, estado;
  double valor;
  DateTime dataCompra;
  int localizacaoId;
  _DadosCadastro(
    this.nome,
    this.descricao,
    this.valor,
    this.dataCompra,
    this.estado,
    this.localizacaoId,
  );
}