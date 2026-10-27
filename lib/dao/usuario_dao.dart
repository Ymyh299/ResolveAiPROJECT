import '../database/conexao.dart';
import '../models/usuario.dart';

class UsuarioDao {
  Future<int> inserir(Usuario u) => Conexao.inserir('USUARIO', u.toMap());

  Future<Usuario?> buscarPorId(int id) async {
    final r = await Conexao.consultar(
        'SELECT * FROM USUARIO WHERE idUSUARIO = :chave', {'chave': id});
    return r.isEmpty ? null : Usuario.fromMap(r.first);
  }

  // Usado no login
  Future<Usuario?> buscarPorEmail(String email) async {
    final r = await Conexao.consultar(
        'SELECT * FROM USUARIO WHERE email = :email', {'email': email});
    return r.isEmpty ? null : Usuario.fromMap(r.first);
  }

  Future<Usuario?> buscarPorCpf(String cpf) async {
    final r = await Conexao.consultar(
        'SELECT * FROM USUARIO WHERE cpf = :cpf', {'cpf': cpf});
    return r.isEmpty ? null : Usuario.fromMap(r.first);
  }

  Future<List<Usuario>> buscarPorNome(String nome) => _lista(
      'SELECT * FROM USUARIO WHERE nome LIKE :nome ORDER BY nome',
      {'nome': '%$nome%'});

  Future<List<Usuario>> buscarPorSetor(int setorId) => _lista(
      'SELECT * FROM USUARIO WHERE SETOR_idSETOR = :setor ORDER BY nome',
      {'setor': setorId});

  Future<List<Usuario>> listarPorTipo(TipoUsuario tipo) => _lista(
      'SELECT * FROM USUARIO WHERE tipo_usuario = :tipo ORDER BY nome',
      {'tipo': tipo.name});

  // Sem limite lista todos; com limite pagina (os valores são int, seguros no SQL)
  Future<List<Usuario>> listar({int? limite, int offset = 0}) {
    final paginacao = limite == null ? '' : ' LIMIT $limite OFFSET $offset';
    return _lista('SELECT * FROM USUARIO ORDER BY nome$paginacao');
  }

  Future<int> contarPorSetor(int setorId) async {
    final r = await Conexao.consultar(
      'SELECT COUNT(*) AS total FROM USUARIO WHERE SETOR_idSETOR = :setor',
      {'setor': setorId},
    );
    return int.parse(r.first['total'].toString());
  }

  Future<bool> atualizar(Usuario u) =>
      Conexao.atualizar('USUARIO', 'idUSUARIO', u.id!, u.toMap());

  Future<bool> excluir(int id) async =>
      await Conexao.executar(
          'DELETE FROM USUARIO WHERE idUSUARIO = :chave', {'chave': id}) > 0;

  Future<List<Usuario>> _lista(String sql, [Map<String, dynamic>? params]) async {
    final r = await Conexao.consultar(sql, params);
    return r.map(Usuario.fromMap).toList();
  }
}