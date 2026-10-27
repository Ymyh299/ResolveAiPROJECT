import 'dart:io';

import 'localizacao.dart';
import 'localizacao_dao.dart';

class LocalizacaoMenu {
  final LocalizacaoDao dao;

  /// Chamado em "Consultar patrimônios" (detalhes da localização).
  /// Aponte para o menu de patrimônios filtrado por localização.
  final Future<void> Function(Localizacao localizacao) abrirPatrimonios;

  LocalizacaoMenu(this.dao, {required this.abrirPatrimonios});

  static const int _tamanhoPagina = 10;

  // ===========================================================
  // HELPERS
  // ===========================================================

  void _cabecalho(String titulo) {
    const linha = '=================================';
    print('\n$linha');
    print(titulo.padLeft((linha.length + titulo.length) ~/ 2));
    print(linha);
  }

  String _ler([String prompt = '']) {
    if (prompt.isNotEmpty) print(prompt);
    stdout.write('> ');
    return stdin.readLineSync()?.trim() ?? '';
  }

  void _opcaoInvalida() =>
      print('Opção inválida! Selecione uma das opções disponíveis.');

  /// Lê um texto obrigatório. Retorna null se o usuário digitar 0 (cancelar).
  String? _lerObrigatorio(String prompt) {
    while (true) {
      final valor = _ler(prompt);
      if (valor == '0') return null;
      if (valor.isNotEmpty) return valor;
      print('Este campo é obrigatório. Tente novamente.');
    }
  }

  /// Confirmação [S]/[N]. Repete até receber uma resposta válida.
  bool _confirmar(String pergunta) {
    while (true) {
      print(pergunta);
      print('[S] Sim\n[N] Não');
      final r = _ler().toUpperCase();
      if (r == 'S') return true;
      if (r == 'N') return false;
      _opcaoInvalida();
    }
  }

  Future<String> _nomePai(int? paiId) async {
    if (paiId == null) return 'Nenhuma';
    final pai = await dao.buscarPorId(paiId);
    return pai?.nome ?? 'Nenhuma';
  }

  /// IDs de todos os descendentes (evita escolher um filho como "pai").
  Future<Set<int>> _descendentes(int id) async {
    final ids = <int>{};
    final fila = <int>[id];
    while (fila.isNotEmpty) {
      final atual = fila.removeLast();
      for (final filha in await dao.listarFilhas(atual)) {
        if (filha.id != null && ids.add(filha.id!)) fila.add(filha.id!);
      }
    }
    return ids;
  }

  // ===========================================================
  // MENU PRINCIPAL
  // ===========================================================

  Future<void> menuPrincipal() async {
    while (true) {
      _cabecalho('Gerenciar Localizações');
      print('1. Cadastrar Localização');
      print('2. Consultar Localização');
      print('3. Listar Localizações');
      print('4. Atualizar Localização');
      print('5. Excluir Localização');
      print('0. Voltar para Home\n');

      switch (_ler('Selecione uma opção:')) {
        case '1':
          await cadastrar();
          break;
        case '2':
          await menuConsultar();
          break;
        case '3':
          await listar();
          break;
        case '4':
          await atualizarPorId();
          break;
        case '5':
          await excluirPorId();
          break;
        case '0':
          return;
        default:
          _opcaoInvalida();
      }
    }
  }

  // ===========================================================
  // CADASTRAR
  // ===========================================================

  Future<void> cadastrar() async {
    while (true) {
      _cabecalho('Cadastrar Localização');
      print('Digite [0] para cancelar\n');

      final nome = _lerObrigatorio('Nome da localização:');
      if (nome == null) return;

      int? paiId;
      if (_confirmar(
          'Esta localização possui uma localização\nsuperior?')) {
        final pai = await selecionarPai();
        if (pai == null) return; // voltou
        paiId = pai.id;
      }

      final cadastrada = await _resumoCadastro(nome, paiId);
      if (cadastrada == null) return; // cancelou

      final repetir = await _sucessoCadastro(cadastrada);
      if (!repetir) return;
    }
  }

