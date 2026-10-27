class Localizacao {
  final int? id;
  final String nome;
  final int? paiId;

  Localizacao({
    this.id,
    required this.nome,
    this.paiId,
  });

  Localizacao copyWith({
    int? id,
    String? nome,
    int? paiId,
    bool removerPai = false,
  }) {
    return Localizacao(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      paiId: removerPai ? null : (paiId ?? this.paiId),
    );
  }

  // Mapeia os atributos para as colunas reais do banco.
  Map<String, dynamic> toMap() {
    return {
      'nome_localizacao': nome,
      'LOCALIZACAO_idPAI': paiId,
    };
  }

  factory Localizacao.fromMap(Map<String, dynamic> map) {
    return Localizacao(
      id: map['idLOCALIZACAO'] as int?,
      nome: map['nome_localizacao'] as String,
      paiId: map['LOCALIZACAO_idPAI'] as int?,
    );
  }

  @override
  String toString() => 'Localizacao(id: $id, nome: $nome, paiId: $paiId)';
}