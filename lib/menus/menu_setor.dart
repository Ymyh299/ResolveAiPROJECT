import 'dart:io';

import '../models/setor.dart';
import '../dao/setor_dao.dart';
import '../dao/usuario_dao.dart';

/// Menus do módulo de Setores (apenas interface de console).
/// Toda persistência é delegada aos DAOs.
///
/// DAOs esperados:
///   SetorDao:   inserir(Setor)->int, buscarPorId(int)->Setor?,
///               buscarPorNome(String)->List<Setor>, listar()->List<Setor>,
///               atualizar(Setor), excluir(int)
///   UsuarioDao: contarPorSetor(int)->int, buscarPorSetor(int)->List<Usuario>
class MenuSetor {
  // ===========================================================================
  // 6.1 GERENCIAR SETORES
  // ===========================================================================

  static Future<void> menuSetores() async {
    while (true) {
      _cabecalho('Gerenciar Setores');
      print('1. Cadastrar Setor');
      print('2. Consultar Setor');
      print('3. Listar Setores');
      print('4. Atualizar Setor');
      print('5. Excluir Setor');
      print('0. Voltar para Home');
      final op = _ler('\nSelecione uma opção:');

      switch (op) {
        case '1':
          await cadastrarSetor();
        case '2':
          await consultarSetor();
        case '3':
          await listarSetores();
        case '4':
          await atualizarSetor();
        case '5':
          await excluirSetor();
        case '0':
          return; // volta para quem chamou (Home)
        default:
          _opcaoInvalida();
      }
    }
  }

  // ===========================================================================
  // CADASTRAR SETOR
  // ===========================================================================

  static Future<void> cadastrarSetor() async {
    _cabecalho('Cadastrar Setor');

    var nome = _lerObrigatorio('Nome do setor:');
    var descricao = _ler('\nDescrição:');

    // Resumo + confirmação
    while (true) {
      _cabecalho('Resumo do Setor');
      print('Nome: $nome');
      print('Descrição: ${descricao.isEmpty ? '-' : descricao}');
      print('\n=================================');
      print('[1] Editar informações');
      print('[2] Confirmar cadastro');
      print('[0] Cancelar');
      final op = _ler('');

      if (op == '0') return;
      if (op == '2') break;
      if (op == '1') {
        print('\nQual campo deseja editar?');
        print('1. Nome');
        print('2. Descrição');
        switch (_ler('>')) {
          case '1':
            nome = _lerObrigatorio('Nome do setor:');
          case '2':
            descricao = _ler('Descrição:');
          default:
            _opcaoInvalida();
        }
      } else {
        _opcaoInvalida();
      }
    }

    final id = await SetorDao().inserir(
      Setor(nome: nome, descricao: descricao.isEmpty ? null : descricao),
    );

    _cabecalho('Setor cadastrado com sucesso!');
    print('ID: #$id');
    print('Nome: $nome');
    _ler('\n[0] Voltar');
  }

  // ===========================================================================
  // CONSULTAR SETOR
  // ===========================================================================

  static Future<void> consultarSetor() async {
    while (true) {
      _cabecalho('Consultar Setor');
      print('1. Buscar por ID');
      print('2. Buscar por nome');
      print('0. Voltar');
      final op = _ler('\nSelecione uma opção:');

      final dao = SetorDao();
      List<Setor> resultado = [];

      switch (op) {
        case '1':
          final id = int.tryParse(_ler('Digite o ID:'));
          if (id == null) {
            _opcaoInvalida();
            continue;
          }
          final s = await dao.buscarPorId(id);
          if (s != null) resultado = [s];
        case '2':
          resultado = await dao.buscarPorNome(_ler('Digite o nome:'));
        case '0':
          return;
        default:
          _opcaoInvalida();
          continue;
      }

      if (resultado.isEmpty) {
        print('\nNenhum setor encontrado.');
        _ler('Pressione ENTER para continuar...');
        continue;
      }
      if (resultado.length == 1) {
        await detalhesSetor(resultado.first.id!);
      } else {
        final escolhido = _escolherDaLista(resultado);
        if (escolhido != null) await detalhesSetor(escolhido.id!);
      }
    }
  }

  // ===========================================================================
  // LISTAR SETORES
  // ===========================================================================

  static Future<void> listarSetores() async {
    while (true) {
      final setores = await SetorDao().listar();

      _cabecalho('Listar Setores');
      if (setores.isEmpty) {
        print('Nenhum setor cadastrado.\n');
        _ler('[0] Voltar');
        return;
      }

      final escolhido = _escolherDaLista(setores);
      if (escolhido == null) return;
      await detalhesSetor(escolhido.id!);
    }
  }

  // ===========================================================================
  // DETALHES DO SETOR
  // ===========================================================================

