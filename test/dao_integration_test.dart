// Testes de integração dos DAOs contra um MySQL real.
// Usa o banco do .env, mas SÓ roda se DB_NAME terminar com "test"
// (para nunca apagar/alterar dados do banco de produção).
// Prepare o banco com sql/ResolveAiDatabase.sql + sql/InsertExemplo.sql.
import 'package:dotenv/dotenv.dart';
import 'package:projeto_resolveai/dao/localizacao_dao.dart';
import 'package:projeto_resolveai/dao/material_dao.dart';
import 'package:projeto_resolveai/dao/ordem_servico_dao.dart';
import 'package:projeto_resolveai/dao/ordem_servico_material_dao.dart';
import 'package:projeto_resolveai/dao/os_apoio_dao.dart';
import 'package:projeto_resolveai/dao/patrimonio_dao.dart';
import 'package:projeto_resolveai/dao/setor_dao.dart';
import 'package:projeto_resolveai/dao/usuario_dao.dart';
import 'package:projeto_resolveai/database/conexao.dart';
import 'package:projeto_resolveai/models/localizacao.dart';
import 'package:projeto_resolveai/models/material.dart';
import 'package:projeto_resolveai/models/ordemdeservico.dart';
import 'package:projeto_resolveai/models/patrimonio.dart';
import 'package:projeto_resolveai/models/setor.dart';
import 'package:projeto_resolveai/models/usuario.dart';
import 'package:test/test.dart';

