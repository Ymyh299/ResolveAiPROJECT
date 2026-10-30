/// Representa um material/insumo usado nas manutenções do clube
class Material {
  final int? id;
  final String nome;
  final double quantidade;
  final double valorMaterial;
  final DateTime dataCompra;

  Material({
    this.id,
    required this.nome,
    required this.quantidade,
    required this.valorMaterial,
    required this.dataCompra,
  });

  Material copyWith({
    int? id,
    String? nome,
    double? quantidade,
    double? valorMaterial,
    DateTime? dataCompra,
  }) {
    return Material(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      quantidade: quantidade ?? this.quantidade,
      valorMaterial: valorMaterial ?? this.valorMaterial,
      dataCompra: dataCompra ?? this.dataCompra,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'idMATERIAL': id,
      'nome': nome,
      'quantidade': quantidade,
      'valor_material': valorMaterial,
      'data_compra': dataCompra.toIso8601String(),
    };
  }

  factory Material.fromMap(Map<String, dynamic> map) {
    final idRaw = map['idMATERIAL'] ?? map['id'];
    final nomeRaw = map['nome'] ?? '';
    final quantidadeRaw = map['quantidade'] ?? 0;
    final valorRaw = map['valor_material'] ?? map['valor'] ?? 0;
    final dataCompraRaw = map['data_compra'];

    return Material(
      id: idRaw == null ? null : int.tryParse(idRaw.toString()),
      nome: nomeRaw.toString(),
      quantidade: double.tryParse(quantidadeRaw.toString()) ?? 0,
      valorMaterial: double.tryParse(valorRaw.toString()) ?? 0,
      dataCompra: DateTime.tryParse(dataCompraRaw?.toString() ?? '') ?? DateTime.now(),
    );
  }

  @override
  String toString() =>
      'Material(id: $id, nome: $nome, quantidade: $quantidade)';
}
