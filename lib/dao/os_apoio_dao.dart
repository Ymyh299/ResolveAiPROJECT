import '../database/conexao.dart';
import '../models/ordemdeservico.dart';
import '../models/patrimonio.dart';
import '../models/setor.dart';
import '../utils/utils.dart';

class ExecutorRef {
  final int id;
  final String nome;
  final String setorNome;

  ExecutorRef(this.id, this.nome, this.setorNome);

  factory ExecutorRef.fromMap(Map<String, dynamic> m) => ExecutorRef(
        m['idUSUARIO'] as int,
        m['nome'] as String,
        m['setor_nome'] as String,
      );
}

class OsApoioDao {
  Future<String?> nomeUsuario(int id) =>
      _nome('SELECT nome FROM USUARIO WHERE idUSUARIO = :chave', id);

  Future<String?> nomeSetor(int id) =>
      _nome('SELECT nome FROM SETOR WHERE idSETOR = :chave', id);

  Future<String?> nomePatrimonio(int id) =>
      _nome('SELECT nome FROM PATRIMONIO WHERE idPATRIMONIO = :chave', id);

  Future<List<Setor>> listarSetores() async {
    final r = await Conexao.consultar('SELECT * FROM SETOR ORDER BY nome');
    return r.map(Setor.fromMap).toList();
  }

  Future<List<Patrimonio>> listarPatrimoniosPorLocalizacao(int localizacaoId) async {
    final r = await Conexao.consultar(
      'SELECT * FROM PATRIMONIO WHERE LOCALIZACAO_idLOCALIZACAO = :loc ORDER BY nome',
      {'loc': localizacaoId},
    );
    return r.map(Patrimonio.fromMap).toList();
  }

  // Sugere quem do setor tem menos OS em aberto
  Future<ExecutorRef?> sugerirExecutor(int setorId) async {
    final lista = await _executores('WHERE u.SETOR_idSETOR = :setor', {'setor': setorId});
    return lista.isEmpty ? null : lista.first;
  }

  Future<List<ExecutorRef>> buscarExecutoresPorNome(String nome) =>
      _executores('WHERE u.nome LIKE :nome', {'nome': '%$nome%'});

  Future<List<ExecutorRef>> listarExecutoresDisponiveis() => _executores('');

  // Cada item já vem formatado para exibição
  Future<List<String>> listarMateriaisUtilizados(int osId) async {
    final r = await Conexao.consultar(
      '''SELECT m.nome_material, i.quantidade_usada, i.valor_unitario
          FROM ORDEMSERVICO_has_MATERIAL i
          JOIN MATERIAL m ON m.idMATERIAL = i.MATERIAL_idMATERIAL
          WHERE i.ORDEMSERVICO_idORDEMSERVICO = :os
          ORDER BY m.nome_material''',
      {'os': osId},
    );
    return r.map((linha) {
      final qtd = lerDouble(linha['quantidade_usada'])!;
      final valor = lerDouble(linha['valor_unitario'])!;
      final qtdTexto =
          qtd == qtd.truncateToDouble() ? qtd.toInt().toString() : qtd.toStringAsFixed(2);
      return '${linha['nome_material']} — $qtdTexto x R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
    }).toList();
  }

  Future<String?> _nome(String sql, int id) async {
    final r = await Conexao.consultar(sql, {'chave': id});
    return r.isEmpty ? null : r.first['nome'] as String;
  }

  Future<List<ExecutorRef>> _executores(String where,
      [Map<String, dynamic>? params]) async {
    final r = await Conexao.consultar(
        '''SELECT u.idUSUARIO, u.nome, s.nome AS setor_nome
          FROM USUARIO u
          JOIN SETOR s ON s.idSETOR = u.SETOR_idSETOR
          $where
          ORDER BY
            (SELECT COUNT(*) FROM ORDEMSERVICO os
              WHERE os.USUARIO_idExecutor = u.idUSUARIO
                AND os.data_fim IS NULL
                AND os.status <> :cancelada),
            u.nome''',
      {...?params, 'cancelada': OrdemDeServico.statusCancelada},
    );
    return r.map(ExecutorRef.fromMap).toList();
  }
}