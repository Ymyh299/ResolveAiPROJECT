  import '../database/conexao.dart';
  import '../models/patrimonio.dart';

  class PatrimonioDao {
    Future<int> inserir(Patrimonio p) {
      return Conexao.inserir('PATRIMONIO', p.toMap());
    }

    Future<Patrimonio?> buscarPorId(int id) async {
      final resultado = await Conexao.consultar(
        'SELECT * FROM PATRIMONIO WHERE idPATRIMONIO = :chave',
        {'chave': id},
      );

      return resultado.isEmpty
          ? null
          : Patrimonio.fromMap(resultado.first);
    }

    Future<List<Patrimonio>> listar() async {
      final resultado = await Conexao.consultar(
        'SELECT * FROM PATRIMONIO ORDER BY nome',
      );

      return resultado.map(Patrimonio.fromMap).toList();
    }

    Future<List<Patrimonio>> buscarPorNome(String nome) async {
      final resultado = await Conexao.consultar(
        '''
        SELECT *
        FROM PATRIMONIO
        WHERE nome LIKE :nome
        ORDER BY nome
        ''',
        {'nome': '%$nome%'},
      );

      return resultado.map(Patrimonio.fromMap).toList();
    }

    Future<List<Patrimonio>> buscarPorEstado(String estado) async {
      final resultado = await Conexao.consultar(
        '''
        SELECT *
        FROM PATRIMONIO
        WHERE estado_conservacao = :estado
        ORDER BY nome
        ''',
        {'estado': estado},
      );

      return resultado.map(Patrimonio.fromMap).toList();
    }

    Future<List<Patrimonio>> buscarPorLocalizacao(
      int localizacaoId, {
      bool incluirSubniveis = false,
    }) async {
      if (!incluirSubniveis) {
        return listarPorLocalizacao(localizacaoId);
      }

      final resultado = await Conexao.consultar(
        '''
        WITH RECURSIVE locais AS (
          SELECT idLOCALIZACAO
          FROM LOCALIZACAO
          WHERE idLOCALIZACAO = :loc

          UNION ALL

          SELECT filha.idLOCALIZACAO
          FROM LOCALIZACAO filha
          INNER JOIN locais pai
            ON filha.LOCALIZACAO_idPAI = pai.idLOCALIZACAO
        )
        SELECT p.*
        FROM PATRIMONIO p
        INNER JOIN locais l
          ON p.LOCALIZACAO_idLOCALIZACAO = l.idLOCALIZACAO
        ORDER BY p.nome
        ''',
        {'loc': localizacaoId},
      );

      return resultado.map(Patrimonio.fromMap).toList();
    }

    Future<List<Patrimonio>> listarPorLocalizacao(
      int localizacaoId,
    ) async {
      final resultado = await Conexao.consultar(
        '''
        SELECT *
        FROM PATRIMONIO
        WHERE LOCALIZACAO_idLOCALIZACAO = :loc
        ORDER BY nome
        ''',
        {'loc': localizacaoId},
      );

      return resultado.map(Patrimonio.fromMap).toList();
    }

    Future<bool> atualizar(Patrimonio p) {
      if (p.id == null) {
        throw ArgumentError(
          'O patrimônio precisa ter um ID para ser atualizado.',
        );
      }

      return Conexao.atualizar(
        'PATRIMONIO',
        'idPATRIMONIO',
        p.id!,
        p.toMap(),
      );
    }

    Future<bool> deletar(int id) async {
      final linhasAfetadas = await Conexao.executar(
        'DELETE FROM PATRIMONIO WHERE idPATRIMONIO = :chave',
        {'chave': id},
      );

      return linhasAfetadas > 0;
    }
  }