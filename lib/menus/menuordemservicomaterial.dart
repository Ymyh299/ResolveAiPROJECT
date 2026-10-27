import 'dart:io';

import '../models/material.dart';
import '../dao/material_dao.dart';
import '../dao/ordem_servico_material_dao.dart';
import '../models/ordemdeservico.dart';
import '../models/ordemdeservicomaterial.dart';

class OrdemServicoMaterialMenu {
  final OrdemDeServicoMaterialDao dao;
  final MaterialDao materialDao;

  final int usuarioId;
  final bool isAdmin;

  /// "Visualizar OS" a partir das telas de histórico -> detalhes da OS.
  final Future<void> Function(int osId) abrirOs;

  /// Aviso de estoque baixo após registrar um uso.
  final double limiteEstoqueBaixo;

  OrdemServicoMaterialMenu(
    this.dao,
    this.materialDao, {
    required this.usuarioId,
    required this.isAdmin,
    required this.abrirOs,
    this.limiteEstoqueBaixo = 10,
  });

  static const int _tamanhoPagina = 10;

  // ----- Regra de permissão (ajuste aqui) -----
  /// Mesma regra de alterar status: admin, executor da OS ou OS sem executor.
  bool _podeRegistrar(OrdemDeServico os) =>
      isAdmin ||
      os.executorId == usuarioId ||
      os.executorId == null;

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

