/// Essa é a classe mais "básica" do sistema: nenhuma outra classe é
/// necessária pra criar um Setor, por isso começamos por ela.
class Setor {
  final int? id; // pode ser nulo antes de salvar no banco (o banco gera o id)
  final String nome;
  final String? descricao;
  final int?
  prioridade; // ex: 1 (alta) a 5 (baixa) — ajuste a escala com seu grupo
  final String?
  duracao; // duração padrão de atendimento do setor (ex: "2h", "30min")

  Setor({
    this.id,
    required this.nome,
    this.descricao,
    this.prioridade,
    this.duracao,
  });

  /// Converte a classe em um Map, formato usado para salvar no banco de dados
  /// ou transformar em JSON pra enviar pelo front end.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'descricao': descricao,
      'prioridade': prioridade,
      'duracao': duracao,
    };
  }

  /// Cria um Setor a partir de um Map (ex: vindo do banco de dados ou da API).
  factory Setor.fromMap(Map<String, dynamic> map) {
    return Setor(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      descricao: map['descricao'] as String?,
      prioridade: map['prioridade'] as int?,
      duracao: map['duracao'] as String?,
    );
  }

  @override
  String toString() => 'Setor(id: $id, nome: $nome)';
}
