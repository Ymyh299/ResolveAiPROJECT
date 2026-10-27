import '../utils/utils.dart';

class Patrimonio {
  static const List<String> estados = [
    'Novo',
    'Bom',
    'Regular',
    'Ruim',
    'Irrecuperável',
  ];

  final int? id;
  final String nome;
  final int localizacaoId;
  final String? descricao;
  final double? valor;
  final String? estadoConservacao;
  final DateTime? dataCompra;

  Patrimonio({
    this.id,
    required this.nome,
    required this.localizacaoId,
    this.descricao,
    this.valor,
    this.estadoConservacao,
    this.dataCompra,
  });

  Patrimonio copyWith({
    int? id,
    String? nome,
    int? localizacaoId,
    String? descricao,
    double? valor,
    String? estadoConservacao,
    DateTime? dataCompra,
  }) {
    return Patrimonio(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      localizacaoId: localizacaoId ?? this.localizacaoId,
      descricao: descricao ?? this.descricao,
      valor: valor ?? this.valor,
      estadoConservacao: estadoConservacao ?? this.estadoConservacao,
      dataCompra: dataCompra ?? this.dataCompra,
    );
  }

  // Mapeia os atributos Dart para as colunas reais do banco.
  // O ID é gerado automaticamente pelo MySQL.
  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'valor': valor,
      'descricao': descricao,
      'estado_conservacao': estadoConservacao,
      'data_compra': gravarData(dataCompra),
      'LOCALIZACAO_idLOCALIZACAO': localizacaoId,
    };
  }

  factory Patrimonio.fromMap(Map<String, dynamic> map) {
    return Patrimonio(
      id: map['idPATRIMONIO'] as int?,
      nome: map['nome'] as String,
      localizacaoId: map['LOCALIZACAO_idLOCALIZACAO'] as int,
      descricao: map['descricao'] as String?,
      valor: lerDouble(map['valor']),
      estadoConservacao: map['estado_conservacao'] as String?,
      dataCompra: lerData(map['data_compra']),
    );
  }

  @override
  String toString() => 'Patrimonio(id: $id, nome: $nome)';
}
