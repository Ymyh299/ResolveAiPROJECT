import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:projeto_resolveai/database/conexao.dart';

class ImportSpec {
  final String arquivo;
  final String tabela;
  final List<String> colunas;
  final Set<String> colunasInteiras;

  const ImportSpec({
    required this.arquivo,
    required this.tabela,
    required this.colunas,
    this.colunasInteiras = const {},
  });
}

const importacoes = <ImportSpec>[
  // A ordem respeita as chaves estrangeiras do schema.
  ImportSpec(
    arquivo: 'setor.csv',
    tabela: 'SETOR',
    colunas: ['idSETOR', 'nome', 'descricao'],
    colunasInteiras: {'idSETOR'},
  ),
  // O CSV já está ordenado com o registro pai antes dos filhos.
  ImportSpec(
    arquivo: 'localizacao.csv',
    tabela: 'LOCALIZACAO',
    colunas: ['idLOCALIZACAO', 'nome_localizacao', 'LOCALIZACAO_idPAI'],
    colunasInteiras: {'idLOCALIZACAO', 'LOCALIZACAO_idPAI'},
  ),
  ImportSpec(
    arquivo: 'material.csv',
    tabela: 'MATERIAL',
    colunas: [
      'idMATERIAL',
      'nome',
      'quantidade',
      'data_compra',
      'valor_material',
    ],
    colunasInteiras: {'idMATERIAL'},
  ),
  ImportSpec(
    arquivo: 'usuario.csv',
    tabela: 'USUARIO',
    colunas: [
      'idUSUARIO',
      'nome',
      'data_cadastro',
      'cpf',
      'telefone',
      'email',
      'senha',
      'tipo_usuario',
      'SETOR_idSETOR',
    ],
    colunasInteiras: {'idUSUARIO', 'SETOR_idSETOR'},
  ),
  ImportSpec(
    arquivo: 'patrimonio.csv',
    tabela: 'PATRIMONIO',
    colunas: [
      'idPATRIMONIO',
      'nome',
      'valor',
      'descricao',
      'estado_conservacao',
      'data_compra',
      'LOCALIZACAO_idLOCALIZACAO',
    ],
    colunasInteiras: {'idPATRIMONIO', 'LOCALIZACAO_idLOCALIZACAO'},
  ),
  ImportSpec(
    arquivo: 'ordemservico.csv',
    tabela: 'ORDEMSERVICO',
    colunas: [
      'idORDEMSERVICO',
      'titulo_os',
      'observacao',
      'data_abertura',
      'data_inicio',
      'data_fim',
      'prazo_previsto',
      'prioridade',
      'status',
      'tipo_manutencao',
      'recorrente',
      'intervalo_dias',
      'duracao_dias',
      'proxima_data',
      'USUARIO_idSolicitante',
      'USUARIO_idExecutor',
      'SETOR_idSETOR',
      'LOCALIZACAO_idLOCALIZACAO',
      'PATRIMONIO_idPATRIMONIO',
    ],
    colunasInteiras: {
      'idORDEMSERVICO',
      'recorrente',
      'intervalo_dias',
      'duracao_dias',
      'USUARIO_idSolicitante',
      'USUARIO_idExecutor',
      'SETOR_idSETOR',
      'LOCALIZACAO_idLOCALIZACAO',
      'PATRIMONIO_idPATRIMONIO',
    },
  ),
  ImportSpec(
    arquivo: 'ordemservico_has_material.csv',
    tabela: 'ORDEMSERVICO_has_MATERIAL',
    colunas: [
      'idITEM',
      'ORDEMSERVICO_idORDEMSERVICO',
      'MATERIAL_idMATERIAL',
      'quantidade_usada',
      'valor_unitario',
      'data_uso',
    ],
    colunasInteiras: {
      'idITEM',
      'ORDEMSERVICO_idORDEMSERVICO',
      'MATERIAL_idMATERIAL',
    },
  ),
];

