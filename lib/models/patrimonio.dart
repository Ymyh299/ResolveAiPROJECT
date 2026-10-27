/// Representa um bem patrimonial do clube (ex: uma bomba de piscina, um
/// ar-condicionado, um cortador de grama) que pode precisar de manutenção
/// e, por isso, pode "receber" Ordens de Serviço.
class Patrimonio {
  /// Opções de estado de conservação, na ordem exibida no menu.
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
  final String numeroPatrimonio;
  final double valor;
  final String estadoConservacao;
  final DateTime dataCompra;

  Patrimonio({
    this.id,
    required this.nome,
    required this.localizacaoId,
    this.descricao,
    required this.numeroPatrimonio,
    required this.valor,
    required this.estadoConservacao,
    required this.dataCompra,
  });

  /// Cria uma cópia alterando apenas os campos informados.
  Patrimonio copyWith({
    int? id,
    String? nome,
    int? localizacaoId,
    String? descricao,
    String? numeroPatrimonio,
    double? valor,
    String? estadoConservacao,
    DateTime? dataCompra,
  }) {
    return Patrimonio(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      localizacaoId: localizacaoId ?? this.localizacaoId,
      descricao: descricao ?? this.descricao,
      numeroPatrimonio: numeroPatrimonio ?? this.numeroPatrimonio,
      valor: valor ?? this.valor,
      estadoConservacao: estadoConservacao ?? this.estadoConservacao,
      dataCompra: dataCompra ?? this.dataCompra,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'localizacao_id': localizacaoId,
      'descricao': descricao,
      'numero_patrimonio': numeroPatrimonio,
      'valor': valor,
      'estado_conservacao': estadoConservacao,
      'data_compra': dataCompra.toIso8601String(),
    };
  }

  factory Patrimonio.fromMap(Map<String, dynamic> map) {
    return Patrimonio(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      localizacaoId: map['localizacao_id'] as int,
      descricao: map['descricao'] as String?,
      numeroPatrimonio: map['numero_patrimonio'] as String,
      valor: (map['valor'] as num).toDouble(),
      estadoConservacao: map['estado_conservacao'] as String,
      dataCompra: DateTime.parse(map['data_compra'] as String),
    );
  }

  @override
  String toString() =>
      'Patrimonio(id: $id, nome: $nome, numero: $numeroPatrimonio)';
}