import 'dart:io';

import 'material.dart';
import 'material_dao.dart';

extension _MaterialCopy on Material {
  Material copyWith({
    String? nome,
    double? quantidade,
    double? valorMaterial,
    DateTime? dataCompra,
  }) {
    return Material(
      id: id,
      nome: nome ?? this.nome,
      quantidade: quantidade ?? this.quantidade,
      valorMaterial: valorMaterial ?? this.valorMaterial,
      dataCompra: dataCompra ?? this.dataCompra,
    );
  }
}

/// Dados ainda não salvos durante o cadastro.
class _Rascunho {
  String nome;
  double quantidade;
  DateTime dataCompra;
  double valor;
  _Rascunho(this.nome, this.quantidade, this.dataCompra, this.valor);
}

class MaterialMenu {
  final MaterialDao dao;

  /// Estoque <= este valor é considerado "baixo".
  final double limiteEstoqueBaixo;

  /// Histórico de utilização (depende da tabela de materiais usados por OS).
  final Future<void> Function(Material material) historicoPorMaterial;
  final Future<void> Function(int idOs) historicoPorOs;
  final Future<void> Function(DateTime inicio, DateTime fim) historicoPorPeriodo;

  MaterialMenu(
    this.dao, {
    required this.historicoPorMaterial,
    required this.historicoPorOs,
    required this.historicoPorPeriodo,
    this.limiteEstoqueBaixo = 10,
  });

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

  String _lerTexto(String prompt) {
    while (true) {
      final v = _ler(prompt);
      if (v.isNotEmpty) return v;
      print('Este campo é obrigatório. Tente novamente.');
    }
  }

  /// Aceita "12,5" ou "12.5". [permitirZero] false exige valor > 0.
  double _lerDouble(String prompt, {bool permitirZero = true}) {
    while (true) {
      final v = double.tryParse(_ler(prompt).replaceAll(',', '.'));
      if (v != null && (permitirZero ? v >= 0 : v > 0)) return v;
      print(permitirZero
          ? 'Valor inválido! Digite um número maior ou igual a zero.'
          : 'Valor inválido! Digite um número maior que zero.');
    }
  }

  /// Aceita DD/MM/AAAA e rejeita datas inexistentes (ex.: 31/02/2025).
  DateTime _lerData(String prompt) {
    while (true) {
      final partes = _ler(prompt).split('/');
      if (partes.length == 3) {
        final d = int.tryParse(partes[0]);
        final m = int.tryParse(partes[1]);
        final a = int.tryParse(partes[2]);
        if (d != null && m != null && a != null && a > 1900) {
          final data = DateTime(a, m, d);
          if (data.day == d && data.month == m && data.year == a) return data;
        }
      }
      print('Data inválida! Use o formato DD/MM/AAAA.');
    }
  }

  int? _lerCodigo(String prompt) => int.tryParse(_ler(prompt));

