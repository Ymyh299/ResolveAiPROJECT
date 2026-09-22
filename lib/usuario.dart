/// Representa um usuário do sistema (a pessoa que registra e/ou executa
/// Ordens de Serviço)
class Usuario {
  final int? id;
  final String nome;
  final DateTime dataCadastro;
  final String cpf;
  final String telefone;
  final String email;
  final String senhaHash; // NUNCA guardar a senha em texto puro
  final int setorId;
  Usuario({
    this.id,
    required this.nome,
    DateTime? dataCadastro,
    required this.cpf,
    required this.telefone,
    required this.email,
    required this.senhaHash,
    required this.setorId,
  }) : dataCadastro = dataCadastro ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'data_cadastro': dataCadastro.toIso8601String(),
      'cpf': cpf,
      'telefone': telefone,
      'email': email,
      'senha_hash': senhaHash,
      'setor_id': setorId,
    };
  }

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      dataCadastro: DateTime.parse(map['data_cadastro'] as String),
      cpf: map['cpf'] as String,
      telefone: map['telefone'] as String,
      email: map['email'] as String,
      senhaHash: map['senha_hash'] as String,
      setorId: map['setor_id'] as int,
    );
  }

  @override
  String toString() => 'Usuario(id: $id, nome: $nome, setorId: $setorId)';
}
