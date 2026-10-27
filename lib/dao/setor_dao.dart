import '../database/conexao.dart';
import '../models/setor.dart';

class SetorDao {
  Future<int> inserir(Setor s) => Conexao.inserir('SETOR', s.toMap());

  Future<Setor?> buscarPorId(int id) async {
    final r = await Conexao.consultar(
        'SELECT * FROM SETOR WHERE idSETOR = :chave', {'chave': id});
    return r.isEmpty ? null : Setor.fromMap(r.first);
  }

  Future<List<Setor>> buscarPorNome(String nome) async {
    final r = await Conexao.consultar(
      'SELECT * FROM SETOR WHERE nome LIKE :nome ORDER BY nome',
      {'nome': '%$nome%'},
    );
    return r.map(Setor.fromMap).toList();
  }

  Future<List<Setor>> listar() async {
    final r = await Conexao.consultar('SELECT * FROM SETOR ORDER BY nome');
    return r.map(Setor.fromMap).toList();
  }

  Future<bool> atualizar(Setor s) =>
      Conexao.atualizar('SETOR', 'idSETOR', s.id!, s.toMap());

  Future<bool> excluir(int id) async =>
      await Conexao.executar(
          'DELETE FROM SETOR WHERE idSETOR = :chave', {'chave': id}) > 0;
}