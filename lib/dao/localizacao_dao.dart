import '../database/conexao.dart';
import '../models/localizacao.dart';

class LocalizacaoDao {
  // Devolve a localização já com o id gerado (o menu usa o id na tela de sucesso)
  Future<Localizacao> inserir(Localizacao l) async {
    final id = await Conexao.inserir('LOCALIZACAO', l.toMap());
    return l.copyWith(id: id);
  }

  Future<Localizacao?> buscarPorId(int id) async {
    final r = await Conexao.consultar(
      'SELECT * FROM LOCALIZACAO WHERE idLOCALIZACAO = :chave',
      {'chave': id},
    );
    return r.isEmpty ? null : Localizacao.fromMap(r.first);
  }

  Future<List<Localizacao>> listarTodas() async {
    final r = await Conexao.consultar(
      'SELECT * FROM LOCALIZACAO ORDER BY nome_localizacao',
    );
    return r.map(Localizacao.fromMap).toList();
  }

  Future<List<Localizacao>> buscarPorNome(String nome) async {
    final r = await Conexao.consultar(
      'SELECT * FROM LOCALIZACAO WHERE nome_localizacao LIKE :nome ORDER BY nome_localizacao',
      {'nome': '%$nome%'},
    );
    return r.map(Localizacao.fromMap).toList();
  }

  // paiId null = localizações raiz (sem superior)
  Future<List<Localizacao>> listarFilhas(int? paiId) async {
    final r = paiId == null
        ? await Conexao.consultar(
            'SELECT * FROM LOCALIZACAO WHERE LOCALIZACAO_idPAI IS NULL ORDER BY nome_localizacao',
          )
        : await Conexao.consultar(
            'SELECT * FROM LOCALIZACAO WHERE LOCALIZACAO_idPAI = :pai ORDER BY nome_localizacao',
            {'pai': paiId},
          );
    return r.map(Localizacao.fromMap).toList();
  }

  Future<int> contarFilhas(int id) => _contar(
    'SELECT COUNT(*) AS total FROM LOCALIZACAO WHERE LOCALIZACAO_idPAI = :chave',
    id,
  );

  Future<int> contarPatrimonios(int id) => _contar(
    'SELECT COUNT(*) AS total FROM PATRIMONIO WHERE LOCALIZACAO_idLOCALIZACAO = :chave',
    id,
  );

  Future<bool> atualizar(Localizacao l) =>
      Conexao.atualizar('LOCALIZACAO', 'idLOCALIZACAO', l.id!, l.toMap());

  Future<bool> excluir(int id) async =>
      await Conexao.executar(
        'DELETE FROM LOCALIZACAO WHERE idLOCALIZACAO = :chave',
        {'chave': id},
      ) >
      0;

  Future<int> _contar(String sql, int id) async {
    final r = await Conexao.consultar(sql, {'chave': id});
    return int.parse(r.first['total'].toString());
  }

  Future<List<Localizacao>> buscarRaizes() => listarFilhas(null);

  Future<List<Localizacao>> buscarFilhos(int paiId) => listarFilhas(paiId);

  // Ex.: "Área A / Sala de TI" (sobe pela hierarquia até a raiz)
  Future<String> caminhoCompleto(int id) async {
    final r = await Conexao.consultar(
      '''
    WITH RECURSIVE caminho AS (
      SELECT idLOCALIZACAO, nome_localizacao, LOCALIZACAO_idPAI, 0 AS nivel
      FROM LOCALIZACAO
      WHERE idLOCALIZACAO = :chave

      UNION ALL

      SELECT l.idLOCALIZACAO, l.nome_localizacao, l.LOCALIZACAO_idPAI, c.nivel + 1
      FROM LOCALIZACAO l
      INNER JOIN caminho c ON l.idLOCALIZACAO = c.LOCALIZACAO_idPAI
    )
    SELECT nome_localizacao FROM caminho ORDER BY nivel DESC
    ''',
      {'chave': id},
    );
    if (r.isEmpty) return '-';
    return r.map((linha) => linha['nome_localizacao']).join(' / ');
  }
}
