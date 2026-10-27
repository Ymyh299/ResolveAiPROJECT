class Setor {
  final int? id;
  final String nome;
  final String? descricao;

  Setor({this.id, required this.nome, this.descricao});

  Setor copyWith({int? id, String? nome, String? descricao}) {
    return Setor(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
    );
  }

  Map<String, dynamic> toMap() {
    return {'idSETOR': id, 'nome': nome, 'descricao': descricao};
  }

  factory Setor.fromMap(Map<String, dynamic> map) {
    return Setor(
      id: map['idSETOR'] as int?,
      nome: map['nome'] as String,
      descricao: map['descricao'] as String?,
    );
  }

  @override
  String toString() => 'Setor(id: $id, nome: $nome)';
}