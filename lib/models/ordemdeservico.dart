import 'statusordemdeservico.dart';

class OrdemServico {
  final int? id;
  final String tipoManutencao; // ex: "preventiva", "corretiva"
  final DateTime dataInicio;
  final DateTime? dataFim;
  final StatusOrdemServico status;
  final String? observacao;
  final int patrimonioId; // qual bem está sendo atendido
  final int usuarioId; // quem registrou a ordem

  OrdemServico({
    this.id,
    required this.tipoManutencao,
    DateTime? dataInicio,
    this.dataFim,
    this.status = StatusOrdemServico.aberta, // toda OS nasce como "aberta"
    this.observacao,
    required this.patrimonioId,
    required this.usuarioId,
  }) : dataInicio = dataInicio ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tipo_manutencao': tipoManutencao,
      'data_inicio': dataInicio.toIso8601String(),
      'data_fim': dataFim?.toIso8601String(),
      'status': status.toValue(),
      'observacao': observacao,
      'patrimonio_id': patrimonioId,
      'usuario_id': usuarioId,
    };
  }

  factory OrdemServico.fromMap(Map<String, dynamic> map) {
    return OrdemServico(
      id: map['id'] as int?,
      tipoManutencao: map['tipo_manutencao'] as String,
      dataInicio: DateTime.parse(map['data_inicio'] as String),
      dataFim: map['data_fim'] != null
          ? DateTime.parse(map['data_fim'] as String)
          : null,
      status: StatusOrdemServico.fromValue(map['status'] as String),
      observacao: map['observacao'] as String?,
      patrimonioId: map['patrimonio_id'] as int,
      usuarioId: map['usuario_id'] as int,
    );
  }

  /// Cria uma cópia da ordem com alguns campos alterados — útil, por
  /// exemplo, pra fechar a ordem (mudar status e preencher dataFim) sem
  /// precisar recriar o objeto inteiro do zero.
  OrdemServico copyWith({
    StatusOrdemServico? status,
    DateTime? dataFim,
    String? observacao,
  }) {
    return OrdemServico(
      id: id,
      tipoManutencao: tipoManutencao,
      dataInicio: dataInicio,
      dataFim: dataFim ?? this.dataFim,
      status: status ?? this.status,
      observacao: observacao ?? this.observacao,
      patrimonioId: patrimonioId,
      usuarioId: usuarioId,
    );
  }

  @override
  String toString() =>
      'OrdemServico(id: $id, tipo: $tipoManutencao, status: ${status.toValue()})';
}
