import 'statusordemdeservico.dart';

/// Espelha a tabela ORDEMSERVICO. As chaves de toMap/fromMap são EXATAMENTE
/// os nomes das colunas do banco, para o DAO não precisar traduzir nada.
class OrdemServico {
  // Valores permitidos (o banco não tem CHECK, então quem garante é o validar()).
  static const String corretiva = 'Corretiva';
  static const String preventiva = 'Preventiva';
  static const List<String> tiposValidos = [corretiva, preventiva];
  static const List<String> prioridadesValidas = ['Baixa', 'Média', 'Alta'];

  final int? id;
  final String titulo;
  final String? observacao;
  final DateTime dataAbertura; // nasce com a OS
  final DateTime? dataInicio; // preenchida quando o executor assume
  final DateTime? dataFim;
  final DateTime? prazoPrevisto; // definido só pelo Administrador
  final String prioridade; // 'Baixa', 'Média' ou 'Alta'
  final StatusOrdemServico status;
  final String tipoManutencao; // 'Corretiva' ou 'Preventiva'

  // Recorrência (só faz sentido para preventiva)
  final bool recorrente;
  final int? intervaloDias;
  final int? duracaoDias; // quanto tempo leva cada execução
  final DateTime? proximaData;

  final int usuarioSolicitanteId; // quem registrou
  final int? usuarioExecutorId; // nulo até alguém assumir
  final int setorId; // setor responsável
  final int localizacaoId; // sempre obrigatória
  final int? patrimonioId; // opcional: problema geral não tem patrimônio

  OrdemServico({
    this.id,
    required this.titulo,
    this.observacao,
    DateTime? dataAbertura,
    this.dataInicio,
    this.dataFim,
    this.prazoPrevisto,
    this.prioridade = 'Média',
    this.status = StatusOrdemServico.aberta, // toda OS nasce "aberta"
    required this.tipoManutencao,
    this.recorrente = false,
    this.intervaloDias,
    this.duracaoDias,
    this.proximaData,
    required this.usuarioSolicitanteId,
    this.usuarioExecutorId,
    required this.setorId,
    required this.localizacaoId,
    this.patrimonioId,
  }) : dataAbertura = dataAbertura ?? DateTime.now();

  /// "Atrasada" não é gravada no banco: é calculada, igual à regra da view.
  bool get estaAtrasada {
    final prazo = prazoPrevisto;
    if (prazo == null) return false;
    if (status == StatusOrdemServico.concluida ||
        status == StatusOrdemServico.cancelada) {
      return false;
    }
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final limite = DateTime(prazo.year, prazo.month, prazo.day);
    return limite.isBefore(hoje);
  }

  /// O banco atual não tem CHECK para essas regras, então a validação mora
  /// aqui. Chame antes de inserir/atualizar (o service faz isso).
  /// Troque ArgumentError pela exceção própria do projeto, se preferir.
  void validar() {
    if (titulo.trim().isEmpty) {
      throw ArgumentError('O título da OS é obrigatório.');
    }
    if (!tiposValidos.contains(tipoManutencao)) {
      throw ArgumentError(
          'Tipo de manutenção inválido: "$tipoManutencao". Use $tiposValidos.');
    }
    if (!prioridadesValidas.contains(prioridade)) {
      throw ArgumentError(
          'Prioridade inválida: "$prioridade". Use $prioridadesValidas.');
    }

    final inicio = dataInicio;
    final fim = dataFim;
    if (inicio != null && fim != null && fim.isBefore(inicio)) {
      throw ArgumentError('A data de fim não pode ser anterior à de início.');
    }

    if (tipoManutencao == preventiva) {
      if (!recorrente ||
          (intervaloDias ?? 0) <= 0 ||
          (duracaoDias ?? 0) <= 0 ||
          proximaData == null) {
        throw ArgumentError(
            'Preventiva exige recorrência, intervalo, duração e próxima data.');
      }
      if (status == StatusOrdemServico.concluida) {
        throw ArgumentError('Preventiva não é concluída: ela se renova.');
      }
    } else if (recorrente ||
        intervaloDias != null ||
        duracaoDias != null ||
        proximaData != null) {
      throw ArgumentError('Corretiva não pode ter campos de recorrência.');
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'idORDEMSERVICO': id,
      'titulo_os': titulo,
      'observacao': observacao,
      'data_abertura': _fmtDateTime(dataAbertura),
      'data_inicio': _fmtDateTime(dataInicio),
      'data_fim': _fmtDateTime(dataFim),
      'prazo_previsto': _fmtDate(prazoPrevisto),
      'prioridade': prioridade,
      'status': status.toValue(),
      'tipo_manutencao': tipoManutencao,
      'recorrente': recorrente ? 1 : 0,
      'intervalo_dias': intervaloDias,
      'duracao_dias': duracaoDias,
      'proxima_data': _fmtDate(proximaData),
      'USUARIO_idSolicitante': usuarioSolicitanteId,
      'USUARIO_idExecutor': usuarioExecutorId,
      'SETOR_idSETOR': setorId,
      'LOCALIZACAO_idLOCALIZACAO': localizacaoId,
      'PATRIMONIO_idPATRIMONIO': patrimonioId,
    };
  }

