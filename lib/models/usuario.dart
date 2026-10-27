import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart'; // dart pub add crypto

/// Perfil do usuário no sistema.
enum TipoUsuario {
  administrador(1, 'Administrador'),
  comum(2, 'Usuário comum');

  final int codigo;
  final String descricao;
  const TipoUsuario(this.codigo, this.descricao);

  static TipoUsuario fromCodigo(int c) =>
      TipoUsuario.values.firstWhere((t) => t.codigo == c);
}

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
  final TipoUsuario tipoUsuario;

  Usuario({
    this.id,
    required this.nome,
    DateTime? dataCadastro,
    required this.cpf,
    required this.telefone,
    required this.email,
    required this.senhaHash,
    required this.setorId,
    this.tipoUsuario = TipoUsuario.comum,
  }) : dataCadastro = dataCadastro ?? DateTime.now();

  bool get isAdmin => tipoUsuario == TipoUsuario.administrador;

  Usuario copyWith({
    int? id,
    String? nome,
    String? cpf,
    String? telefone,
    String? email,
    String? senhaHash,
    int? setorId,
    TipoUsuario? tipoUsuario,
  }) {
    return Usuario(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      dataCadastro: dataCadastro,
      cpf: cpf ?? this.cpf,
      telefone: telefone ?? this.telefone,
      email: email ?? this.email,
      senhaHash: senhaHash ?? this.senhaHash,
      setorId: setorId ?? this.setorId,
      tipoUsuario: tipoUsuario ?? this.tipoUsuario,
    );
  }

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
      'tipo_usuario': tipoUsuario.codigo,
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
      tipoUsuario: TipoUsuario.fromCodigo(map['tipo_usuario'] as int),
    );
  }

  @override
  String toString() => 'Usuario(id: $id, nome: $nome, setorId: $setorId)';

  // ---------------------------------------------------------------------------
  // HASH DE SENHA
  // ---------------------------------------------------------------------------

  /// Gera "salt:hash" (SHA-256 salgado com 10.000 iterações).
  /// Para produção, prefira bcrypt/argon2 (ex.: pacote `dbcrypt`).
  static String gerarHash(String senha, {String? salt}) {
    final s = salt ??
        base64UrlEncode(
            List<int>.generate(16, (_) => Random.secure().nextInt(256)));
    List<int> bytes = utf8.encode('$s$senha');
    for (var i = 0; i < 10000; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return '$s:${base64UrlEncode(bytes)}';
  }

  /// Usado no login: compara a senha digitada com o hash salvo.
  static bool verificarSenha(String senha, String hashSalvo) {
    final salt = hashSalvo.split(':').first;
    return gerarHash(senha, salt: salt) == hashSalvo;
  }
}