  String _qtd(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
  String _valor(double v) => v.toStringAsFixed(2).replaceAll('.', ',');
  String _data(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Pede o código e retorna o material, ou null (0 = voltar / não achou).
  Future<Material?> _pedirMaterialPorCodigo() async {
    final id = _lerCodigo('Digite o código do material (0 para voltar):');
    if (id == null || id == 0) {
      if (id == null) print('Código inválido.');
      return null;
    }
    final m = await dao.buscarPorId(id);
    if (m == null) print('Nenhum material encontrado com esse código.');
    return m;
  }

  // ===========================================================
  // MENU PRINCIPAL
  // ===========================================================

  Future<void> menuPrincipal() async {
    while (true) {
      _cabecalho('Materiais e Estoque');
      print('1. Cadastrar Material');
      print('2. Consultar Material');
      print('3. Listar Materiais');
      print('4. Atualizar Material');
      print('5. Registrar Entrada no Estoque');
      print('6. Consultar Estoque');
      print('7. Histórico de utilização');
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
          await atualizarPorCodigo();
          break;
        case '5':
          await registrarEntradaPorCodigo();
          break;
        case '6':
          await menuEstoque();
          break;
        case '7':
          await menuHistorico();
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
      _cabecalho('Cadastrar Material');

      final r = _Rascunho(
        _lerTexto('Nome do material:'),
        _lerDouble('Quantidade inicial em estoque:'),
        _lerData('Data da compra (DD/MM/AAAA):'),
        _lerDouble('Valor unitário (R\$):'),
      );

      final salvo = await _resumoCadastro(r);
      if (salvo == null) return; // cancelou

      final cadastrarOutro = await _sucessoCadastro(salvo);
      if (!cadastrarOutro) return;
    }
  }

  /// [1] Editar / [2] Confirmar / [0] Cancelar.
  /// Retorna o material salvo ou null se cancelou.
  Future<Material?> _resumoCadastro(_Rascunho r) async {
    while (true) {
      _cabecalho('Resumo do Material');
      print('Nome: ${r.nome}');
      print('Quantidade inicial: ${_qtd(r.quantidade)}');
      print('Data da compra: ${_data(r.dataCompra)}');
      print('Valor unitário: R\$ ${_valor(r.valor)}\n');
      print('=================================');
      print('[1] Editar informações');
      print('[2] Confirmar cadastro');
      print('[0] Cancelar');

      switch (_ler()) {
        case '1':
          _editarRascunho(r);
          break;
        case '2':
          return await dao.inserir(Material(
            nome: r.nome,
            quantidade: r.quantidade,
            valorMaterial: r.valor,
            dataCompra: r.dataCompra,
          ));
        case '0':
          if (_confirmar('Deseja realmente cancelar o cadastro?')) return null;
          break;
        default:
          _opcaoInvalida();
      }
    }
  }

  void _editarRascunho(_Rascunho r) {
    while (true) {
      _cabecalho('Editar Material');
      print('1. Nome: ${r.nome}');
      print('2. Quantidade inicial: ${_qtd(r.quantidade)}');
      print('3. Data da compra: ${_data(r.dataCompra)}');
      print('4. Valor unitário: R\$ ${_valor(r.valor)}');
      print('0. Voltar ao resumo\n');

      switch (_ler('Selecione o campo que deseja editar:')) {
        case '1':
          r.nome = _lerTexto('Novo nome:');
          break;
        case '2':
          r.quantidade = _lerDouble('Nova quantidade inicial:');
          break;
        case '3':
          r.dataCompra = _lerData('Nova data (DD/MM/AAAA):');
          break;
        case '4':
          r.valor = _lerDouble('Novo valor unitário (R\$):');
          break;
        case '0':
          return;
        default:
          _opcaoInvalida();
      }
    }
  }

  /// Retorna true se o usuário quer cadastrar outro.
  Future<bool> _sucessoCadastro(Material m) async {
    while (true) {
      _cabecalho('Material cadastrado com sucesso!');
      print('Código: #${m.id}');
      print('Nome: ${m.nome}');
      print('Estoque: ${_qtd(m.quantidade)}\n');
      print('=================================');
      print('[1] Cadastrar outro material');
      print('[2] Visualizar material');
      print('[0] Voltar para Home');

      switch (_ler()) {
        case '1':
          return true;
        case '2':
          await detalhes(m);
          return false;
        case '0':
          return false;
        default:
          _opcaoInvalida();
      }
    }
  }

  // ===========================================================
  // CONSULTAR MATERIAL
  // ===========================================================

  Future<void> menuConsultar() async {
    while (true) {
      _cabecalho('Consultar Material');
      print('1. Buscar por código');
      print('2. Buscar por nome');
      print('3. Consultar materiais com estoque baixo');
      print('4. Consultar materiais sem estoque');
      print('0. Voltar\n');

      switch (_ler('Selecione uma opção:')) {
        case '1':
          await buscarPorCodigo();
          break;
        case '2':
          await buscarPorNome();
          break;
        case '3':
          await listarEstoqueBaixo();
          break;
        case '4':
          await listarSemEstoque();
          break;
        case '0':
          return;
        default:
          _opcaoInvalida();
      }
    }
  }

  Future<void> buscarPorCodigo() async {
    final m = await _pedirMaterialPorCodigo();
    if (m != null) await detalhes(m);
  }

  Future<void> buscarPorNome() async {
    final nome = _ler('Digite o nome do material (0 para voltar):');
    if (nome.isEmpty || nome == '0') return;
    final resultados = await dao.buscarPorNome(nome);
    if (resultados.isEmpty) {
      print('Nenhum material encontrado com esse nome.');
      return;
    }
    final m = await _escolherDaLista('Resultados da Busca', resultados);
    if (m != null) await detalhes(m);
  }

  Future<void> listarEstoqueBaixo() async {
    final itens = await dao.listarEstoqueBaixo(limiteEstoqueBaixo);
    if (itens.isEmpty) {
      print('Nenhum material com estoque baixo.');
      return;
    }
    final m = await _escolherDaLista('Estoque Baixo', itens);
    if (m != null) await detalhes(m);
  }

  Future<void> listarSemEstoque() async {
    final itens = await dao.listarSemEstoque();
    if (itens.isEmpty) {
      print('Nenhum material sem estoque.');
      return;
    }
    final m = await _escolherDaLista('Materiais Sem Estoque', itens);
    if (m != null) await detalhes(m);
  }

  // ===========================================================
  // LISTAR (paginado)
  // ===========================================================

  Future<void> listar() async {
    final todos = await dao.listarTodos();
    if (todos.isEmpty) {
      print('Nenhum material cadastrado.');
      return;
    }
    final m = await _escolherDaLista('Listar Materiais', todos);
    if (m != null) await detalhes(m);
  }

  /// Lista paginada (ID / Material / Estoque). Retorna o escolhido ou null.
  Future<Material?> _escolherDaLista(String titulo, List<Material> itens) async {
    var pagina = 0;
    final totalPaginas = (itens.length / _tamanhoPagina).ceil();

    while (true) {
      _cabecalho(titulo);
      final inicio = pagina * _tamanhoPagina;
      final fim = (inicio + _tamanhoPagina).clamp(0, itens.length);
      final visiveis = itens.sublist(inicio, fim);

      print('ID    Material             Estoque');
      print('-----------------------------------------');
      for (final m in visiveis) {
        print('${m.id.toString().padRight(6)}'
            '${m.nome.padRight(21)}${_qtd(m.quantidade)}');
      }
      print('-----------------------------------------');
      print('Página ${pagina + 1} de $totalPaginas');
      print('[1] Visualizar material');
      print('[2] Próxima página');
      print('[3] Página anterior');
      print('[0] Voltar\n');

      switch (_ler('Selecione uma opção:')) {
        case '1':
          final id = _lerCodigo('Digite o código do material:');
          final achado = visiveis.where((m) => m.id == id);
          if (achado.isNotEmpty) return achado.first;
          print('Código não encontrado nesta página.');
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
  // DETALHES DO MATERIAL
  // ===========================================================

  Future<void> detalhes(Material material) async {
    while (true) {
      final m = await dao.buscarPorId(material.id!); // recarrega
      if (m == null) return;

      _cabecalho('Material #${m.id}');
      print('Nome: ${m.nome}');
      print('Quantidade em estoque: ${_qtd(m.quantidade)}');
      print('Valor unitário: R\$ ${_valor(m.valorMaterial)}');
      print('Data da compra: ${_data(m.dataCompra)}\n');
      print('=================================');
      print('[1] Editar material');
      print('[2] Registrar entrada');
      print('[3] Histórico de utilização');
      print('[0] Voltar\n');

      switch (_ler('Selecione uma opção:')) {
        case '1':
          await atualizar(m);
          break;
        case '2':
          await registrarEntrada(m);
          break;
        case '3':
          await historicoPorMaterial(m);
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

  Future<void> atualizarPorCodigo() async {
    final m = await _pedirMaterialPorCodigo();
    if (m != null) await atualizar(m);
  }

  Future<void> atualizar(Material material) async {
    while (true) {
      final m = await dao.buscarPorId(material.id!);
      if (m == null) return;

      _cabecalho('Atualizar Material');
      print('Material: ${m.nome}\n');
      print('1. Nome');
      print('2. Valor unitário');
      print('3. Data da compra');
      print('0. Voltar\n');

      final campo = _ler('Selecione o campo:');
      Material? alterado;

      switch (campo) {
        case '1':
          print('Valor atual: ${m.nome}');
          alterado = m.copyWith(nome: _lerTexto('Novo valor:'));
          break;
        case '2':
          print('Valor atual: R\$ ${_valor(m.valorMaterial)}');
          alterado =
              m.copyWith(valorMaterial: _lerDouble('Novo valor (R\$):'));
          break;
        case '3':
          print('Valor atual: ${_data(m.dataCompra)}');
          alterado = m.copyWith(
              dataCompra: _lerData('Nova data (DD/MM/AAAA):'));
          break;
        case '0':
          return;
        default:
          _opcaoInvalida();
      }

      if (alterado != null && _confirmar('Deseja salvar a alteração?')) {
        await dao.atualizar(alterado);
        print('Informação atualizada!');
      }
    }
  }

  // ===========================================================
  // REGISTRAR ENTRADA NO ESTOQUE
  // ===========================================================

  Future<void> registrarEntradaPorCodigo() async {
    final m = await _pedirMaterialPorCodigo();
    if (m != null) await registrarEntrada(m);
  }

  Future<void> registrarEntrada(Material material) async {
    _cabecalho('Registrar Entrada');
    print('Material: ${material.nome}');
    print('Estoque atual: ${_qtd(material.quantidade)}\n');

    final quantidade =
        _lerDouble('Quantidade recebida:', permitirZero: false);
    final valor = _lerDouble('Valor unitário da compra (R\$):');
    final data = _lerData('Data da compra (DD/MM/AAAA):');
    final novoEstoque = material.quantidade + quantidade;

    _cabecalho('Resumo da Entrada');
    print('Material: ${material.nome}');
    print('Quantidade recebida: ${_qtd(quantidade)}');
    print('Estoque anterior: ${_qtd(material.quantidade)}');
    print('Novo estoque: ${_qtd(novoEstoque)}\n');
    print('=================================');
    print('[1] Confirmar entrada');
    print('[0] Cancelar');

    while (true) {
      switch (_ler()) {
        case '1':
          await dao.registrarEntrada(
            id: material.id!,
            quantidade: quantidade,
            valorUnitario: valor,
            dataCompra: data,
          );
          print('Entrada registrada com sucesso!');
          return;
        case '0':
          print('Entrada cancelada.');
          return;
        default:
          _opcaoInvalida();
      }
    }
  }

  // ===========================================================
  // CONSULTAR ESTOQUE
  // ===========================================================

  Future<void> menuEstoque() async {
    while (true) {
      _cabecalho('Consultar Estoque');
      print('1. Todos os materiais');
      print('2. Estoque baixo');
      print('3. Sem estoque');
      print('4. Buscar material');
      print('0. Voltar\n');

      switch (_ler('Selecione uma opção:')) {
        case '1':
          await listar();
          break;
        case '2':
          await listarEstoqueBaixo();
          break;
        case '3':
          await listarSemEstoque();
          break;
        case '4':
          await buscarPorNome();
          break;
        case '0':
          return;
        default:
          _opcaoInvalida();
      }
    }
  }

  // ===========================================================
  // HISTÓRICO DE UTILIZAÇÃO
  // ===========================================================

  Future<void> menuHistorico() async {
    while (true) {
      _cabecalho('Histórico de Utilização');
      print('1. Consultar por material');
      print('2. Consultar por OS');
      print('3. Consultar por período');
      print('0. Voltar\n');

      switch (_ler('Selecione uma opção:')) {
        case '1':
          final m = await _pedirMaterialPorCodigo();
          if (m != null) await historicoPorMaterial(m);
          break;
        case '2':
          final idOs = _lerCodigo('Digite o número da OS (0 para voltar):');
          if (idOs == null) {
            print('Número inválido.');
          } else if (idOs != 0) {
            await historicoPorOs(idOs);
          }
          break;
        case '3':
          final inicio = _lerData('Data inicial (DD/MM/AAAA):');
          final fim = _lerData('Data final (DD/MM/AAAA):');
          if (fim.isBefore(inicio)) {
            print('A data final não pode ser anterior à inicial.');
          } else {
            await historicoPorPeriodo(inicio, fim);
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