  String _qtd(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  String _data(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _cortar(String s, int n) =>
      s.length <= n ? s : '${s.substring(0, n - 1)}…';

  /// Quantidade > 0. Retorna null se digitar 0 (cancelar).
  double? _lerQuantidade(String prompt) {
    while (true) {
      final raw = _ler('$prompt (0 para cancelar)');
      if (raw == '0') return null;
      final v = double.tryParse(raw.replaceAll(',', '.'));
      if (v != null && v > 0) return v;
      print('Valor inválido! Digite um número maior que zero.');
    }
  }

  bool _statusBloqueiaRegistro(String status) =>
      status == OrdemDeServico.statusCancelada ||
      status == OrdemDeServico.statusConcluida;

  // ===========================================================
  // REGISTRAR MATERIAIS UTILIZADOS (tela de detalhes da OS)
  // ===========================================================

  Future<void> registrarMateriais(OrdemDeServico os) async {
    if (_statusBloqueiaRegistro(os.status)) {
      print('Não é possível registrar materiais em uma OS ${os.status}.');
      return;
    }
    if (!_podeRegistrar(os)) {
      print('Apenas o executor ou um administrador pode registrar materiais.');
      return;
    }

    while (true) {
      _cabecalho('Materiais da OS #${os.id}');
      print('OS: ${os.titulo}\n');
      print('1. Adicionar material por código');
      print('2. Buscar material por nome');
      print('3. Ver materiais registrados');
      print('4. Remover material registrado');
      print('0. Voltar\n');

      switch (_ler('Selecione uma opção:')) {
        case '1':
          final m = await _selecionarPorCodigo();
          if (m != null && await _adicionar(os, m)) {
            if (!_confirmar('Deseja registrar outro material?')) return;
          }
          break;
        case '2':
          final m = await _selecionarPorNome();
          if (m != null && await _adicionar(os, m)) {
            if (!_confirmar('Deseja registrar outro material?')) return;
          }
          break;
        case '3':
          await _verRegistrados(os);
          break;
        case '4':
          await _remover(os);
          break;
        case '0':
          return;
        default:
          _opcaoInvalida();
      }
    }
  }

  Future<Material?> _selecionarPorCodigo() async {
    final id = int.tryParse(
      _ler('Digite o código do material (0 para voltar):'),
    );
    if (id == null || id == 0) return null;
    final m = await materialDao.buscarPorId(id);
    if (m == null) print('Nenhum material encontrado com esse código.');
    return m;
  }

  Future<Material?> _selecionarPorNome() async {
    final nome = _ler('Digite o nome do material (0 para voltar):');
    if (nome.isEmpty || nome == '0') return null;

    final resultados = await materialDao.buscarPorNome(nome);
    if (resultados.isEmpty) {
      print('Nenhum material encontrado com esse nome.');
      return null;
    }

    while (true) {
      _cabecalho('Resultados Encontrados');
      for (var i = 0; i < resultados.length; i++) {
        print(
          '[${i + 1}] ${resultados[i].nome} '
          '(estoque: ${_qtd(resultados[i].quantidade)})',
        );
      }
      print('[0] Voltar\n');

      final op = int.tryParse(_ler('Selecione um material:'));
      if (op == 0) return null;
      if (op != null && op >= 1 && op <= resultados.length) {
        return resultados[op - 1];
      }
      _opcaoInvalida();
    }
  }

  /// Resumo -> [1] Confirmar / [0] Cancelar. Retorna true se registrou.
  Future<bool> _adicionar(OrdemDeServico os, Material m) async {
    _cabecalho('Registrar Material');
    print('Material: ${m.nome}');
    print('Estoque atual: ${_qtd(m.quantidade)}\n');

    if (m.quantidade <= 0) {
      print('Este material está sem estoque.');
      return false;
    }

    final qtd = _lerQuantidade('Quantidade utilizada:');
    if (qtd == null) return false;
    if (qtd > m.quantidade) {
      print('Estoque insuficiente! Disponível: ${_qtd(m.quantidade)}.');
      return false;
    }
    final novoEstoque = m.quantidade - qtd;

    _cabecalho('Resumo do Uso');
    print('OS: #${os.id} — ${os.titulo}');
    print('Material: ${m.nome}');
    print('Quantidade utilizada: ${_qtd(qtd)}');
    print('Estoque anterior: ${_qtd(m.quantidade)}');
    print('Novo estoque: ${_qtd(novoEstoque)}\n');
    print('=================================');
    print('[1] Confirmar registro\n[0] Cancelar');

    while (true) {
      switch (_ler()) {
        case '1':
          try {
            await dao.registrarUso(os.id!, m.id!, qtd);
          } on Exception catch (e) {
            print('Não foi possível registrar: ${e.toString().replaceFirst('Exception: ', '')}');
            return false;
          }
          print('Material registrado com sucesso!');
          if (novoEstoque <= 0) {
            print('Atenção: o estoque deste material zerou.');
          } else if (novoEstoque <= limiteEstoqueBaixo) {
            print('Atenção: estoque baixo (${_qtd(novoEstoque)}).');
          }
          return true;
        case '0':
          print('Registro cancelado.');
          return false;
        default:
          _opcaoInvalida();
      }
    }
  }

  Future<void> _verRegistrados(OrdemDeServico os) async {
    final usos = await dao.listarPorOs(os.id!);
    if (usos.isEmpty) {
      print('\nNenhum material registrado nesta OS.');
      return;
    }
    _cabecalho('Materiais da OS #${os.id}');
    _imprimirTabela(usos);
    print('\nTotal de registros: ${usos.length}');
  }

  Future<void> _remover(OrdemDeServico os) async {
  final usos = await dao.listarPorOs(os.id!);
  if (usos.isEmpty) {
    print('\nNenhum material registrado nesta OS.');
    return;
  }
  _cabecalho('Remover Material Registrado');
  _imprimirTabela(usos);

  final id = int.tryParse(_ler('\nDigite o ID do registro (0 para voltar):'));
  if (id == null || id == 0) return;
  final achados = usos.where((u) => u.id == id);
  if (achados.isEmpty) {
    print('Registro não encontrado nesta OS.');
    return;
  }

  final u = achados.first;
  print('\nMaterial: ${u.materialNome}');
  print('Quantidade: ${_qtd(u.quantidade)}');

  if (!_confirmar('Deseja remover este registro?\n'
      '(a quantidade será devolvida ao estoque)')) {
    return;
  }

  try {
    await dao.removerUso(u.id);
    print('Registro removido e estoque atualizado!');
  } on Exception catch (e) {
    print('Não foi possível remover: ${e.toString().replaceFirst('Exception: ', '')}');
  }
}

  // ===========================================================
  // HISTÓRICO DE UTILIZAÇÃO (callbacks do MaterialMenu)
  // ===========================================================

  Future<void> historicoPorMaterial(Material material) async {
    final usos = await dao.listarPorMaterial(material.id!);
    final total = usos.fold<double>(0, (s, u) => s + u.quantidade);
    await _exibirHistorico(
      'Histórico — ${_cortar(material.nome, 20)}',
      usos,
      rodape: [
        'Total de usos: ${usos.length}',
        'Quantidade total consumida: ${_qtd(total)}',
      ],
    );
  }

  Future<void> historicoPorOs(int osId) async {
    final usos = await dao.listarPorOs(osId);
    await _exibirHistorico(
      'Materiais da OS #$osId',
      usos,
      rodape: ['Total de registros: ${usos.length}'],
    );
  }

  Future<void> historicoPorPeriodo(DateTime inicio, DateTime fim) async {
    final usos = await dao.listarPorPeriodo(inicio, fim);

    // Consumo agregado por material no período.
    final porMaterial = <String, double>{};
    for (final u in usos) {
      porMaterial[u.materialNome] =
          (porMaterial[u.materialNome] ?? 0) + u.quantidade;
    }

    await _exibirHistorico(
      'Histórico — ${_data(inicio)} a ${_data(fim)}',
      usos,
      rodape: [
        'Total de registros: ${usos.length}',
        if (porMaterial.isNotEmpty) '\nConsumo por material:',
        ...porMaterial.entries.map((e) => '  ${e.key}: ${_qtd(e.value)}'),
      ],
    );
  }

  void _imprimirTabela(List<UsoMaterialDetalhe> usos) {
    print('ID    Data        OS     Material            Qtd');
    print('-------------------------------------------------');
    for (final u in usos) {
      print(
        '${u.id.toString().padRight(6)}'
        '${_data(u.dataUso).padRight(12)}'
        '${('#${u.ordemServicoId}').padRight(7)}'
        '${_cortar(u.materialNome, 18).padRight(20)}'
        '${_qtd(u.quantidade)}',
      );
    }
  }

  /// Lista paginada; [1] abre a OS do registro escolhido.
  Future<void> _exibirHistorico(
    String titulo,
    List<UsoMaterialDetalhe> usos, {
    List<String> rodape = const [],
  }) async {
    if (usos.isEmpty) {
      print('\nNenhum registro de utilização encontrado.');
      return;
    }

    var pagina = 0;
    final totalPaginas = (usos.length / _tamanhoPagina).ceil();

    while (true) {
      _cabecalho(titulo);
      final inicio = pagina * _tamanhoPagina;
      final fim = (inicio + _tamanhoPagina).clamp(0, usos.length);
      _imprimirTabela(usos.sublist(inicio, fim));
      print('-------------------------------------------------');
      print('Página ${pagina + 1} de $totalPaginas');
      for (final linha in rodape) {
        print(linha);
      }
      print('\n[1] Visualizar OS');
      print('[2] Próxima página');
      print('[3] Página anterior');
      print('[0] Voltar\n');

      switch (_ler('Selecione uma opção:')) {
          case '1':
            final osId = int.tryParse(_ler('Digite o número da OS:'));
            if (osId == null || !usos.any((u) => u.ordemServicoId == osId)) {
              print('OS não encontrada neste histórico.');
            } else {
              await abrirOs(osId);
            }
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
          return;
        default:
          _opcaoInvalida();
      }
    }
  }
}
