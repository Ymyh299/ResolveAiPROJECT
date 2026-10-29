import 'dart:io';

import 'package:projeto_resolveai/utils/utils.dart'; // limparTela() e pausar()

import '../models/localizacao.dart';
import '../dao/localizacao_dao.dart';
import '../models/ordemdeservico.dart';
import '../dao/ordem_servico_dao.dart';
import '../dao/os_apoio_dao.dart';

// ===========================================================
// NAVEGAÇÃO DO ASSISTENTE (Nova OS): "0" cancela, "Voltar" volta
// ===========================================================

enum _Nav { voltar, cancelar }

class _Navegacao implements Exception {
  final _Nav tipo;
  const _Navegacao(this.tipo);
}

// ===========================================================
// RASCUNHO: dados editáveis da OS (nova ou existente)
// ===========================================================

class _RascunhoOs {
  String titulo = '';
  String? observacao;
  String prioridade = 'Média';
  String tipo = OrdemDeServico.corretiva;
  int? setorId;
  int? localizacaoId;
  int? patrimonioId;
  int? executorId;
  DateTime? prazo;
  int? intervaloDias;
  int? duracaoDias;
  DateTime? proximaData;
  final int solicitanteId;
  bool alterado = false;

  _RascunhoOs(this.solicitanteId);

  factory _RascunhoOs.de(OrdemDeServico os) {
    return _RascunhoOs(os.solicitanteId)
      ..titulo = os.titulo
      ..observacao = os.observacao
      ..prioridade = os.prioridade
      ..tipo = os.tipoManutencao
      ..setorId = os.setorId
      ..localizacaoId = os.localizacaoId
      ..patrimonioId = os.patrimonioId
      ..executorId = os.executorId
      ..prazo = os.prazoPrevisto
      ..intervaloDias = os.intervaloDias
      ..duracaoDias = os.duracaoDias
      ..proximaData = os.proximaData;
  }

  bool get preventiva => tipo == OrdemDeServico.preventiva;

  void limparRecorrencia() {
    intervaloDias = null;
    duracaoDias = null;
    proximaData = null;
  }

  /// [base] = OS existente (preserva id, datas e status). Sem base = OS nova.
  OrdemDeServico construir({OrdemDeServico? base}) {
    return OrdemDeServico(
      id: base?.id,
      titulo: titulo,
      observacao: observacao,
      dataAbertura: base?.dataAbertura,
      dataInicio: base?.dataInicio,
      dataFim: base?.dataFim,
      prazoPrevisto: prazo,
      prioridade: prioridade,
      status: base?.status ?? OrdemDeServico.statusAberta,
      tipoManutencao: tipo,
      recorrente: preventiva,
      intervaloDias: preventiva ? intervaloDias : null,
      duracaoDias: preventiva ? duracaoDias : null,
      proximaData: preventiva ? proximaData : null,
      solicitanteId: solicitanteId,
      executorId: executorId,
      setorId: setorId!,
      localizacaoId: localizacaoId!,
      patrimonioId: patrimonioId,
    );
  }
}

// ===========================================================
// MENU
// ===========================================================

class OrdemDeServicoMenu {
  final OrdemDeServicoDao dao;
  final OsApoioDao apoio;
  final LocalizacaoDao localizacaoDao;

  /// Usuário logado (vem da tela de login).
  final int usuarioId;
  final String usuarioNome;
  final bool isAdmin;

  /// "Registrar materiais utilizados" (tela de detalhes) -> menu de Materiais.
  final Future<void> Function(OrdemDeServico os) registrarMateriais;

  /// "Consultar patrimônio" (tela de detalhes) -> menu de Patrimônio.
  final Future<void> Function(int patrimonioId) abrirPatrimonio;

  OrdemDeServicoMenu(
    this.dao,
    this.apoio,
    this.localizacaoDao, {
    required this.usuarioId,
    required this.usuarioNome,
    required this.isAdmin,
    required this.registrarMateriais,
    required this.abrirPatrimonio,
  });

  static const int _tamanhoPagina = 10;

  // ----- Regras de permissão (centralizadas: ajuste aqui) -----
  bool _podeEditar(OrdemDeServico os) =>
      isAdmin || os.solicitanteId == usuarioId;

  bool _podeAlterarStatus(OrdemDeServico os) =>
      isAdmin ||
      os.executorId == usuarioId ||
      os.executorId == null;

  bool get _podeAlterarExecutor => isAdmin;

  // ===========================================================
  // HELPERS DE CONSOLE
  // ===========================================================

