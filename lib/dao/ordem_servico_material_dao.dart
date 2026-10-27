import '../database/conexao.dart';
import '../models/ordemdeservicomaterial.dart';
import '../utils/utils.dart';

class OrdemDeServicoMaterialDao {
  Future<int> registrarUso(int osId, int materialId, double quantidade) async {
    final conn = await Conexao.get();

    return await conn.transactional((tx) async {
      final r = await tx.execute(
        'SELECT quantidade_estoque, valor FROM MATERIAL WHERE idMATERIAL = :mat FOR UPDATE',
        {'mat': materialId},
      );
      if (r.rows.isEmpty) throw Exception('Material não encontrado');

      final dados = r.rows.first.typedAssoc();
      final estoque = lerDouble(dados['quantidade_estoque'])!;
      final valor = lerDouble(dados['valor'])!;
      if (estoque < quantidade) {
        throw Exception('Estoque insuficiente (disponível: $estoque)');
      }

      final ins = await tx.execute(
        '''INSERT INTO ORDEMSERVICO_has_MATERIAL
            (ORDEMSERVICO_idORDEMSERVICO, MATERIAL_idMATERIAL, quantidade_usada, valor_unitario)
            VALUES (:os, :mat, :qtd, :valor)''',
        {'os': osId, 'mat': materialId, 'qtd': quantidade, 'valor': valor},
      );

      await tx.execute(
        'UPDATE MATERIAL SET quantidade_estoque = quantidade_estoque - :qtd WHERE idMATERIAL = :mat',
        {'qtd': quantidade, 'mat': materialId},
      );

      return ins.lastInsertID.toInt();
    });
  }

  // Remove o item da OS e devolve a quantidade ao estoque
  Future<void> removerUso(int idItem) async {
    final conn = await Conexao.get();

    await conn.transactional((tx) async {
      final r = await tx.execute(
        'SELECT MATERIAL_idMATERIAL, quantidade_usada FROM ORDEMSERVICO_has_MATERIAL WHERE idITEM = :item',
        {'item': idItem},
      );
      if (r.rows.isEmpty) throw Exception('Item não encontrado');

      final dados = r.rows.first.typedAssoc();
      final materialId = dados['MATERIAL_idMATERIAL'];
      final quantidade = lerDouble(dados['quantidade_usada'])!;

      await tx.execute(
        'UPDATE MATERIAL SET quantidade_estoque = quantidade_estoque + :qtd WHERE idMATERIAL = :mat',
        {'qtd': quantidade, 'mat': materialId},
      );
      await tx.execute(
        'DELETE FROM ORDEMSERVICO_has_MATERIAL WHERE idITEM = :item',
        {'item': idItem},
      );
    });
  }

  Future<List<UsoMaterialDetalhe>> listarPorOs(int osId) => _detalhes(
        'WHERE i.ORDEMSERVICO_idORDEMSERVICO = :os',
        {'os': osId},
      );

  Future<List<UsoMaterialDetalhe>> listarPorMaterial(int materialId) => _detalhes(
        'WHERE i.MATERIAL_idMATERIAL = :mat',
        {'mat': materialId},
      );

  // Pela data de uso, incluindo o último dia
  Future<List<UsoMaterialDetalhe>> listarPorPeriodo(DateTime inicio, DateTime fim) =>
      _detalhes(
        'WHERE DATE(i.data_uso) BETWEEN :inicio AND :fim',
        {'inicio': gravarData(inicio), 'fim': gravarData(fim)},
      );

  Future<double> custoTotalDaOs(int osId) async {
    final r = await Conexao.consultar(
      '''SELECT COALESCE(SUM(quantidade_usada * valor_unitario), 0) AS total
          FROM ORDEMSERVICO_has_MATERIAL WHERE ORDEMSERVICO_idORDEMSERVICO = :os''',
      {'os': osId},
    );
    return lerDouble(r.first['total'])!;
  }

  Future<List<UsoMaterialDetalhe>> _detalhes(
      String where, Map<String, dynamic> params) async {
    final r = await Conexao.consultar(
      '''SELECT i.idITEM, i.ORDEMSERVICO_idORDEMSERVICO, i.MATERIAL_idMATERIAL,
                m.nome_material, i.quantidade_usada, i.valor_unitario, i.data_uso
          FROM ORDEMSERVICO_has_MATERIAL i
          JOIN MATERIAL m ON m.idMATERIAL = i.MATERIAL_idMATERIAL
          $where
          ORDER BY i.data_uso DESC, i.idITEM DESC''',
      params,
    );
    return r.map(UsoMaterialDetalhe.fromMap).toList();
  }
}