  /// Tela "Selecionar Localização Pai". Retorna null se o usuário voltar.
  /// [ignorarIds] impede escolher a própria localização ou seus descendentes.
  Future<Localizacao?> selecionarPai({Set<int> ignorarIds = const {}}) async {
    while (true) {
      final todas = (await dao.listarTodas())
          .where((l) => !ignorarIds.contains(l.id))
          .toList();

      _cabecalho('Selecionar Localização Pai');
      if (todas.isEmpty) {
        print('Nenhuma localização cadastrada.\n[0] Voltar');
        _ler();
        return null;
      }
      for (var i = 0; i < todas.length; i++) {
        print('[${i + 1}] ${todas[i].nome}');
      }
      print('[0] Voltar\n');

      final op = int.tryParse(_ler('Selecione a localização superior:'));
      if (op == 0) return null;
      if (op != null && op >= 1 && op <= todas.length) return todas[op - 1];
      _opcaoInvalida();
    }
  }

  /// Resumo + [1] Editar / [2] Confirmar / [0] Cancelar.
  /// Retorna a localização salva ou null se cancelou.
  Future<Localizacao?> _resumoCadastro(String nome, int? paiId) async {
    while (true) {
      _cabecalho('Resumo da Localização');
      print('Nome: $nome');
      print('Localização superior: ${await _nomePai(paiId)}\n');
      print('=================================');
      print('[1] Editar informações');
      print('[2] Confirmar cadastro');
      print('[0] Cancelar');

      switch (_ler()) {
        case '1':
          final editado = await _editarRascunho(nome, paiId);
          nome = editado.$1;
          paiId = editado.$2;
          break;
        case '2':
          return await dao.inserir(Localizacao(nome: nome, paiId: paiId));
        case '0':
          if (_confirmar('Deseja realmente cancelar o cadastro?')) return null;
          break;
        default:
          _opcaoInvalida();
      }
    }
  }

  /// Edição dos dados ainda não salvos (durante o cadastro).
  Future<(String, int?)> _editarRascunho(String nome, int? paiId) async {
    while (true) {
      _cabecalho('Editar Localização');
      print('1. Nome: $nome');
      print('2. Localização superior: ${await _nomePai(paiId)}');
      print('0. Voltar ao resumo\n');

      switch (_ler('Selecione o campo que deseja editar:')) {
        case '1':
          final novo = _lerObrigatorio('Novo nome (0 para voltar):');
          if (novo != null) nome = novo;
          break;
        case '2':
          final pai = await selecionarPai();
          if (pai != null) paiId = pai.id;
          break;
        case '0':
          return (nome, paiId);
        default:
          _opcaoInvalida();
      }
    }
  }

  /// Retorna true se o usuário quer cadastrar outra.
  Future<bool> _sucessoCadastro(Localizacao loc) async {
    while (true) {
      _cabecalho('Localização cadastrada com sucesso!');
      print('ID: #${loc.id}');
      print('Nome: ${loc.nome}\n');
      print('=================================');
      print('[1] Cadastrar outra localização');
      print('[2] Visualizar localização');
      print('[0] Voltar');

      switch (_ler()) {
        case '1':
          return true;
        case '2':
          await detalhes(loc);
          return false;
        case '0':
          return false;
        default:
          _opcaoInvalida();
      }
    }
  }

  // ===========================================================
  // CONSULTAR
  // ===========================================================

  Future<void> menuConsultar() async {
    while (true) {
      _cabecalho('Consultar Localização');
      print('1. Buscar por ID');
      print('2. Buscar por nome');
      print('3. Navegar pela hierarquia');
      print('0. Voltar\n');

      switch (_ler('Selecione uma opção:')) {
        case '1':
          await buscarPorId();
          break;
        case '2':
          await buscarPorNome();
          break;
        case '3':
          await navegarHierarquia();
          break;
        case '0':
          return;
        default:
          _opcaoInvalida();
      }
    }
  }

  Future<void> buscarPorId() async {
    final entrada = _ler('Digite o ID da localização (0 para voltar):');
    final id = int.tryParse(entrada);
    if (id == 0) return;
    final loc = id == null ? null : await dao.buscarPorId(id);
    if (loc == null) {
      print('Nenhuma localização encontrada com esse ID.');
      return;
    }
    await detalhes(loc);
  }

