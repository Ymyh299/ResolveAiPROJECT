import 'package:mysql_client/mysql_client.dart';

class Database {
  //Configuração do env para a senha do banco de dados
  final apiKey = String.fromEnvironment('DB_KEY', defaultValue: '');

  // Configurações do Banco de Dados do Laboratório
  static const String _host = "127.0.0.1";
  static const int _port = 3306;
  static const String _user = "root";
  static const String _password = ""; // Senha do env a ser adicionada
  static const String _dbName = "curso_db";

  /// Método centralizado para abrir conexões
  static Future<MySQLConnection> abrirConexao() async {
    var conn = await MySQLConnection.createConnection(
      host: _host,
      port: _port,
      userName: _user,
      password: _password,
      databaseName: _dbName,
      secure: true, // Desativa SSL para o MySQL local do laboratório
    );

    await conn.connect();
    return conn;
  }
}