import 'package:dotenv/dotenv.dart';
import 'package:mysql_client/mysql_client.dart';

class Conexao {
  static MySQLConnection? _conn;

  static Future<MySQLConnection> get() async {
    if (_conn == null || !_conn!.connected) {
      final env = DotEnv()..load();
      _conn = await MySQLConnection.createConnection(
        host: env['DB_HOST']!,
        port: int.parse(env['DB_PORT']!),
        userName: env['DB_USER']!,
        password: env['DB_PASSWORD']!,
        databaseName: env['DB_NAME']!,
        secure: true,
      );
      await _conn!.connect();
    }
    return _conn!;
  }

  static Future<List<Map<String, dynamic>>> consultar(String sql,
      [Map<String, dynamic>? params]) async {
    final conn = await get();
    final r = await conn.execute(sql, params);
    return r.rows.map((row) => row.typedAssoc()).toList();
  }

  static Future<int> executar(String sql, [Map<String, dynamic>? params]) async {
    final conn = await get();
    final r = await conn.execute(sql, params);
    return r.affectedRows.toInt();
  }

  // Campos null são omitidos: o banco gera o id e aplica os DEFAULT
  static Future<int> inserir(String tabela, Map<String, dynamic> map) async {
    final dados = Map<String, dynamic>.of(map)..removeWhere((k, v) => v == null);
    final colunas = dados.keys.toList();
    final params = <String, dynamic>{};
    for (var i = 0; i < colunas.length; i++) {
      params['p${i.toString().padLeft(2, '0')}'] = dados[colunas[i]];
    }
    final marcas = params.keys.map((k) => ':$k').join(', ');

    final conn = await get();
    final r = await conn.execute(
      'INSERT INTO $tabela (${colunas.join(', ')}) VALUES ($marcas)',
      params,
    );
    return r.lastInsertID.toInt();
  }

  static Future<bool> atualizar(
      String tabela, String colunaId, int id, Map<String, dynamic> map) async {
    final dados = Map<String, dynamic>.of(map)..remove(colunaId);
    final colunas = dados.keys.toList();
    final params = <String, dynamic>{};
    final sets = <String>[];
    for (var i = 0; i < colunas.length; i++) {
      final nome = 'p${i.toString().padLeft(2, '0')}';
      params[nome] = dados[colunas[i]];
      sets.add('${colunas[i]} = :$nome');
    }
    params['chave'] = id;

    final conn = await get();
    final r = await conn.execute(
      'UPDATE $tabela SET ${sets.join(', ')} WHERE $colunaId = :chave',
      params,
    );
    return r.affectedRows.toInt() > 0;
  }
}