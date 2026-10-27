import '../database/conexao.dart';
import '../models/ordemdeservico.dart';
import '../utils/utils.dart';

class OrdemDeServicoDao {
  // Devolve a OS já como está no banco (com id e data de abertura)
  Future<OrdemDeServico> inserir(OrdemDeServico os) async {
    final id = await Conexao.inserir('ORDEMSERVICO', os.toMap());
    return (await buscarPorId(id))!;
  }

  Future<OrdemDeServico?> buscarPorId(int id) async {
    final r = await Conexao.consultar(
      'SELECT * FROM ORDEMSERVICO WHERE idORDEMSERVICO = :chave',
      {'chave': id},
    );
    return r.isEmpty ? null : OrdemDeServico.fromMap(r.first);
  }

  Future<List<OrdemDeServico>> listarTodas() =>
      _lista('SELECT * FROM ORDEMSERVICO ORDER BY data_abertura DESC');

  Future<List<OrdemDeServico>> listarPorStatus(String status) => _lista(
    'SELECT * FROM ORDEMSERVICO WHERE status = :status ORDER BY data_abertura DESC',
    {'status': status},
  );

  Future<List<OrdemDeServico>> listarPorPrioridade(String prioridade) => _lista(
    'SELECT * FROM ORDEMSERVICO WHERE prioridade = :prioridade ORDER BY data_abertura DESC',
    {'prioridade': prioridade},
  );

  Future<List<OrdemDeServico>> listarPorSetor(int setorId) => _lista(
    'SELECT * FROM ORDEMSERVICO WHERE SETOR_idSETOR = :setor ORDER BY data_abertura DESC',
    {'setor': setorId},
  );

  // Pela data de abertura, incluindo o último dia
  Future<List<OrdemDeServico>> listarPorPeriodo(DateTime inicio, DateTime fim) =>
      _lista(
        '''SELECT * FROM ORDEMSERVICO
            WHERE DATE(data_abertura) BETWEEN :inicio AND :fim
            ORDER BY data_abertura DESC''',
        {'inicio': gravarData(inicio), 'fim': gravarData(fim)},
      );

  Future<List<OrdemDeServico>> buscarPorTitulo(String texto) => _lista(
    'SELECT * FROM ORDEMSERVICO WHERE titulo_os LIKE :texto ORDER BY data_abertura DESC',
    {'texto': '%$texto%'},
  );

  Future<List<OrdemDeServico>> buscarPorSolicitanteNome(String nome) => _lista(
    '''SELECT os.* FROM ORDEMSERVICO os
        JOIN USUARIO u ON u.idUSUARIO = os.USUARIO_idSolicitante
        WHERE u.nome LIKE :nome
        ORDER BY os.data_abertura DESC''',
    {'nome': '%$nome%'},
  );

  Future<List<OrdemDeServico>> buscarPorExecutorNome(String nome) => _lista(
    '''SELECT os.* FROM ORDEMSERVICO os
        JOIN USUARIO u ON u.idUSUARIO = os.USUARIO_idExecutor
        WHERE u.nome LIKE :nome
        ORDER BY os.data_abertura DESC''',
    {'nome': '%$nome%'},
  );

  Future<List<OrdemDeServico>> listarPorSolicitante(int usuarioId) => _lista(
    'SELECT * FROM ORDEMSERVICO WHERE USUARIO_idSolicitante = :usuario ORDER BY data_abertura DESC',
    {'usuario': usuarioId},
  );

  Future<List<OrdemDeServico>> listarPorExecutor(int usuarioId) => _lista(
    'SELECT * FROM ORDEMSERVICO WHERE USUARIO_idExecutor = :usuario ORDER BY data_abertura DESC',
    {'usuario': usuarioId},
  );

  Future<List<OrdemDeServico>> listarPorPatrimonio(int patrimonioId) => _lista(
    'SELECT * FROM ORDEMSERVICO WHERE PATRIMONIO_idPATRIMONIO = :pat ORDER BY data_abertura DESC',
    {'pat': patrimonioId},
  );

  // Atrasada é calculada aqui, não existe coluna
  Future<List<OrdemDeServico>> listarAtrasadas() => _lista(
    '''SELECT * FROM ORDEMSERVICO
        WHERE data_fim IS NULL
          AND status <> :cancelada
          AND COALESCE(proxima_data, prazo_previsto) < CURDATE()
        ORDER BY COALESCE(proxima_data, prazo_previsto)''',
    {'cancelada': OrdemDeServico.statusCancelada},
  );

  Future<bool> atualizar(OrdemDeServico os) =>
      Conexao.atualizar('ORDEMSERVICO', 'idORDEMSERVICO', os.id!, os.toMap());

  // Preventiva: avança o lembrete para o próximo ciclo
  Future<bool> renovarPreventiva(int osId) async =>
      await Conexao.executar(
        '''UPDATE ORDEMSERVICO
            SET proxima_data = DATE_ADD(COALESCE(proxima_data, CURDATE()), INTERVAL intervalo_dias DAY)
            WHERE idORDEMSERVICO = :os AND recorrente = 1''',
        {'os': osId},
      ) > 0;

  Future<bool> existePorPatrimonio(int patrimonioId) async {
    final r = await Conexao.consultar(
      'SELECT 1 AS existe FROM ORDEMSERVICO WHERE PATRIMONIO_idPATRIMONIO = :pat LIMIT 1',
      {'pat': patrimonioId},
    );
    return r.isNotEmpty;
  }

  Future<bool> existePorUsuario(int usuarioId) async {
    final r = await Conexao.consultar(
      '''SELECT 1 AS existe FROM ORDEMSERVICO
          WHERE USUARIO_idSolicitante = :u1 OR USUARIO_idExecutor = :u2
          LIMIT 1''',
      {'u1': usuarioId, 'u2': usuarioId},
    );
    return r.isNotEmpty;
  }

  // Apaga primeiro os materiais da OS (FK) e depois a OS
  Future<void> excluir(int osId) async {
    final conn = await Conexao.get();
    await conn.transactional((tx) async {
      await tx.execute(
        'DELETE FROM ORDEMSERVICO_has_MATERIAL WHERE ORDEMSERVICO_idORDEMSERVICO = :os',
        {'os': osId},
      );
      await tx.execute(
        'DELETE FROM ORDEMSERVICO WHERE idORDEMSERVICO = :os',
        {'os': osId},
      );
    });
  }

  Future<List<OrdemDeServico>> _lista(
    String sql, [
    Map<String, dynamic>? params,
  ]) async {
    final r = await Conexao.consultar(sql, params);
    return r.map(OrdemDeServico.fromMap).toList();
  }
}