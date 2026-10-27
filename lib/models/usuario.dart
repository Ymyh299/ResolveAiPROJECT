import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import '../utils/utils.dart';

enum TipoUsuario {
  administrador(1, 'Administrador'),
  comum(2, 'Usuário comum');

  final int codigo;
  final String descricao;
  const TipoUsuario(this.codigo, this.descricao);

  static TipoUsuario fromCodigo(int c) =>
      TipoUsuario.values.firstWhere((t) => t.codigo == c);

  static TipoUsuario fromNome(String n) =>
      TipoUsuario.values.firstWhere((t) => t.name == n);
}

class Usuario {
  final int? id;
  final String nome;
  final DateTime dataCadastro;
  final String cpf;
  final String telefone;
  final String email;
  final String senhaHash;
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
      'idUSUARIO': id,
      'nome': nome,
      'data_cadastro': gravarDataHora(dataCadastro),
      'cpf': cpf,
      'telefone': telefone.isEmpty ? null : telefone,
      'email': email,
      'senha': senhaHash,
      'tipo_usuario': tipoUsuario.name,
      'SETOR_idSETOR': setorId,
    };
  }

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['idUSUARIO'] as int?,
      nome: map['nome'] as String,
      dataCadastro: lerData(map['data_cadastro']),
      cpf: map['cpf'] as String,
      telefone: (map['telefone'] as String?) ?? '',
      email: map['email'] as String,
      senhaHash: map['senha'] as String,
      setorId: map['SETOR_idSETOR'] as int,
      tipoUsuario: TipoUsuario.fromNome(map['tipo_usuario'] as String),
    );
  }

  @override
  String toString() => 'Usuario(id: $id, nome: $nome, setorId: $setorId)';

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

  static bool verificarSenha(String senha, String hashSalvo) {
    final salt = hashSalvo.split(':').first;
    return gerarHash(senha, salt: salt) == hashSalvo;
  }
}