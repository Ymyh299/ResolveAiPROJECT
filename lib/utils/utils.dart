import 'dart:io';

DateTime? lerData(dynamic v) => v == null ? null : DateTime.parse(v.toString());

double? lerDouble(dynamic v) => v == null ? null : double.parse(v.toString());

String? gravarData(DateTime? d) => d?.toIso8601String().substring(0, 10);

String? gravarDataHora(DateTime? d) =>
    d?.toIso8601String().substring(0, 19).replaceFirst('T', ' ');

void limparTela() {
  if (stdout.hasTerminal) {
    stdout.write('\x1B[2J\x1B[3J\x1B[H');
  } else {
    print('\n' * 50);
  }
}

void pausar([String msg = 'Pressione ENTER para continuar...']) {
  stdout.write('\n$msg');
  stdin.readLineSync();
}