void main() {
  String? skip;
  try {
    final env = DotEnv()..load();
    final nome = env['DB_NAME'] ?? '';
    if (!nome.endsWith('test')) skip = 'DB_NAME="$nome" não é banco de teste';
  } catch (e) {
    skip = 'sem .env: $e';
  }

  group('DAOs (MySQL)', skip: skip, () {
    final setorDao = SetorDao();
    final usuarioDao = UsuarioDao();
    final locDao = LocalizacaoDao();
    final patDao = PatrimonioDao();
    final matDao = MaterialDao();
    final osDao = OrdemDeServicoDao();
    final osMatDao = OrdemDeServicoMaterialDao();
    final apoio = OsApoioDao();
    final sufixo = DateTime.now().microsecondsSinceEpoch.toString();

    late int setorId, usuarioId, locRaizId, locFilhaId, patId, matId;
    late OrdemDeServico os;

    test('conexão', () async {
      final r = await Conexao.consultar('SELECT 1 AS um');
      expect(r.first['um'], 1);
    });

    test('Setor CRUD', () async {
      setorId = await setorDao.inserir(Setor(nome: 'S$sufixo', descricao: 'd'));
      expect(setorId, greaterThan(0));
      expect((await setorDao.buscarPorId(setorId))!.nome, 'S$sufixo');
      expect(await setorDao.buscarPorNome('S$sufixo'), hasLength(1));
      expect(await setorDao.listar(), isNotEmpty);
      expect(await setorDao.atualizar(Setor(id: setorId, nome: 'S2$sufixo')), isTrue);
      expect((await setorDao.buscarPorId(setorId))!.nome, 'S2$sufixo');
    });

    test('Usuario CRUD + login por hash', () async {
      final u = Usuario(
        nome: 'U$sufixo',
        cpf: sufixo.substring(sufixo.length - 11),
        telefone: '',
        email: 'u$sufixo@t.com',
        senhaHash: Usuario.gerarHash('senha1'),
        setorId: setorId,
      );
      usuarioId = await usuarioDao.inserir(u);
      final lido = (await usuarioDao.buscarPorEmail('u$sufixo@t.com'))!;
      expect(lido.id, usuarioId);
      expect(Usuario.verificarSenha('senha1', lido.senhaHash), isTrue);
      expect(lido.telefone, '');
      expect(await usuarioDao.buscarPorCpf(u.cpf), isNotNull);
      expect(await usuarioDao.buscarPorNome('U$sufixo'), hasLength(1));
      expect(await usuarioDao.buscarPorSetor(setorId), hasLength(1));
      expect(await usuarioDao.listarPorTipo(TipoUsuario.comum), isNotEmpty);
      expect(await usuarioDao.listar(limite: 2, offset: 1), hasLength(2));
      expect(await usuarioDao.contarPorSetor(setorId), 1);
      expect(await usuarioDao.atualizar(lido.copyWith(nome: 'U2$sufixo')), isTrue);
      expect((await usuarioDao.buscarPorId(usuarioId))!.nome, 'U2$sufixo');
    });

    test('usuários do InsertExemplo.sql conseguem logar com 123456', () async {
      final admin = await usuarioDao.buscarPorEmail('admin@resolveai.com');
      expect(admin, isNotNull);
      expect(Usuario.verificarSenha('123456', admin!.senhaHash), isTrue,
          reason: 'seed usa SHA2() puro, o app usa salt:hash iterado');
    });

    test('Localizacao hierarquia', () async {
      final raiz = await locDao.inserir(Localizacao(nome: 'R$sufixo'));
      locRaizId = raiz.id!;
      final filha = await locDao.inserir(Localizacao(nome: 'F$sufixo', paiId: locRaizId));
      locFilhaId = filha.id!;
      expect(await locDao.caminhoCompleto(locFilhaId), 'R$sufixo / F$sufixo');
      expect(await locDao.contarFilhas(locRaizId), 1);
      expect((await locDao.listarFilhas(locRaizId)).single.id, locFilhaId);
      expect((await locDao.buscarRaizes()).any((l) => l.id == locRaizId), isTrue);
      expect(await locDao.buscarPorNome('F$sufixo'), hasLength(1));
      expect(await locDao.listarTodas(), isNotEmpty);
      expect(await locDao.atualizar(filha.copyWith(nome: 'F2$sufixo')), isTrue);
      expect((await locDao.buscarPorId(locFilhaId))!.nome, 'F2$sufixo');
    });

    test('Patrimonio CRUD + busca recursiva', () async {
      patId = await patDao.inserir(Patrimonio(
          nome: 'P$sufixo', localizacaoId: locFilhaId, valor: 150.5,
          estadoConservacao: 'Bom', dataCompra: DateTime(2025, 6, 1)));
      final p = (await patDao.buscarPorId(patId))!;
      expect(p.valor, 150.5);
      expect(p.dataCompra, DateTime(2025, 6, 1));
      expect(await patDao.buscarPorNome('P$sufixo'), hasLength(1));
      expect(await patDao.buscarPorEstado('Bom'), isNotEmpty);
      expect(await patDao.buscarPorLocalizacao(locRaizId), isEmpty);
      expect(await patDao.buscarPorLocalizacao(locRaizId, incluirSubniveis: true), hasLength(1));
      expect(await locDao.contarPatrimonios(locFilhaId), 1);
      expect(await patDao.listar(), isNotEmpty);
      expect(await patDao.atualizar(p.copyWith(nome: 'P2$sufixo')), isTrue);
    });

    test('Material inserir (data_compra) e estoque', () async {
      final m = await matDao.inserir(Material(
          nome: 'M$sufixo', quantidade: 5, valorMaterial: 2.5,
          dataCompra: DateTime(2026, 1, 10)));
      matId = m.id!;
      expect((await matDao.buscarPorId(matId))!.dataCompra, DateTime(2026, 1, 10));
      expect(await matDao.registrarEntrada(
          id: matId, quantidade: 3, valorUnitario: 3, dataCompra: DateTime(2026, 2, 1)), isTrue);
      final lido = (await matDao.buscarPorId(matId))!;
      expect(lido.quantidade, 8);
      expect(lido.valorMaterial, 3);
      expect((await matDao.listarEstoqueBaixo(10)).any((x) => x.id == matId), isTrue);
      expect(await matDao.listarSemEstoque(), isA<List<Material>>());
      expect(await matDao.buscarPorNome('M$sufixo'), hasLength(1));
      expect(await matDao.listarTodos(), isNotEmpty);
      expect(await matDao.atualizar(lido.copyWith(nome: 'M2$sufixo')), isTrue);
    });

    test('OrdemDeServico inserir/consultas', () async {
      final nova = OrdemDeServico(
        titulo: 'OS$sufixo',
        prioridade: 'Alta',
        status: OrdemDeServico.statusAberta,
        tipoManutencao: OrdemDeServico.corretiva,
        prazoPrevisto: DateTime(2020, 1, 1),
        solicitanteId: usuarioId,
        executorId: usuarioId,
        setorId: setorId,
        localizacaoId: locFilhaId,
        patrimonioId: patId,
      )..validar();
      os = await osDao.inserir(nova);
      expect(os.id, isNotNull);
      expect(os.dataAbertura, isNotNull);
      expect(os.atrasada, isTrue);
      final hoje = DateTime.now();
      expect(await osDao.listarTodas(), isNotEmpty);
      expect(await osDao.listarPorStatus('Aberta'), isNotEmpty);
      expect(await osDao.listarPorPrioridade('Alta'), isNotEmpty);
      expect(await osDao.listarPorSetor(setorId), hasLength(1));
      expect(await osDao.listarPorPeriodo(hoje, hoje), isNotEmpty);
      expect(await osDao.buscarPorTitulo('OS$sufixo'), hasLength(1));
      expect(await osDao.buscarPorSolicitanteNome('U2$sufixo'), hasLength(1));
      expect(await osDao.buscarPorExecutorNome('U2$sufixo'), hasLength(1));
      expect(await osDao.listarPorSolicitante(usuarioId), hasLength(1));
      expect(await osDao.listarPorExecutor(usuarioId), hasLength(1));
      expect(await osDao.listarPorPatrimonio(patId), hasLength(1));
      expect((await osDao.listarAtrasadas()).any((x) => x.id == os.id), isTrue);
      expect(await osDao.existePorPatrimonio(patId), isTrue);
      expect(await osDao.existePorUsuario(usuarioId), isTrue);
      final concluida = os.copyWith(
          status: OrdemDeServico.statusConcluida,
          dataInicio: DateTime(2026, 1, 1, 8),
          dataFim: DateTime(2026, 1, 1, 10));
      expect(await osDao.atualizar(concluida), isTrue);
      expect((await osDao.buscarPorId(os.id!))!.status, 'Concluída');
    });

    test('OS preventiva renovar', () async {
      final p = await osDao.inserir(OrdemDeServico(
        titulo: 'PREV$sufixo',
        prioridade: 'Baixa',
        status: OrdemDeServico.statusAberta,
        tipoManutencao: OrdemDeServico.preventiva,
        recorrente: true,
        intervaloDias: 30,
        duracaoDias: 1,
        proximaData: DateTime(2026, 1, 1),
        solicitanteId: usuarioId,
        setorId: setorId,
        localizacaoId: locFilhaId,
      )..validar());
      expect(await osDao.renovarPreventiva(p.id!), isTrue);
      expect((await osDao.buscarPorId(p.id!))!.proximaData, DateTime(2026, 1, 31));
      await osDao.excluir(p.id!);
      expect(await osDao.buscarPorId(p.id!), isNull);
    });

    test('Uso de material em OS (estoque e custo)', () async {
      final item = await osMatDao.registrarUso(os.id!, matId, 2);
      expect((await matDao.buscarPorId(matId))!.quantidade, 6);
      expect(await osMatDao.custoTotalDaOs(os.id!), 6.0);
      expect(await osMatDao.listarPorOs(os.id!), hasLength(1));
      expect(await osMatDao.listarPorMaterial(matId), hasLength(1));
      final hoje = DateTime.now();
      expect(await osMatDao.listarPorPeriodo(hoje, hoje), isNotEmpty);
      await expectLater(osMatDao.registrarUso(os.id!, matId, 999), throwsException);
      expect((await matDao.buscarPorId(matId))!.quantidade, 6);
      await osMatDao.removerUso(item);
      expect((await matDao.buscarPorId(matId))!.quantidade, 8);
      await osMatDao.registrarUso(os.id!, matId, 1);
    });

    test('OsApoioDao', () async {
      expect(await apoio.nomeUsuario(usuarioId), 'U2$sufixo');
      expect(await apoio.nomeSetor(setorId), 'S2$sufixo');
      expect(await apoio.nomePatrimonio(patId), 'P2$sufixo');
      expect(await apoio.listarSetores(), isNotEmpty);
      expect(await apoio.listarPatrimoniosPorLocalizacao(locFilhaId), hasLength(1));
      expect((await apoio.sugerirExecutor(setorId))!.id, usuarioId);
      expect(await apoio.buscarExecutoresPorNome('U2$sufixo'), hasLength(1));
      expect(await apoio.listarExecutoresDisponiveis(), isNotEmpty);
    });

    test('OsApoioDao.listarMateriaisUtilizados', () async {
      final l = await apoio.listarMateriaisUtilizados(os.id!);
      expect(l.single, startsWith('M2$sufixo'));
    });

    test('limpeza: exclusões', () async {
      await osDao.excluir(os.id!);
      expect(await matDao.excluir(matId), isTrue);
      expect(await patDao.deletar(patId), isTrue);
      expect(await locDao.excluir(locFilhaId), isTrue);
      expect(await locDao.excluir(locRaizId), isTrue);
      expect(await usuarioDao.excluir(usuarioId), isTrue);
      expect(await setorDao.excluir(setorId), isTrue);
    });

    tearDownAll(() async => (await Conexao.get()).close());
  });
}