  static Future<void> detalhesSetor(int id) async {
    while (true) {
      // Recarrega a cada volta, para refletir edições feitas na própria tela.
      final setor = await SetorDao().buscarPorId(id);
      if (setor == null) {
        print('\nSetor não encontrado (pode ter sido excluído).');
        _ler('Pressione ENTER para continuar...');
        return;
      }
      final qtdUsuarios = await UsuarioDao().contarPorSetor(id);

      _cabecalho('Setor #${setor.id}');
      print('Nome: ${setor.nome}');
      print('Descrição: ${_texto(setor.descricao)}');
      print('Usuários vinculados: $qtdUsuarios');
      print('\n=================================');
      print('[1] Editar setor');
      print('[2] Consultar usuários do setor');
      print('[3] Excluir setor');
      print('[0] Voltar');
      final op = _ler('\nSelecione uma opção:');

      switch (op) {
        case '1':
          await _editarSetor(setor);
        case '2':
          await _consultarUsuariosDoSetor(setor);
        case '3':
          final excluido = await _excluirSetor(setor);
          if (excluido) return; // setor não existe mais
        case '0':
          return;
        default:
          _opcaoInvalida();
      }
    }
  }

  // ===========================================================================
  // ATUALIZAR SETOR
  // ===========================================================================

  /// Opção 4 do menu: pede o ID e abre a edição.
  static Future<void> atualizarSetor() async {
    _cabecalho('Atualizar Setor');
    final id = int.tryParse(_ler('Digite o ID do setor:'));
    if (id == null) return _opcaoInvalida();

    final setor = await SetorDao().buscarPorId(id);
    if (setor == null) {
      print('\nSetor não encontrado.');
      _ler('Pressione ENTER para continuar...');
      return;
    }
    await _editarSetor(setor);
  }

  /// Edição de campos (usada pelo menu e pela tela de detalhes).
  static Future<void> _editarSetor(Setor setor) async {
    var atual = setor;

    while (true) {
      print('\nSetor: ${atual.nome}\n');
      print('1. Nome');
      print('2. Descrição');
      print('0. Voltar');
      final campo = _ler('\nSelecione o campo:');

      if (campo == '0') return;

      Setor atualizado;
      switch (campo) {
        case '1':
          atualizado = atual.copyWith(nome: _lerObrigatorio('\nNovo valor:'));
        case '2':
          atualizado = atual.copyWith(descricao: _ler('\nNovo valor:'));
        default:
          _opcaoInvalida();
          continue;
      }

      if (_confirmar('Deseja salvar a alteração?')) {
        await SetorDao().atualizar(atualizado);
        atual = atualizado;
        print('\nAlteração salva com sucesso!');
      } else {
        print('\nAlteração descartada.');
      }
    }
  }

  // ===========================================================================
  // EXCLUIR SETOR
  // ===========================================================================

  /// Opção 5 do menu: pede o ID e executa a exclusão.
  static Future<void> excluirSetor() async {
    _cabecalho('Excluir Setor');
    final id = int.tryParse(_ler('Digite o ID do setor:'));
    if (id == null) return _opcaoInvalida();

    final setor = await SetorDao().buscarPorId(id);
    if (setor == null) {
      print('\nSetor não encontrado.');
      _ler('Pressione ENTER para continuar...');
      return;
    }
    await _excluirSetor(setor);
  }

  /// Retorna true se o setor foi excluído.
  /// Regra: com usuários vinculados, a exclusão é impedida.
  static Future<bool> _excluirSetor(Setor setor) async {
    print('\nSetor: ${setor.nome}');

    final qtd = await UsuarioDao().contarPorSetor(setor.id!);
    if (qtd > 0) {
      print('\nNão foi possível excluir o setor.');
      print('Existem $qtd usuário(s) vinculado(s) a ele.\n');
      print('Transfira ou exclua esses usuários antes');
      print('de excluir o setor.\n');
      _ler('[0] Voltar');
      return false;
    }

    if (!_confirmar('Deseja Excluir este setor?')) return false;

    await SetorDao().excluir(setor.id!);
    print('\nSetor excluído com sucesso!\n');
    _ler('[0] Voltar');
    return true;
  }

  // ===========================================================================
  // CONSULTAR USUÁRIOS DO SETOR
  // ===========================================================================

  static Future<void> _consultarUsuariosDoSetor(Setor setor) async {
    final usuarios = await UsuarioDao().buscarPorSetor(setor.id!);

    _cabecalho('Usuários de ${setor.nome}');
    if (usuarios.isEmpty) {
      print('Nenhum usuário vinculado a este setor.');
    } else {
      print('ID    Nome');
      print('-----------------------------------------');
      for (final u in usuarios) {
        print('${u.id.toString().padRight(6)}${u.nome}');
      }
    }
    _ler('\n[0] Voltar');
  }

  // ===========================================================================
  // HELPERS PRIVADOS
  // ===========================================================================

  /// Mostra [1] setor1, [2] setor2... e devolve o escolhido (null = voltar).
  static Setor? _escolherDaLista(List<Setor> setores) {
    while (true) {
      print('');
      for (var i = 0; i < setores.length; i++) {
        print('[${i + 1}] ${setores[i].nome}');
      }
      print('\n[0] Voltar');
      final n = int.tryParse(_ler('\nSelecione um setor:'));
      if (n == 0) return null;
      if (n != null && n >= 1 && n <= setores.length) return setores[n - 1];
      _opcaoInvalida();
    }
  }

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