  factory OrdemServico.fromMap(Map<String, dynamic> map) {
    return OrdemServico(
      id: _toInt(map['idORDEMSERVICO']),
      titulo: map['titulo_os'] as String,
      observacao: map['observacao'] as String?,
      dataAbertura: _toDateTime(map['data_abertura']),
      dataInicio: _toDateTime(map['data_inicio']),
      dataFim: _toDateTime(map['data_fim']),
      prazoPrevisto: _toDateTime(map['prazo_previsto']),
      prioridade: map['prioridade'] as String,
      status: StatusOrdemServico.fromValue(map['status'] as String),
      tipoManutencao: map['tipo_manutencao'] as String,
      recorrente: _toBool(map['recorrente']),
      intervaloDias: _toInt(map['intervalo_dias']),
      duracaoDias: _toInt(map['duracao_dias']),
      proximaData: _toDateTime(map['proxima_data']),
      usuarioSolicitanteId: _toInt(map['USUARIO_idSolicitante'])!,
      usuarioExecutorId: _toInt(map['USUARIO_idExecutor']),
      setorId: _toInt(map['SETOR_idSETOR'])!,
      localizacaoId: _toInt(map['LOCALIZACAO_idLOCALIZACAO'])!,
      patrimonioId: _toInt(map['PATRIMONIO_idPATRIMONIO']),
    );
  }

  /// Cópia com campos alterados — ex.: o executor assume a OS
  /// (copyWith(status: ..., usuarioExecutorId: ..., dataInicio: ...)).
  /// Limitação: não dá para "limpar" um campo opcional passando null.
  OrdemServico copyWith({
    String? titulo,
    String? observacao,
    DateTime? dataInicio,
    DateTime? dataFim,
    DateTime? prazoPrevisto,
    String? prioridade,
    StatusOrdemServico? status,
    bool? recorrente,
    int? intervaloDias,
    int? duracaoDias,
    DateTime? proximaData,
    int? usuarioExecutorId,
    int? patrimonioId,
  }) {
    return OrdemServico(
      id: id,
      titulo: titulo ?? this.titulo,
      observacao: observacao ?? this.observacao,
      dataAbertura: dataAbertura,
      dataInicio: dataInicio ?? this.dataInicio,
      dataFim: dataFim ?? this.dataFim,
      prazoPrevisto: prazoPrevisto ?? this.prazoPrevisto,
      prioridade: prioridade ?? this.prioridade,
      status: status ?? this.status,
      tipoManutencao: tipoManutencao,
      recorrente: recorrente ?? this.recorrente,
      intervaloDias: intervaloDias ?? this.intervaloDias,
      duracaoDias: duracaoDias ?? this.duracaoDias,
      proximaData: proximaData ?? this.proximaData,
      usuarioSolicitanteId: usuarioSolicitanteId,
      usuarioExecutorId: usuarioExecutorId ?? this.usuarioExecutorId,
      setorId: setorId,
      localizacaoId: localizacaoId,
      patrimonioId: patrimonioId ?? this.patrimonioId,
    );
  }

  @override
  String toString() =>
      'OrdemServico(id: $id, $tipoManutencao, "$titulo", '
      'status: ${status.toValue()})';
}

// ---------------------------------------------------------------------------
// Conversores tolerantes: o driver pode devolver DateTime/int/bool ou texto,
// dependendo do pacote MySQL usado. Assim o fromMap funciona nos dois casos.
// ---------------------------------------------------------------------------

DateTime? _toDateTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.parse(v);
  throw FormatException('Data inválida vinda do banco: $v');
}

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.parse(v);
  throw FormatException('Inteiro inválido vindo do banco: $v');
}

bool _toBool(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == '1' || v.toLowerCase() == 'true';
  return false;
}

/// Formato aceito pelo MySQL em colunas DATETIME.
String? _fmtDateTime(DateTime? d) {
  if (d == null) return null;
  String dois(int n) => n.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${dois(d.month)}-${dois(d.day)} '
      '${dois(d.hour)}:${dois(d.minute)}:${dois(d.second)}';
}

/// Formato aceito pelo MySQL em colunas DATE.
String? _fmtDate(DateTime? d) {
  if (d == null) return null;
  String dois(int n) => n.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${dois(d.month)}-${dois(d.day)}';
}