  /// Limpa a tela e mostra o título: é isso que separa uma tela da outra.
  void _cabecalho(String titulo) {
    limparTela();
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

  /// Com [pausa] = true espera um ENTER, para a mensagem não sumir
  /// quando a próxima tela limpar o terminal. Use pausa: false quando
  /// a pergunta é repetida logo abaixo, sem redesenhar a tela.
  void _opcaoInvalida({bool pausa = true}) {
    print('Opção inválida! Selecione uma das opções disponíveis.');
    if (pausa) pausar();
  }

  bool _confirmar(String pergunta) {
    while (true) {
      print(pergunta);
      print('[S] Sim\n[N] Não');
      final r = _ler().toUpperCase();
      if (r == 'S') return true;
      if (r == 'N') return false;
      _opcaoInvalida(pausa: false);
    }
  }

  /// Leitura bruta. No assistente, "0" cancela e "Voltar" volta.
  String _lerRaw(String prompt, {bool wizard = false}) {
    final raw = _ler(prompt);
    if (wizard) {
      if (raw == '0') throw const _Navegacao(_Nav.cancelar);
      if (raw.toLowerCase() == 'voltar') throw const _Navegacao(_Nav.voltar);
    }
    return raw;
  }

  String _lerTexto(String prompt, {bool wizard = false}) {
    while (true) {
      final v = _lerRaw(prompt, wizard: wizard);
      if (v.isNotEmpty) return v;
      print('Este campo é obrigatório. Tente novamente.');
    }
  }

  String? _lerTextoOpcional(String prompt, {bool wizard = false}) {
    final v = _lerRaw('$prompt (Enter para pular)', wizard: wizard);
    return v.isEmpty ? null : v;
  }

  int _lerInteiroPositivo(String prompt, {bool wizard = false}) {
    while (true) {
      final v = int.tryParse(_lerRaw(prompt, wizard: wizard));
      if (v != null && v > 0) return v;
      print('Valor inválido! Digite um número inteiro maior que zero.');
    }
  }

  /// DD/MM/AAAA. Rejeita datas inexistentes (31/02).
  DateTime? _lerData(
    String prompt, {
    bool opcional = false,
    bool wizard = false,
    bool permitirPassado = true,
  }) {
    while (true) {
      final raw = _lerRaw(
        opcional ? '$prompt (Enter para pular)' : prompt,
        wizard: wizard,
      );
      if (raw.isEmpty && opcional) return null;

      final p = raw.split('/');
      if (p.length == 3) {
        final d = int.tryParse(p[0]);
        final m = int.tryParse(p[1]);
        final a = int.tryParse(p[2]);
        if (d != null && m != null && a != null && a > 1900) {
          final data = DateTime(a, m, d);
          if (data.day == d && data.month == m && data.year == a) {
            final agora = DateTime.now();
            final hoje = DateTime(agora.year, agora.month, agora.day);
            if (!permitirPassado && data.isBefore(hoje)) {
              print('A data não pode ser anterior a hoje.');
              continue;
            }
            return data;
          }
        }
      }
      print('Data inválida! Use o formato DD/MM/AAAA.');
    }
  }

  /// Mostra [1]..[n] e lê a escolha. Retorna o índice (0-based) ou null (voltar).
  int? _escolherOpcao(List<String> opcoes, {bool wizard = false}) {
    while (true) {
      for (var i = 0; i < opcoes.length; i++) {
        print('[${i + 1}] ${opcoes[i]}');
      }
      if (!wizard) print('[0] Voltar');
      print('');
      final raw = _lerRaw('Selecione uma opção:', wizard: wizard);
      final op = int.tryParse(raw);
      if (op == 0) return null;
      if (op != null && op >= 1 && op <= opcoes.length) return op - 1;
      _opcaoInvalida(pausa: false); // a lista é repetida logo abaixo
    }
  }

  String _data(DateTime? d) => d == null
      ? '—'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _dataHora(DateTime? d) => d == null
      ? '—'
      : '${_data(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _cortar(String s, int n) =>
      s.length <= n ? s : '${s.substring(0, n - 1)}…';

  Future<String> _nomeUsuario(int? id, [String vazio = 'Não definido']) async {
    if (id == null) return vazio;
    return await apoio.nomeUsuario(id) ?? '—';
  }

  Future<String> _nomeSetor(int? id) async =>
      id == null ? '—' : await apoio.nomeSetor(id) ?? '—';

  Future<String> _nomeLocalizacao(int? id) async =>
      id == null ? '—' : (await localizacaoDao.buscarPorId(id))?.nome ?? '—';

  Future<String> _nomePatrimonio(int? id) async =>
      id == null ? 'Não especificado' : await apoio.nomePatrimonio(id) ?? '—';

  String _statusTexto(OrdemDeServico os) =>
      os.status + (os.atrasada ? ' (ATRASADA)' : '');

  OrdemDeServico? _construirValidando(_RascunhoOs d, {OrdemDeServico? base}) {
    try {
      final os = d.construir(base: base);
      os.validar();
      return os;
    } on ArgumentError catch (e) {
      print('Não foi possível continuar: ${e.message}');
      pausar();
      return null;
    }
  }

  // ===========================================================
  // MENU PRINCIPAL
  // ===========================================================

  Future<void> menuPrincipal() async {
    while (true) {
      _cabecalho('Ordens de Serviço');
      print('1. Nova Ordem de Serviço');
      print('2. Consultar Ordens de Serviço');
      print('3. Listar todas as Ordens');
      print('4. OS associadas a mim');
      print('5. Excluir ordens de serviço (somente ADMIN)');
      print('0. Voltar para Home\n');

      switch (_ler('Selecione uma opção:')) {
        case '1':
          await novaOs();
          break;
        case '2':
          await menuConsultar();
          break;
        case '3':
          await menuListar();
          break;
        case '4':
          await menuMinhasOs();
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
  // NOVA OS (assistente em 3 etapas + executor + resumo)
  // ===========================================================

  Future<void> novaOs() async {
    while (true) {
      final salva = await _assistente();
      if (salva == null) return; // cancelou
      final outra = await _sucessoCadastro(salva);
      if (!outra) return;
    }
  }

  /// Retorna a OS salva, ou null se o usuário cancelou.
  Future<OrdemDeServico?> _assistente() async {
    final d = _RascunhoOs(usuarioId);
    var etapa = 1;

    while (true) {
      try {
        switch (etapa) {
          case 1:
            await _etapa1(d);
            etapa = 2;
            break;
          case 2:
            await _etapa2(d);
            etapa = 3;
            break;
          case 3:
            await _etapa3(d);
            etapa = 4;
            break;
          case 4:
            // Executor ("Voltar" retorna à etapa 3)
            if (!await _campoExecutor(d)) throw const _Navegacao(_Nav.voltar);
            etapa = 5;
            break;
          case 5:
            return await _resumo(d);
        }
      } on _Navegacao catch (n) {
        if (n.tipo == _Nav.cancelar) {
          if (_confirmar('Deseja realmente cancelar o cadastro?')) return null;
        } else if (etapa > 1) {
          etapa--;
        }
      }
    }
  }

  void _cabecalhoEtapa(int n, String nome, {bool podeVoltar = true}) {
    _cabecalho('Nova Ordem de Serviço');
    print('Etapa $n de 3 -- $nome');
    print(
      podeVoltar
          ? 'Digite [0] para cancelar e "Voltar" para voltar\n'
          : 'Digite [0] para cancelar\n',
    );
  }

  // ----- Etapa 1: Dados do serviço -----
  Future<void> _etapa1(_RascunhoOs d) async {
    _cabecalhoEtapa(1, 'Dados do Serviço', podeVoltar: false);

    d.titulo = _lerTexto('Título da OS:', wizard: true);
    d.observacao = _lerTextoOpcional('Descrição do problema:', wizard: true);

    print('\nPrioridade:');
    final p = _escolherOpcao(OrdemDeServico.prioridadesValidas, wizard: true)!;
    d.prioridade = OrdemDeServico.prioridadesValidas[p];

    print('\nTipo de manutenção:');
    final t = _escolherOpcao(OrdemDeServico.tiposValidos, wizard: true)!;
    final novoTipo = OrdemDeServico.tiposValidos[t];
    if (novoTipo != d.tipo) d.limparRecorrencia();
    d.tipo = novoTipo;

    print('\n---------------------------------');
    print('[1] Continuar\n[0] Cancelar');
    while (true) {
      final r = _ler();
      if (r == '1') return;
      if (r == '0') throw const _Navegacao(_Nav.cancelar);
      _opcaoInvalida(pausa: false); // volta a ler o mesmo menu
    }
  }

  // ----- Etapa 2: Responsáveis e local -----
  Future<void> _etapa2(_RascunhoOs d) async {
    _cabecalhoEtapa(2, 'Responsáveis e Local');
    while (true) {
      await _campoSetor(d, wizard: true);
      // Se o usuário voltar na tela de localização, pergunta o setor de novo.
      if (await _campoLocalizacao(d)) return;
    }
  }

  // ----- Etapa 3: Prazo e confirmação -----
  Future<void> _etapa3(_RascunhoOs d) async {
    _cabecalhoEtapa(3, 'Prazo e Confirmação');

    // Prazo é definido apenas pelo Administrador (regra do objeto).
    if (isAdmin) {
      d.prazo = _lerData(
        'Prazo previsto (DD/MM/AAAA):',
        opcional: true,
        wizard: true,
        permitirPassado: false,
      );
    }

    // Preventiva é sempre recorrente (exigência do validar()).
    if (d.preventiva) {
      print('\nManutenção preventiva: recorrência obrigatória.');
      await _campoRecorrencia(d, wizard: true);
    }
  }

  // ===========================================================
  // CAMPOS REUTILIZÁVEIS (assistente e edição)
  // ===========================================================

  /// Retorna false se o usuário voltou sem escolher (só fora do assistente).
  Future<bool> _campoSetor(_RascunhoOs d, {bool wizard = false}) async {
    final setores = await apoio.listarSetores();
    if (setores.isEmpty) {
      print('Nenhum setor cadastrado. Cadastre um setor antes.');
      if (wizard) throw const _Navegacao(_Nav.cancelar);
      pausar();
      return false;
    }
    print('\nSetor responsável:');
    final i = _escolherOpcao(
      setores.map((s) => s.nome).toList(),
      wizard: wizard,
    );
    if (i == null) return false;
    d.setorId = setores[i].id;
    return true;
  }

  Future<void> _campoRecorrencia(_RascunhoOs d, {bool wizard = false}) async {
    d.intervaloDias = _lerInteiroPositivo(
      'Intervalo entre manutenções (dias):',
      wizard: wizard,
    );
    d.duracaoDias = _lerInteiroPositivo(
      'Duração de cada manutenção (dias):',
      wizard: wizard,
    );
    d.proximaData = _lerData(
      'Próxima manutenção (DD/MM/AAAA):',
      wizard: wizard,
      permitirPassado: false,
    );
  }

  // ----- Localização (hierarquia) + Patrimônio -----

  /// Fluxo Localização -> Patrimônio. Retorna false se o usuário saiu
  /// pelo "Voltar" da primeira tela.
  Future<bool> _campoLocalizacao(_RascunhoOs d) async {
    while (true) {
      final loc = await _navegarLocalizacao();
      if (loc == null) return false;

      final r = await _escolherPatrimonio(loc);
      if (r.escolheu) {
        d.localizacaoId = loc.id;
        d.patrimonioId = r.patrimonioId;
        return true;
      }
      // "Voltar" / "Escolher outra localização": repete a escolha.
    }
  }

  //  Desce pela hierarquia. Folhas são escolhidas direto; em um nível
  // intermediário há a opção "Usar <esta localização>".
  Future<Localizacao?> _navegarLocalizacao() async {
    final pilha = <Localizacao>[];
    while (true) {
      final atual = pilha.isEmpty ? null : pilha.last;
      final filhas = await localizacaoDao.listarFilhas(atual?.id);

      _cabecalho(atual == null ? 'Localização' : atual.nome);
      if (filhas.isEmpty && atual == null) {
        print('Nenhuma localização cadastrada.');
        pausar();
        return null;
      }
      for (var i = 0; i < filhas.length; i++) {
        print('[${i + 1}] ${filhas[i].nome}');
      }
      final usarEsta = filhas.length + 1;
      if (atual != null) print('[$usarEsta] Usar "${atual.nome}"');
      print('[0] Voltar\n');

      final op = int.tryParse(_ler('Selecione uma opção:'));
      if (op == 0) {
        if (pilha.isEmpty) return null;
        pilha.removeLast();
      } else if (op != null && op >= 1 && op <= filhas.length) {
        final escolhida = filhas[op - 1];
        if (await localizacaoDao.contarFilhas(escolhida.id!) == 0) {
          return escolhida;
        }
        pilha.add(escolhida);
      } else if (atual != null && op == usarEsta) {
        return atual;
      } else {
        _opcaoInvalida();
      }
    }
  }

  Future<({bool escolheu, int? patrimonioId})> _escolherPatrimonio(
    Localizacao loc,
  ) async {
    final pats = await apoio.listarPatrimoniosPorLocalizacao(loc.id!);

    if (pats.isEmpty) {
      _cabecalho('Patrimônio');
      print('Local selecionado: ${loc.nome}\n');
      print('Nenhum patrimônio cadastrado nesta localização.\n');
      print('[1] Continuar sem patrimônio específico');
      print('[2] Escolher outra localização');
      print('[0] Voltar');
      while (true) {
        switch (_ler()) {
          case '1':
            return (escolheu: true, patrimonioId: null);
          case '2':
          case '0':
            return (escolheu: false, patrimonioId: null);
          default:
            _opcaoInvalida(pausa: false); // volta a ler o mesmo menu
        }
      }
    }

    while (true) {
      _cabecalho('Patrimônio');
      print('Local selecionado: ${loc.nome}\n');
      print('[1] Não específico');
      for (var i = 0; i < pats.length; i++) {
        print('[${i + 2}] ${pats[i].nome}');
      }
      print('\n[0] Voltar\n');

      final op = int.tryParse(_ler('Selecione uma opção:'));
      if (op == 0) return (escolheu: false, patrimonioId: null);
      if (op == 1) return (escolheu: true, patrimonioId: null);
      if (op != null && op >= 2 && op <= pats.length + 1) {
        return (escolheu: true, patrimonioId: pats[op - 2].id);
      }
      _opcaoInvalida();
    }
  }

  /// Troca só o patrimônio, dentro da localização atual do rascunho.
  Future<bool> _campoPatrimonio(_RascunhoOs d) async {
    final loc = await localizacaoDao.buscarPorId(d.localizacaoId!);
    if (loc == null) return false;
    final r = await _escolherPatrimonio(loc);
    if (!r.escolheu) return false;
    d.patrimonioId = r.patrimonioId;
    return true;
  }

  // ----- Executor -----

  /// Sugestão automática -> [1] Confirmar / [2] Escolher outro / [0] Voltar.
  /// Retorna false se o usuário voltou.
  Future<bool> _campoExecutor(_RascunhoOs d) async {
    _cabecalho('Executor da OS');
    print('O sistema está identificando o executor');
    print('mais adequado para esta solicitação...\n');

    final sugestao = await apoio.sugerirExecutor(d.setorId!);
    if (sugestao == null) {
      print('Nenhum executor sugerido para este setor.');
      pausar();
      final e = await _selecionarExecutor();
      if (e == null) return false;
      d.executorId = e.id;
      return true;
    }

    while (true) {
      print('Executor selecionado: ${sugestao.nome}');
      print('Setor: ${sugestao.setorNome}\n');
      print('[1] Confirmar executor');
      print('[2] Escolher outro executor');
      print('[3] Deixar sem executor (alguém assume depois)');
      print('[0] Voltar\n');

      switch (_ler('Selecione uma opção:')) {
        case '1':
          d.executorId = sugestao.id;
          return true;
        case '2':
          final e = await _selecionarExecutor();
          if (e != null) {
            d.executorId = e.id;
            return true;
          }
          break;
        case '3':
          d.executorId = null;
          return true;
        case '0':
          return false;
        default:
          _opcaoInvalida();
      }
      // Chegou aqui = vai repetir a tela: limpa e redesenha o título.
      _cabecalho('Executor da OS');
    }
  }

  Future<ExecutorRef?> _selecionarExecutor() async {
    while (true) {
      _cabecalho('Selecionar Executor');
      print('[1] Buscar por nome');
      print('[2] Listar executores disponíveis');
      print('[0] Voltar\n');

      switch (_ler('Selecione uma opção:')) {
        case '1':
          final nome = _ler('Digite o nome do executor:');
          if (nome.isEmpty) break;
          final e = await _escolherExecutor(
            await apoio.buscarExecutoresPorNome(nome),
          );
          if (e != null) return e;
          break;
        case '2':
          final e = await _escolherExecutor(
            await apoio.listarExecutoresDisponiveis(),
          );
          if (e != null) return e;
          break;
        case '0':
          return null;
        default:
          _opcaoInvalida();
      }
    }
  }

  Future<ExecutorRef?> _escolherExecutor(List<ExecutorRef> lista) async {
    if (lista.isEmpty) {
      print('Nenhum executor encontrado.');
      pausar();
      return null;
    }
    print('\nResultados encontrados:\n');
    final i = _escolherOpcao(
      lista.map((e) => '${e.nome} (${e.setorNome})').toList(),
    );
    return i == null ? null : lista[i];
  }

  // ===========================================================
  // RESUMO / EDIÇÃO DO RASCUNHO / CONFIRMAÇÃO
  // ===========================================================

  Future<void> _imprimirResumo(_RascunhoOs d) async {
    _cabecalho('Resumo da OS');
    print('Título: ${d.titulo}');
    print('Descrição: ${d.observacao ?? "—"}');
    print('Solicitante: ${await _nomeUsuario(d.solicitanteId)}');
    print('Executor: ${await _nomeUsuario(d.executorId)}');
    print('Setor: ${await _nomeSetor(d.setorId)}');
    print('Prioridade: ${d.prioridade}');
    print('Tipo de manutenção: ${d.tipo}');
    print('Localização: ${await _nomeLocalizacao(d.localizacaoId)}');
    print('Patrimônio: ${await _nomePatrimonio(d.patrimonioId)}');
    print(
      'Prazo previsto: ${d.prazo == null ? "Não definido" : _data(d.prazo)}',
    );
    if (d.preventiva) {
      print(
        'Recorrente: Sim (a cada ${d.intervaloDias} dias, '
        'duração ${d.duracaoDias} dias, próxima ${_data(d.proximaData)})',
      );
    } else {
      print('Recorrente: Não');
    }
    print('\n=================================');
  }

  /// [1] Editar OS / [2] Confirmar e abrir / [0] Cancelar.
  Future<OrdemDeServico?> _resumo(_RascunhoOs d) async {
    while (true) {
      await _imprimirResumo(d);
      print('[1] Editar OS\n[2] Confirmar e abrir\n[0] Cancelar');

      switch (_ler()) {
        case '1':
          await _editarCampos(d, novo: true);
          break;
        case '2':
          if (!_confirmar('Deseja abrir esta ordem de serviço?')) break;
          final os = _construirValidando(d);
          if (os == null) break; // mostra o erro (com pausa) e volta ao resumo
          return await dao.inserir(os);
        case '0':
          if (_confirmar('Deseja realmente cancelar o cadastro?')) return null;
          break;
        default:
          _opcaoInvalida();
      }
    }
  }

  /// Tela "Editar Ordem de Serviço". Serve para OS nova (rascunho) e para
  /// OS já gravada ([novo] = false: o tipo de manutenção fica bloqueado).
  Future<void> _editarCampos(_RascunhoOs d, {required bool novo}) async {
    while (true) {
      _cabecalho('Editar Ordem de Serviço');
      print('1. Título: ${d.titulo}');
      print('2. Descrição: ${d.observacao ?? "—"}');
      print('3. Prioridade: ${d.prioridade}');
      print('4. Tipo de manutenção: ${d.tipo}');
      print('5. Solicitante: ${await _nomeUsuario(d.solicitanteId)}');
      print('6. Executor: ${await _nomeUsuario(d.executorId)}');
      print('7. Setor: ${await _nomeSetor(d.setorId)}');
      print('8. Localização: ${await _nomeLocalizacao(d.localizacaoId)}');
      print('9. Patrimônio: ${await _nomePatrimonio(d.patrimonioId)}');
      print(
        '10. Prazo previsto: ${d.prazo == null ? "Não definido" : _data(d.prazo)}',
      );
      if (d.preventiva) {
        print(
          '11. Recorrência: a cada ${d.intervaloDias} dias, '
          'duração ${d.duracaoDias}, próxima ${_data(d.proximaData)}',
        );
      }
      print('\n0. Voltar\n');

      final campo = _ler('Selecione o campo que deseja editar:');
      var editou = false;

      switch (campo) {
        case '0':
          return;
        case '1':
          print('Valor atual: ${d.titulo}');
          d.titulo = _lerTexto('Insira o novo valor:');
          editou = true;
          break;
        case '2':
          print('Valor atual: ${d.observacao ?? "—"}');
          d.observacao = _lerTextoOpcional('Insira o novo valor:');
          editou = true;
          break;
        case '3':
          print('Valor atual: ${d.prioridade}');
          final i = _escolherOpcao(OrdemDeServico.prioridadesValidas);
          if (i != null) {
            d.prioridade = OrdemDeServico.prioridadesValidas[i];
            editou = true;
          }
          break;
        case '4':
          if (!novo) {
            print(
              'O tipo de manutenção não pode ser alterado '
              'depois que a OS foi aberta.',
            );
            pausar();
            break;
          }
          print('Valor atual: ${d.tipo}');
          final i = _escolherOpcao(OrdemDeServico.tiposValidos);
          if (i == null) break;
          d.tipo = OrdemDeServico.tiposValidos[i];
          if (d.preventiva) {
            if (d.intervaloDias == null) await _campoRecorrencia(d);
          } else {
            d.limparRecorrencia();
          }
          editou = true;
          break;
        case '5':
          print('O solicitante não pode ser alterado.');
          pausar();
          break;
        case '6':
          if (!_podeAlterarExecutor) {
            print('Apenas administradores podem alterar o executor.');
            pausar();
            break;
          }
          editou = await _campoExecutor(d);
          break;
        case '7':
          editou = await _campoSetor(d);
          break;
        case '8':
          editou = await _campoLocalizacao(d);
          break;
        case '9':
          editou = await _campoPatrimonio(d);
          break;
        case '10':
          if (!isAdmin) {
            print('Apenas administradores definem o prazo previsto.');
            pausar();
            break;
          }
          print(
            'Valor atual: ${d.prazo == null ? "Não definido" : _data(d.prazo)}',
          );
          d.prazo = _lerData(
            'Insira o novo valor (DD/MM/AAAA):',
            opcional: true,
            permitirPassado: false,
          );
          editou = true;
          break;
        case '11':
          if (!d.preventiva) {
            _opcaoInvalida();
            break;
          }
          await _campoRecorrencia(d);
          editou = true;
          break;
        default:
          _opcaoInvalida();
      }

      if (editou) {
        d.alterado = true;
        print('Informação atualizada!');
        if (!_confirmar('Deseja alterar mais algum campo?')) return;
      }
    }
  }

  /// Tela "OS Cadastrada com Sucesso!". Retorna true para cadastrar outra.
  Future<bool> _sucessoCadastro(OrdemDeServico os) async {
    while (true) {
      _cabecalho('OS Cadastrada com Sucesso!');
      print('Número da OS: #${os.id}');
      print('Status: ${os.status}');
      print('Solicitante: ${await _nomeUsuario(os.solicitanteId)}');
      print('Executor: ${await _nomeUsuario(os.executorId)}\n');
      print('=================================');
      print('[1] Visualizar OS\n[2] Cadastrar outra OS\n[0] Voltar para Home');

      switch (_ler()) {
        case '1':
          await detalhes(os);
          return false;
        case '2':
          return true;
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
      _cabecalho('Consultar Ordens de Serviço');
      print('1. Buscar por número da OS');
      print('2. Buscar por título');
      print('3. Buscar por solicitante');
      print('4. Buscar por executor');
      print('5. Filtrar por status');
      print('6. Filtrar por prioridade');
      print('7. Filtrar por período');
      print('8. Filtrar por setor');
      print('0. Voltar\n');

      switch (_ler('Selecione uma opção:')) {
        case '1':
          await buscarPorNumero();
          break;
        case '2':
          await _buscarTexto(
            'Digite o título:',
            dao.buscarPorTitulo,
            'Resultados por Título',
          );
          break;
        case '3':
          await _buscarTexto(
            'Digite o nome do solicitante:',
            dao.buscarPorSolicitanteNome,
            'Resultados por Solicitante',
          );
          break;
        case '4':
          await _buscarTexto(
            'Digite o nome do executor:',
            dao.buscarPorExecutorNome,
            'Resultados por Executor',
          );
          break;
        case '5':
          await _filtrarPorStatus();
          break;
        case '6':
          await _filtrarPorPrioridade();
          break;
        case '7':
          await _filtrarPorPeriodo();
          break;
        case '8':
          await _filtrarPorSetor();
          break;
        case '0':
          return;
        default:
          _opcaoInvalida();
      }
    }
  }

  Future<void> buscarPorNumero() async {
    while (true) {
      _cabecalho('Buscar Ordem de Serviço');
      final id = int.tryParse(_ler('Digite o número da OS:'));
      final os = id == null ? null : await dao.buscarPorId(id);

      if (os == null) {
        print('Nenhuma OS encontrada com esse número.\n');
        print('[1] Tentar novamente\n[0] Voltar');
        while (true) {
          final r = _ler();
          if (r == '1') break;
          if (r == '0') return;
          _opcaoInvalida(pausa: false); // volta a ler o mesmo menu
        }
        continue;
      }

      print('\nOS #${os.id}');
      print('Título: ${os.titulo}');
      print('Status: ${_statusTexto(os)}');
      print('Solicitante: ${await _nomeUsuario(os.solicitanteId)}');
      print('Executor: ${await _nomeUsuario(os.executorId)}\n');
      print('[1] Visualizar detalhes\n[2] Buscar outra OS\n[0] Voltar');

      while (true) {
        final r = _ler('Selecione uma opção:');
        if (r == '1') {
          await detalhes(os);
          return;
        }
        if (r == '2') break;
        if (r == '0') return;
        _opcaoInvalida(pausa: false); // volta a ler o mesmo menu
      }
    }
  }

  Future<void> _buscarTexto(
    String prompt,
    Future<List<OrdemDeServico>> Function(String) busca,
    String titulo,
  ) async {
    final texto = _ler('$prompt (0 para voltar)');
    if (texto.isEmpty || texto == '0') return;
    await _exibirLista(titulo, await busca(texto));
  }

  Future<void> _filtrarPorStatus() async {
    print('\nSelecione o status:');
    final status = OrdemDeServico.statusValidos;
    final i = _escolherOpcao(status);
    if (i == null) return;
    await _exibirLista(
      'OS — ${status[i]}',
      await dao.listarPorStatus(status[i]),
    );
  }

  Future<void> _filtrarPorPrioridade() async {
    print('\nSelecione a prioridade:');
    final i = _escolherOpcao(OrdemDeServico.prioridadesValidas);
    if (i == null) return;
    final p = OrdemDeServico.prioridadesValidas[i];
    await _exibirLista('OS — Prioridade $p', await dao.listarPorPrioridade(p));
  }

  Future<void> _filtrarPorPeriodo() async {
    final inicio = _lerData('Data inicial (DD/MM/AAAA):')!;
    final fim = _lerData('Data final (DD/MM/AAAA):')!;
    if (fim.isBefore(inicio)) {
      print('A data final não pode ser anterior à inicial.');
      pausar();
      return;
    }
    await _exibirLista('OS — Período', await dao.listarPorPeriodo(inicio, fim));
  }

  Future<void> _filtrarPorSetor() async {
    final setores = await apoio.listarSetores();
    if (setores.isEmpty) {
      print('Nenhum setor cadastrado.');
      pausar();
      return;
    }
    print('\nSelecione o setor:');
    final i = _escolherOpcao(setores.map((s) => s.nome).toList());
    if (i == null) return;
    await _exibirLista(
      'OS — ${setores[i].nome}',
      await dao.listarPorSetor(setores[i].id!),
    );
  }

  // ===========================================================
  // LISTAR
  // ===========================================================

  Future<void> menuListar() async {
    final status = OrdemDeServico.statusValidos;
    while (true) {
      _cabecalho('Listar Ordens de Serviço');
      print('1. Todas as OS');
      for (var i = 0; i < status.length; i++) {
        print('${i + 2}. OS ${status[i]}');
      }
      final porPrioridade = status.length + 2;
      print('$porPrioridade. OS por prioridade');
      print('0. Voltar\n');

      final op = int.tryParse(_ler('Selecione uma opção:'));
      if (op == 0) return;
      if (op == 1) {
        await _exibirLista('Ordens de Serviço', await dao.listarTodas());
      } else if (op != null && op >= 2 && op < porPrioridade) {
        final s = status[op - 2];
        await _exibirLista('OS — $s', await dao.listarPorStatus(s));
      } else if (op == porPrioridade) {
        await _filtrarPorPrioridade();
      } else {
        _opcaoInvalida();
      }
    }
  }

  /// Tabela paginada: ID / Título / Status. Escolher abre os detalhes.
  Future<void> _exibirLista(
    String titulo,
    List<OrdemDeServico> itens, {
    String rotuloVisualizar = 'Consultar uma OS',
  }) async {
    if (itens.isEmpty) {
      print('\nNenhuma OS encontrada.');
      pausar();
      return;
    }
    var pagina = 0;
    final totalPaginas = (itens.length / _tamanhoPagina).ceil();

    while (true) {
      _cabecalho(titulo);
      final inicio = pagina * _tamanhoPagina;
      final fim = (inicio + _tamanhoPagina).clamp(0, itens.length);

      print('ID    Título                 Status');
      print('-----------------------------------------');
      for (final os in itens.sublist(inicio, fim)) {
        print(
          '${os.id.toString().padRight(6)}'
          '${_cortar(os.titulo, 22).padRight(23)}${_statusTexto(os)}',
        );
      }
      print('-----------------------------------------');
      print('Página ${pagina + 1} de $totalPaginas');
      print('[1] $rotuloVisualizar');
      print('[2] Próxima página');
      print('[3] Página anterior');
      print('[0] Voltar\n');

      switch (_ler('Selecione uma opção:')) {
        case '1':
          final id = int.tryParse(_ler('Digite o ID da OS:'));
          final achada = itens.where((o) => o.id == id);
          if (achada.isEmpty) {
            print('ID não encontrado nesta lista.');
            pausar();
          } else {
            await detalhes(achada.first);
          }
          break;
        case '2':
          if (pagina < totalPaginas - 1) {
            pagina++;
          } else {
            print('Você já está na última página.');
            pausar();
          }
          break;
        case '3':
          if (pagina > 0) {
            pagina--;
          } else {
            print('Você já está na primeira página.');
            pausar();
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
  // OS ASSOCIADAS A MIM
  // ===========================================================

  Future<void> menuMinhasOs() async {
    while (true) {
      _cabecalho('Minhas Ordens');
      print('1. OS que solicitei');
      print('2. OS sob minha responsabilidade');
      print('3. Todas as minhas OS');
      print('0. Voltar\n');

      List<OrdemDeServico>? lista;
      switch (_ler('Selecione uma opção:')) {
        case '1':
          lista = await dao.listarPorSolicitante(usuarioId);
          break;
        case '2':
          lista = await dao.listarPorExecutor(usuarioId);
          break;
        case '3':
          final mapa = <int?, OrdemDeServico>{};
          for (final os in [
            ...await dao.listarPorSolicitante(usuarioId),
            ...await dao.listarPorExecutor(usuarioId),
          ]) {
            mapa[os.id] = os; // evita duplicar quem é solicitante e executor
          }
          lista = mapa.values.toList();
          break;
        case '0':
          return;
        default:
          _opcaoInvalida();
      }

      if (lista != null) {
        await _exibirLista(
          'Minhas Ordens de Serviço',
          lista,
          rotuloVisualizar: 'Visualizar OS',
        );
      }
    }
  }

  // ===========================================================
  // DETALHES DA OS
  // ===========================================================

  Future<void> detalhes(OrdemDeServico osInicial) async {
    while (true) {
      final os = await dao.buscarPorId(osInicial.id!); // recarrega
      if (os == null) return;

      final materiais = await apoio.listarMateriaisUtilizados(os.id!);

      _cabecalho('Ordem de Serviço #${os.id}');
      print('Título: ${os.titulo}');
      print('Descrição: ${os.observacao ?? "—"}');
      print('Data de abertura: ${_dataHora(os.dataAbertura)}');
      print(
        'Prazo previsto: ${os.prazoPrevisto == null ? "Não definido" : _data(os.prazoPrevisto)}',
      );
      print(
        'Data de início: ${os.dataInicio == null ? "Não iniciado" : _dataHora(os.dataInicio)}',
      );
      print(
        'Data de conclusão: ${os.dataFim == null ? "Não concluída" : _dataHora(os.dataFim)}\n',
      );
      print('Solicitante: ${await _nomeUsuario(os.solicitanteId)}');
      print('Executor: ${await _nomeUsuario(os.executorId)}');
      print('Setor: ${await _nomeSetor(os.setorId)}');
      print('Localização: ${await _nomeLocalizacao(os.localizacaoId)}');
      print('Patrimônio: ${await _nomePatrimonio(os.patrimonioId)}\n');
      print('Prioridade: ${os.prioridade}');
      print('Tipo de manutenção: ${os.tipoManutencao}');
      if (os.recorrente) {
        print(
          'Recorrência: a cada ${os.intervaloDias} dias, '
          'próxima em ${_data(os.proximaData)}',
        );
      }
      print('Status: ${_statusTexto(os)}\n');
      print('Materiais utilizados:');
      print(
        materiais.isEmpty
            ? '  Nenhum'
            : materiais.map((m) => '  $m').join('\n'),
      );
      print('\n=================================');
      print('[1] Editar OS');
      print('[2] Alterar status');
      print('[3] Alterar executor');
      print('[4] Registrar materiais utilizados');
      print('[5] Consultar patrimônio');
      print('[0] Voltar\n');

      switch (_ler('Selecione uma opção:')) {
        case '1':
          await editar(os);
          break;
        case '2':
          await alterarStatus(os);
          break;
        case '3':
          await alterarExecutor(os);
          break;
        case '4':
          await registrarMateriais(os);
          break;
        case '5':
          if (os.patrimonioId == null) {
            print('Esta OS não possui patrimônio específico.');
            pausar();
          } else {
            await abrirPatrimonio(os.patrimonioId!);
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
  // EDITAR OS EXISTENTE
  // ===========================================================

  Future<void> editar(OrdemDeServico os) async {
    if (!_podeEditar(os)) {
      print('Você não tem permissão para editar esta OS.');
      pausar();
      return;
    }
    final d = _RascunhoOs.de(os);
    await _editarCampos(d, novo: false);
    if (!d.alterado) return;

    if (!_confirmar('Deseja salvar as alterações?')) return;
    final atualizada = _construirValidando(d, base: os);
    if (atualizada == null) return;
    await dao.atualizar(atualizada);
    print('Ordem de serviço atualizada!');
    pausar();
  }

  // ===========================================================
  // ALTERAR STATUS
  // ===========================================================

  Future<void> alterarStatus(OrdemDeServico os) async {
    if (!_podeAlterarStatus(os)) {
      print('Apenas o executor ou um administrador pode alterar o status.');
      pausar();
      return;
    }

    _cabecalho('Alterar Status da OS');
    print('OS: #${os.id}');
    print('Status atual: ${os.status}\n');
    print('Selecione o novo status:\n');

    final todos = OrdemDeServico.statusValidos;
    final i = _escolherOpcao(todos);
    if (i == null) return;
    final novo = todos[i];

    if (novo == os.status) {
      print('A OS já está com esse status.');
      pausar();
      return;
    }
    if (os.tipoManutencao == OrdemDeServico.preventiva &&
        novo == OrdemDeServico.statusConcluida) {
      print('Preventiva não é concluída: ela se renova.');
      pausar();
      return;
    }
    if (!_confirmar('Deseja realmente alterar o status para "$novo"?')) return;

    final iniciou =
        novo != OrdemDeServico.statusAberta &&
        novo != OrdemDeServico.statusCancelada;
    final concluiu = novo == OrdemDeServico.statusConcluida;
    final agora = DateTime.now();

    final atualizada = os.copyWith(
      status: novo,
      dataInicio: (iniciou && os.dataInicio == null) ? agora : null,
      dataFim: concluiu ? agora : null,
      limparDataFim:
          !concluiu, // ao reabrir ou cancelar, apaga a conclusão anterior
      executorId: (iniciou && os.executorId == null && !isAdmin)
          ? usuarioId
          : null,
    );

    try {
      atualizada.validar();
    } on ArgumentError catch (e) {
      print('Não foi possível alterar o status: ${e.message}');
      pausar();
      return;
    }
    await dao.atualizar(atualizada);
    print('Status atualizado para "$novo"!');
    pausar();
  }

  // ===========================================================
  // ALTERAR EXECUTOR
  // ===========================================================

  Future<void> alterarExecutor(OrdemDeServico os) async {
    if (!_podeAlterarExecutor) {
      print('Apenas administradores podem alterar o executor.');
      pausar();
      return;
    }
    final e = await _selecionarExecutor();
    if (e == null) return;

    if (!_confirmar('Deseja alterar o executor para "${e.nome}"?')) return;
    await dao.atualizar(os.copyWith(executorId: e.id));
    print('Executor atualizado!');
    pausar();
  }

  // ===========================================================
  // EXCLUIR (somente ADMIN)
  // ===========================================================

  Future<void> excluirPorId() async {
    if (!isAdmin) {
      print('Acesso negado: somente administradores podem excluir OS.');
      pausar();
      return;
    }

    _cabecalho('Excluir Ordem de Serviço');
    final id = int.tryParse(_ler('Digite o número da OS (0 para voltar):'));
    if (id == null || id == 0) return;

    final os = await dao.buscarPorId(id);
    if (os == null) {
      print('Nenhuma OS encontrada com esse número.');
      pausar();
      return;
    }

    print('\nOS #${os.id} — ${os.titulo}');
    print('Status: ${_statusTexto(os)}\n');
    if (!_confirmar('Deseja realmente excluir esta OS?')) return;

    try {
      await dao.excluir(os.id!);
      print('OS excluída com sucesso!');
    } catch (_) {
      print('Não foi possível excluir a OS.');
      print('Existem registros relacionados (ex.: materiais utilizados).');
      print('Considere cancelá-la para preservar o histórico.');
    }
    pausar();
  }
}