  Future<void> buscarPorNome() async {
    final nome = _lerObrigatorio('Digite o nome (0 para voltar):');
    if (nome == null) return;
    final resultados = await dao.buscarPorNome(nome);
    if (resultados.isEmpty) {
      print('Nenhuma localização encontrada com esse nome.');
      return;
    }
    final escolhida = await _escolherDaLista('Resultados', resultados);
    if (escolhida != null) await detalhes(escolhida);
  }

  /// Árvore de Localizações: começa nas raízes e desce pelos filhos.
  /// [paiId] null = raízes. Usado também por "Abrir sublocalizações".
  Future<void> navegarHierarquia({int? paiId}) async {
    while (true) {
      final filhas = await dao.listarFilhas(paiId);
      _cabecalho(paiId == null ? 'Árvore de Localizações' : 'Sublocalizações');

      if (filhas.isEmpty) {
        print('Nenhuma sublocalização cadastrada.\n\n[0] Voltar');
        _ler();
        return;
      }
      for (var i = 0; i < filhas.length; i++) {
        print('[${i + 1}] ${filhas[i].nome}');
      }
      print('[0] Voltar\n');

      final op = int.tryParse(_ler('Selecione uma localização:'));
      if (op == 0) return;
      if (op != null && op >= 1 && op <= filhas.length) {
        await detalhes(filhas[op - 1]);
      } else {
        _opcaoInvalida();
      }
    }
  }

  // ===========================================================
  // LISTAR (com paginação)
  // ===========================================================

  Future<void> listar() async {
    final todas = await dao.listarTodas();
    if (todas.isEmpty) {
      print('Nenhuma localização cadastrada.');
      return;
    }
    final escolhida = await _escolherDaLista('Listar Localizações', todas);
    if (escolhida != null) await detalhes(escolhida);
  }

  /// Lista paginada; retorna a escolhida ou null ao voltar.
  Future<Localizacao?> _escolherDaLista(
      String titulo, List<Localizacao> itens) async {
    var pagina = 0;
    final totalPaginas = (itens.length / _tamanhoPagina).ceil();

    while (true) {
      _cabecalho(titulo);
      final inicio = pagina * _tamanhoPagina;
      final fim = (inicio + _tamanhoPagina).clamp(0, itens.length);
      final visiveis = itens.sublist(inicio, fim);

      print('ID    Nome');
      print('-----------------------------------------');
      for (final l in visiveis) {
        print('${l.id.toString().padRight(6)}${l.nome}');
      }
      print('-----------------------------------------');
      print('Página ${pagina + 1} de $totalPaginas');
      print('[1] Visualizar localização');
      print('[2] Próxima página');
      print('[3] Página anterior');
      print('[0] Voltar\n');

      switch (_ler('Selecione uma opção:')) {
        case '1':
          final id = int.tryParse(_ler('Digite o ID da localização:'));
          final achada = visiveis.where((l) => l.id == id);
          if (achada.isNotEmpty) return achada.first;
          print('ID não encontrado nesta página.');
          break;
        case '2':
          if (pagina < totalPaginas - 1) {
            pagina++;
          } else {
            print('Você já está na última página.');
          }
          break;
        case '3':
          if (pagina > 0) {
            pagina--;
          } else {
            print('Você já está na primeira página.');
          }
          break;
        case '0':
          return null;
        default:
          _opcaoInvalida();
      }
    }
  }

  // ===========================================================
  // DETALHES DA LOCALIZAÇÃO
  // ===========================================================

