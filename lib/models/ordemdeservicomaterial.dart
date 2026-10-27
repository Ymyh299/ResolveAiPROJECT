import '../utils/utils.dart';

class OrdemServicoMaterial {
  final int? id;
  final int ordemServicoId;
  final int materialId;
  final int quantidadeUtilizada;

  OrdemServicoMaterial({
    this.id,
    required this.ordemServicoId,
    required this.materialId,
    required this.quantidadeUtilizada,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ordem_servico_id': ordemServicoId,
      'material_id': materialId,
      'quantidade_utilizada': quantidadeUtilizada,
    };
  }

  factory OrdemServicoMaterial.fromMap(Map<String, dynamic> map) {
    return OrdemServicoMaterial(
      id: map['id'] as int?,
      ordemServicoId: map['ordem_servico_id'] as int,
      materialId: map['material_id'] as int,
      quantidadeUtilizada: map['quantidade_utilizada'] as int,
    );
  }

  @override
  String toString() =>
      'OrdemServicoMaterial(ordemServicoId: $ordemServicoId, materialId: $materialId, qtd: $quantidadeUtilizada)';
}
class UsoMaterialDetalhe {
  final int id;
  final int ordemServicoId;
  final int materialId;
  final String materialNome;
  final double quantidade;
  final double valorUnitario;
  final DateTime dataUso;

  UsoMaterialDetalhe({
    required this.id,
    required this.ordemServicoId,
    required this.materialId,
    required this.materialNome,
    required this.quantidade,
    required this.valorUnitario,
    required this.dataUso,
  });

  double get subtotal => quantidade * valorUnitario;

  factory UsoMaterialDetalhe.fromMap(Map<String, dynamic> map) {
    return UsoMaterialDetalhe(
      id: map['idITEM'] as int,
      ordemServicoId: map['ORDEMSERVICO_idORDEMSERVICO'] as int,
      materialId: map['MATERIAL_idMATERIAL'] as int,
      materialNome: map['nome_material'] as String,
      quantidade: lerDouble(map['quantidade_usada'])!,
      valorUnitario: lerDouble(map['valor_unitario'])!,
      dataUso: lerData(map['data_uso'])!,
    );
  }
}

