import 'usuario.dart';

/// Guarda o usuário que está logado no sistema no momento.
/// Como tudo é `static`, existe uma única sessão para o programa inteiro.
class Sessao {
  Sessao._(); // impede instanciar a classe

  /// Usuário logado (null = ninguém logado).
  static Usuario? usuarioLogado;

  static bool get estaLogado => usuarioLogado != null;

  /// true somente se há alguém logado e esse alguém é administrador.
  static bool get isAdmin => usuarioLogado?.isAdmin ?? false;

  /// Chamar após validar a senha no login.
  static void iniciar(Usuario usuario) => usuarioLogado = usuario;

  /// Chamar ao deslogar ou antes de encerrar o sistema.
  static void encerrar() => usuarioLogado = null;
}