  Future<void> detalhes(Localizacao loc) async {
    while (true) {
      // Recarrega para refletir edições.
      final atual = await dao.buscarPorId(loc.id!);
      if (atual == null) return; // foi excluída

      final subs = await dao.listarFilhas(atual.id);
      final qtdPatrimonios = await dao.contarPatrimonios(atual.id!);

      _cabecalho('Localização: ${atual.nome}');
      print('Localização superior: ${await _nomePai(atual.paiId)}');
      print(
          'Sublocalizações: ${subs.isEmpty ? "Nenhuma" : subs.map((s) => s.nome).join(", ")}');
      print('Patrimônios vinculados: $qtdPatrimonios\n');
      print('=================================');
      print('[1] Abrir sublocalizações');
      print('[2] Editar localização');
      print('[3] Consultar patrimônios');
      print('[4] Excluir localização');
      print('[0] Voltar\n');

      switch (_ler('Selecione uma opção:')) {
        case '1':
          await navegarHierarquia(paiId: atual.id);
          break;
        case '2':
          await atualizar(atual);
          break;
        case '3':
          await abrirPatrimonios(atual);
          break;
        case '4':
          final excluiu = await excluir(atual);
          if (excluiu) return;
          break;
        case '0':
          return;
        default:
          _opcaoInvalida();
      }
    }
  }

  // ===========================================================
  // ATUALIZAR
  // ===========================================================

  /// Entrada pelo menu principal (pede o ID).
  Future<void> atualizarPorId() async {
    final id = int.tryParse(_ler('Digite o ID da localização (0 para voltar):'));
    if (id == 0) return;
    final loc = id == null ? null : await dao.buscarPorId(id);
    if (loc == null) {
      print('Nenhuma localização encontrada com esse ID.');
      return;
    }
    await atualizar(loc);
  }

  /// Entrada pelos detalhes (já tem o objeto).
  Future<void> atualizar(Localizacao loc) async {
    while (true) {
      final atual = await dao.buscarPorId(loc.id!);
      if (atual == null) return;

      _cabecalho('Atualizar Localização');
      print('Localização: ${atual.nome}\n');
      print('1. Nome');
      print('2. Localização superior');
      print('0. Voltar\n');

      switch (_ler('Selecione o campo:')) {
        case '1':
          print('Valor atual: ${atual.nome}');
          final novoNome = _lerObrigatorio('Novo valor (0 para voltar):');
          if (novoNome == null) break;
          if (_confirmar('Deseja salvar a alteração?')) {
            await dao.atualizar(atual.copyWith(nome: novoNome));
            print('Informação atualizada!');
          }
          break;
        case '2':
          print('Valor atual: ${await _nomePai(atual.paiId)}');
          // Não permite escolher a si mesma nem um descendente (evita ciclo).
          final bloqueados = await _descendentes(atual.id!)
            ..add(atual.id!);
          final novoPai = await selecionarPai(ignorarIds: bloqueados);
          if (novoPai == null) break;
          if (_confirmar('Deseja salvar a alteração?')) {
            await dao.atualizar(atual.copyWith(paiId: novoPai.id));
            print('Informação atualizada!');
          }
          break;
        case '0':
          return;
        default:
          _opcaoInvalida();
      }
    }
  }

  // ===========================================================
  // EXCLUIR
  // ===========================================================

  Future<void> excluirPorId() async {
    final id = int.tryParse(_ler('Digite o ID da localização (0 para voltar):'));
    if (id == 0) return;
    final loc = id == null ? null : await dao.buscarPorId(id);
    if (loc == null) {
      print('Nenhuma localização encontrada com esse ID.');
      return;
    }
    await excluir(loc);
  }

  /// Retorna true se a localização foi excluída.
  Future<bool> excluir(Localizacao loc) async {
    _cabecalho('Excluir Localização');
    print('Localização: ${loc.nome}\n');
    print('ATENÇÃO: a exclusão pode ser impedida se houver');
    print('sublocalizações ou patrimônios vinculados.\n');

    if (!_confirmar('Deseja realmente excluir?')) return false;

    final filhas = await dao.contarFilhas(loc.id!);
    final patrimonios = await dao.contarPatrimonios(loc.id!);

    if (filhas > 0 || patrimonios > 0) {
      print('\nNão foi possível excluir a localização.');
      if (filhas > 0) print('Existem sublocalizações vinculadas ($filhas).');
      if (patrimonios > 0) {
        print('Existem patrimônios vinculados ($patrimonios).');
      }
      print('\nMova ou remova os vínculos antes de excluir.');
      print('\n[0] Voltar');
      _ler();
      return false;
    }

    await dao.excluir(loc.id!);
    print('Localização excluída com sucesso!\n\n[0] Voltar');
    _ler();
    return true;
  }
}