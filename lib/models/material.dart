/// Representa um material/insumo usado nas manutenções do clube
class Material {
  final int? id;
  final String nome;
  final int quantidade;
  final double valorMaterial;
  final DateTime dataCompra;

  Material({
    this.id,
    required this.nome,
    required this.quantidade,
    required this.valorMaterial,
    required this.dataCompra,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'quantidade': quantidade,
      'valor_material': valorMaterial,
      'data_compra': dataCompra.toIso8601String(),
    };
  }

  factory Material.fromMap(Map<String, dynamic> map) {
    return Material(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      quantidade: map['quantidade'] as int,
      valorMaterial: (map['valor_material'] as num).toDouble(),
      dataCompra: DateTime.parse(map['data_compra'] as String),
    );
  }

  @override
  String toString() =>
      'Material(id: $id, nome: $nome, quantidade: $quantidade)';
}
