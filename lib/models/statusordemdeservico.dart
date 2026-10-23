enum StatusOrdemServico {
  aberta,
  emAndamento,
  concluida,
  cancelada;

  /// Converte para texto.
  String toValue() {
    switch (this) {
      case StatusOrdemServico.aberta:
        return 'aberta';
      case StatusOrdemServico.emAndamento:
        return 'em_andamento';
      case StatusOrdemServico.concluida:
        return 'concluida';
      case StatusOrdemServico.cancelada:
        return 'cancelada';
    }
  }

  /// Faz o caminho inverso: transforma o texto do banco de volta em enum.
  static StatusOrdemServico fromValue(String value) {
    switch (value) {
      case 'aberta':
        return StatusOrdemServico.aberta;
      case 'em_andamento':
        return StatusOrdemServico.emAndamento;
      case 'concluida':
        return StatusOrdemServico.concluida;
      case 'cancelada':
        return StatusOrdemServico.cancelada;
      default:
        throw ArgumentError('Status desconhecido: $value');
    }
  }
}
