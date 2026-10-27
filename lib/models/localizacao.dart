class Localizacao {
  final int? id;
  final String nome;

  /// Localização superior (null = localização raiz, ex.: "Área A").
  final int? paiId;

  Localizacao({this.id, required this.nome, this.paiId});

  Localizacao copyWith({int? id, String? nome, int? paiId, bool removerPai = false}) {
    return Localizacao(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      paiId: removerPai ? null : (paiId ?? this.paiId),
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'nome': nome, 'pai_id': paiId};
  }

  factory Localizacao.fromMap(Map<String, dynamic> map) {
    return Localizacao(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      paiId: map['pai_id'] as int?,
    );
  }

  @override
  String toString() => 'Localizacao(id: $id, nome: $nome, paiId: $paiId)';
}