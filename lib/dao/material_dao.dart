import '../database/conexao.dart';
import '../models/material.dart';
import '../utils/utils.dart';

class MaterialDao {
  // Devolve o material já com o id gerado (o menu usa o id na tela de sucesso)
  Future<Material> inserir(Material m) async {
    final id = await Conexao.inserir('MATERIAL', m.toMap());
    return m.copyWith(id: id);
  }

  Future<Material?> buscarPorId(int id) async {
    final r = await Conexao.consultar(
        'SELECT * FROM MATERIAL WHERE idMATERIAL = :chave', {'chave': id});
    return r.isEmpty ? null : Material.fromMap(r.first);
  }

  Future<List<Material>> buscarPorNome(String nome) => _lista(
      'SELECT * FROM MATERIAL WHERE nome_material LIKE :nome ORDER BY nome_material',
      {'nome': '%$nome%'});

  Future<List<Material>> listarTodos() =>
      _lista('SELECT * FROM MATERIAL ORDER BY nome_material');

  // Estoque baixo: acima de zero e até o limite (zerados ficam em listarSemEstoque)
  Future<List<Material>> listarEstoqueBaixo(double limite) => _lista(
      '''SELECT * FROM MATERIAL
          WHERE quantidade_estoque > 0 AND quantidade_estoque <= :limite
          ORDER BY quantidade_estoque''',
      {'limite': limite});

  Future<List<Material>> listarSemEstoque() => _lista(
      'SELECT * FROM MATERIAL WHERE quantidade_estoque <= 0 ORDER BY nome_material');

  // Não mexe no estoque: quem altera a quantidade é registrarEntrada e o uso em OS
  Future<bool> atualizar(Material m) => Conexao.atualizar(
        'MATERIAL',
        'idMATERIAL',
        m.id!,
        {
          'nome_material': m.nome,
          'valor': m.valorMaterial,
          'data_compra': gravarData(m.dataCompra),
        },
      );

  // Soma ao estoque e passa a valer o preço e a data da última compra
  Future<bool> registrarEntrada({
    required int id,
    required double quantidade,
    required double valorUnitario,
    required DateTime dataCompra,
  }) async =>
      await Conexao.executar(
        '''UPDATE MATERIAL
            SET quantidade_estoque = quantidade_estoque + :qtd,
                valor = :valor,
                data_compra = :data
            WHERE idMATERIAL = :chave''',
        {
          'qtd': quantidade,
          'valor': valorUnitario,
          'data': gravarData(dataCompra),
          'chave': id,
        },
      ) > 0;

  Future<bool> excluir(int id) async =>
      await Conexao.executar(
          'DELETE FROM MATERIAL WHERE idMATERIAL = :chave', {'chave': id}) > 0;

  Future<List<Material>> _lista(String sql, [Map<String, dynamic>? params]) async {
    final r = await Conexao.consultar(sql, params);
    return r.map(Material.fromMap).toList();
  }
}