Future<void> main() async {
  final pastaDados = Directory('dados_csv');
  if (!await pastaDados.exists()) {
    stderr.writeln(
      'Pasta ./dados_csv não encontrada. Crie-a na raiz do projeto.',
    );
    exitCode = 1;
    return;
  }

  stdout.writeln(
    'ATENÇÃO: todos os registros das tabelas de importação serão apagados '
    'antes da carga.',
  );
  stdout.write('Digite APAGAR para confirmar: ');
  final confirmacao = stdin.readLineSync()?.trim();
  if (confirmacao != 'APAGAR') {
    stdout.writeln('Importação cancelada. Nenhum dado foi alterado.');
    return;
  }

  MySQLConnection? conn;
  try {
    conn = await Conexao.get();

    await conn.execute('START TRANSACTION');
    var totalImportado = 0;

    try {
      await conn.execute('SET FOREIGN_KEY_CHECKS = 0');
      try {
        for (final spec in importacoes.reversed) {
          await conn.execute('DELETE FROM ${spec.tabela}');
        }
      } finally {
        await conn.execute('SET FOREIGN_KEY_CHECKS = 1');
      }

      for (final spec in importacoes) {
        final arquivo = File('${pastaDados.path}/${spec.arquivo}');
        if (!await arquivo.exists()) {
          throw FileSystemException('Arquivo não encontrado', arquivo.path);
        }

        // Os arquivos estão codificados em UTF-8 (acentos).
        final conteudo = utf8.decode(await arquivo.readAsBytes());
        final linhas = Csv(
          fieldDelimiter: ',',
          autoDetect: false,
        ).decode(conteudo);

        if (linhas.isEmpty) {
          throw FormatException('${spec.arquivo}: arquivo vazio.');
        }

        final cabecalho = linhas.first.map((v) => v.toString().trim()).toList();
        if (!_mesmaLista(cabecalho, spec.colunas)) {
          throw FormatException(
            '${spec.arquivo}: cabeçalho diferente do esperado.\n'
            'Esperado: ${spec.colunas.join(', ')}\n'
            'Recebido: ${cabecalho.join(', ')}',
          );
        }

        final placeholders = List.generate(
          spec.colunas.length,
          (i) => ':p$i',
        ).join(', ');
        final sql =
            'INSERT INTO ${spec.tabela} '
            '(${spec.colunas.join(', ')}) VALUES ($placeholders)';

        var importadosArquivo = 0;
        for (var indice = 1; indice < linhas.length; indice++) {
          final linha = linhas[indice];
          if (linha.every((campo) => campo.toString().trim().isEmpty)) continue;

          if (linha.length != spec.colunas.length) {
            throw FormatException(
              '${spec.arquivo}, linha ${indice + 1}: esperadas '
              '${spec.colunas.length} colunas, recebidas ${linha.length}.',
            );
          }

          final parametros = <String, dynamic>{};
          for (var coluna = 0; coluna < spec.colunas.length; coluna++) {
            final nomeColuna = spec.colunas[coluna];
            final valorOriginal = linha[coluna].toString().trim();
            final valor = _normalizarValor(valorOriginal);

            if (valor == null) {
              parametros['p$coluna'] = null;
            } else if (spec.colunasInteiras.contains(nomeColuna)) {
              final inteiro = int.tryParse(valor);
              if (inteiro == null) {
                throw FormatException(
                  '${spec.arquivo}, linha ${indice + 1}: '
                  'valor "$valor" inválido para $nomeColuna.',
                );
              }
              parametros['p$coluna'] = inteiro;
            } else {
              // Mantém DECIMAL e datas como texto para evitar perda de precisão.
              parametros['p$coluna'] = valor;
            }
          }

          await conn.execute(sql, parametros);
          importadosArquivo++;
        }

        totalImportado += importadosArquivo;
        stdout.writeln('✓ ${spec.arquivo}: $importadosArquivo registros');
      }

      await conn.execute('COMMIT');
      stdout.writeln(
        '\nImportação concluída: $totalImportado registros inseridos.',
      );
    } catch (_) {
      await conn.execute('ROLLBACK');
      rethrow;
    }
  } catch (erro) {
    stderr.writeln('\nFalha na importação: $erro');
    stderr.writeln('Nenhuma alteração da transação foi mantida.');
    exitCode = 1;
  } finally {
    // Sem fechar a conexão o programa não termina depois da importação.
    if (conn != null && conn.connected) await conn.close();
  }
}

String? _normalizarValor(String valor) {
  if (valor.isEmpty || valor == r'\N') return null;
  return valor;
}

bool _mesmaLista(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
