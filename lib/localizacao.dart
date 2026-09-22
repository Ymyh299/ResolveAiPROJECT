class Localizacao {
  final int? id;
  final String nome;

  Localizacao({this.id, required this.nome});

  Map<String, dynamic> toMap() {
    return {'id': id, 'nome': nome};
  }

  factory Localizacao.fromMap(Map<String, dynamic> map) {
    return Localizacao(id: map['id'] as int?, nome: map['nome'] as String);
  }

  @override
  String toString() => 'Localizacao(id: $id, nome: $nome)';
}
