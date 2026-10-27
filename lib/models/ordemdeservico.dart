import '../utils/utils.dart';

class OrdemDeServico {
  static const String corretiva = 'Corretiva';
  static const String preventiva = 'Preventiva';
  static const List<String> tiposValidos = [corretiva, preventiva];

  static const List<String> prioridadesValidas = [
    'Baixa',
    'Média',
    'Alta',
    'Urgente',
  ];

  static const String statusAberta = 'Aberta';
  static const String statusEmAndamento = 'Em andamento';
  static const String statusConcluida = 'Concluída';
  static const String statusCancelada = 'Cancelada';
  static const List<String> statusValidos = [
    statusAberta,
    statusEmAndamento,
    statusConcluida,
    statusCancelada,
  ];

  final int? id;
  final String titulo;
  final String? observacao;
  final DateTime? dataAbertura;
  final DateTime? dataInicio;
  final DateTime? dataFim;
  final DateTime? prazoPrevisto;
  final String prioridade;
  final String status;
  final String tipoManutencao;
  final bool recorrente;
  final int? intervaloDias;
  final int? duracaoDias;
  final DateTime? proximaData;
  final int solicitanteId;
  final int? executorId;
  final int setorId;
  final int localizacaoId;
  final int? patrimonioId;

  OrdemDeServico({
    this.id,
    required this.titulo,
    this.observacao,
    this.dataAbertura,
    this.dataInicio,
    this.dataFim,
    this.prazoPrevisto,
    required this.prioridade,
    required this.status,
    required this.tipoManutencao,
    this.recorrente = false,
    this.intervaloDias,
    this.duracaoDias,
    this.proximaData,
    required this.solicitanteId,
    this.executorId,
    required this.setorId,
    required this.localizacaoId,
    this.patrimonioId,
  });

  bool get atrasada {
    if (status == statusCancelada || status == statusConcluida) return false;
    final limite = proximaData ?? prazoPrevisto;
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    return dataFim == null && limite != null && limite.isBefore(hoje);
  }

  /// Lança ArgumentError se a OS estiver inconsistente.
  void validar() {
    if (titulo.trim().isEmpty) throw ArgumentError('O título é obrigatório.');
    if (!prioridadesValidas.contains(prioridade)) {
      throw ArgumentError('Prioridade inválida: $prioridade');
    }
    if (!statusValidos.contains(status)) {
      throw ArgumentError('Status inválido: $status');
    }
    if (!tiposValidos.contains(tipoManutencao)) {
      throw ArgumentError('Tipo de manutenção inválido: $tipoManutencao');
    }
    if (dataInicio != null && dataFim != null && dataFim!.isBefore(dataInicio!)) {
      throw ArgumentError('A data de conclusão não pode ser anterior à de início.');
    }
    if (tipoManutencao == preventiva) {
      if (!recorrente ||
          intervaloDias == null || intervaloDias! <= 0 ||
          duracaoDias == null || duracaoDias! <= 0 ||
          proximaData == null) {
        throw ArgumentError(
            'Manutenção preventiva exige recorrência com intervalo, duração e próxima data.');
      }
    } else if (recorrente) {
      throw ArgumentError('Apenas manutenção preventiva pode ser recorrente.');
    }
  }

  /// Campos null mantêm o valor atual. Para apagar a data de conclusão,
  /// use limparDataFim: true.
  OrdemDeServico copyWith({
    int? id,
    String? titulo,
    String? observacao,
    DateTime? dataAbertura,
    DateTime? dataInicio,
    DateTime? dataFim,
    bool limparDataFim = false,
    DateTime? prazoPrevisto,
    String? prioridade,
    String? status,
    String? tipoManutencao,
    bool? recorrente,
    int? intervaloDias,
    int? duracaoDias,
    DateTime? proximaData,
    int? solicitanteId,
    int? executorId,
    int? setorId,
    int? localizacaoId,
    int? patrimonioId,
  }) {
    return OrdemDeServico(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      observacao: observacao ?? this.observacao,
      dataAbertura: dataAbertura ?? this.dataAbertura,
      dataInicio: dataInicio ?? this.dataInicio,
      dataFim: limparDataFim ? null : (dataFim ?? this.dataFim),
      prazoPrevisto: prazoPrevisto ?? this.prazoPrevisto,
      prioridade: prioridade ?? this.prioridade,
      status: status ?? this.status,
      tipoManutencao: tipoManutencao ?? this.tipoManutencao,
      recorrente: recorrente ?? this.recorrente,
      intervaloDias: intervaloDias ?? this.intervaloDias,
      duracaoDias: duracaoDias ?? this.duracaoDias,
      proximaData: proximaData ?? this.proximaData,
      solicitanteId: solicitanteId ?? this.solicitanteId,
      executorId: executorId ?? this.executorId,
      setorId: setorId ?? this.setorId,
      localizacaoId: localizacaoId ?? this.localizacaoId,
      patrimonioId: patrimonioId ?? this.patrimonioId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'idORDEMSERVICO': id,
      'titulo_os': titulo,
      'observacao': observacao,
      if (dataAbertura != null) 'data_abertura': gravarDataHora(dataAbertura),
      'data_inicio': gravarDataHora(dataInicio),
      'data_fim': gravarDataHora(dataFim),
      'prazo_previsto': gravarData(prazoPrevisto),
      'prioridade': prioridade,
      'status': status,
      'tipo_manutencao': tipoManutencao,
      'recorrente': recorrente ? 1 : 0,
      'intervalo_dias': intervaloDias,
      'duracao_dias': duracaoDias,
      'proxima_data': gravarData(proximaData),
      'USUARIO_idSolicitante': solicitanteId,
      'USUARIO_idExecutor': executorId,
      'SETOR_idSETOR': setorId,
      'LOCALIZACAO_idLOCALIZACAO': localizacaoId,
      'PATRIMONIO_idPATRIMONIO': patrimonioId,
    };
  }

  factory OrdemDeServico.fromMap(Map<String, dynamic> map) {
    return OrdemDeServico(
      id: map['idORDEMSERVICO'] as int?,
      titulo: map['titulo_os'] as String,
      observacao: map['observacao'] as String?,
      dataAbertura: lerData(map['data_abertura']),
      dataInicio: lerData(map['data_inicio']),
      dataFim: lerData(map['data_fim']),
      prazoPrevisto: lerData(map['prazo_previsto']),
      prioridade: map['prioridade'] as String,
      status: map['status'] as String,
      tipoManutencao: map['tipo_manutencao'] as String,
      recorrente: map['recorrente'] == 1 || map['recorrente'] == true,
      intervaloDias: map['intervalo_dias'] as int?,
      duracaoDias: map['duracao_dias'] as int?,
      proximaData: lerData(map['proxima_data']),
      solicitanteId: map['USUARIO_idSolicitante'] as int,
      executorId: map['USUARIO_idExecutor'] as int?,
      setorId: map['SETOR_idSETOR'] as int,
      localizacaoId: map['LOCALIZACAO_idLOCALIZACAO'] as int,
      patrimonioId: map['PATRIMONIO_idPATRIMONIO'] as int?,
    );
  }

  @override
  String toString() => 'OrdemDeServico(id: $id, titulo: $titulo, status: $status)';
}