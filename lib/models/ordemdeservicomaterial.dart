/// Classe associativa que representa o relacionamento UTILIZA.
///
/// Por que ela existe? Porque uma OrdemServico pode usar vários Materiais,
/// e um Material pode ser usado em várias OrdemServico diferentes — isso é
/// uma relação N:N, e relação N:N sempre precisa de uma "classe/tabela
/// no meio" pra funcionar, tanto em banco de dados quanto em código.
///
/// Pense nela como o "recibo" de quanto material foi gasto em cada ordem.
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
