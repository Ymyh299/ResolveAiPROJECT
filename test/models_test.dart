import 'package:projeto_resolveai/models/localizacao.dart';
import 'package:projeto_resolveai/models/material.dart';
import 'package:projeto_resolveai/models/ordemdeservico.dart';
import 'package:projeto_resolveai/models/ordemdeservicomaterial.dart';
import 'package:projeto_resolveai/models/patrimonio.dart';
import 'package:projeto_resolveai/models/sessao.dart';
import 'package:projeto_resolveai/models/setor.dart';
import 'package:projeto_resolveai/models/usuario.dart';
import 'package:projeto_resolveai/utils/utils.dart';
import 'package:test/test.dart';

OrdemDeServico _os({
  String titulo = 'Trocar lâmpada',
  String prioridade = 'Alta',
  String status = OrdemDeServico.statusAberta,
  String tipo = OrdemDeServico.corretiva,
  bool recorrente = false,
  int? intervalo,
  int? duracao,
  DateTime? proxima,
  DateTime? inicio,
  DateTime? fim,
  DateTime? prazo,
}) =>
    OrdemDeServico(
      titulo: titulo,
      prioridade: prioridade,
      status: status,
      tipoManutencao: tipo,
      recorrente: recorrente,
      intervaloDias: intervalo,
      duracaoDias: duracao,
      proximaData: proxima,
      dataInicio: inicio,
      dataFim: fim,
      prazoPrevisto: prazo,
      solicitanteId: 1,
      setorId: 1,
      localizacaoId: 1,
    );

void main() {
  group('utils', () {
    test('lerData / lerDouble aceitam null e strings', () {
      expect(lerData(null), isNull);
      expect(lerData('2026-01-02'), DateTime(2026, 1, 2));
      expect(lerData('2026-01-02 10:20:30'), DateTime(2026, 1, 2, 10, 20, 30));
      expect(lerDouble(null), isNull);
      expect(lerDouble('12.50'), 12.5);
      expect(lerDouble(3), 3.0);
    });

    test('gravarData / gravarDataHora formatam para MySQL', () {
      final d = DateTime(2026, 3, 4, 5, 6, 7, 800);
      expect(gravarData(d), '2026-03-04');
      expect(gravarDataHora(d), '2026-03-04 05:06:07');
      expect(gravarData(null), isNull);
      expect(gravarDataHora(null), isNull);
    });
  });

  group('Usuario', () {
    test('hash de senha verifica a senha correta e rejeita a errada', () {
      final h = Usuario.gerarHash('segredo123');
      expect(h.contains(':'), isTrue);
      expect(Usuario.verificarSenha('segredo123', h), isTrue);
      expect(Usuario.verificarSenha('outra', h), isFalse);
    });

    test('salt aleatório gera hashes diferentes para a mesma senha', () {
      expect(Usuario.gerarHash('abc'), isNot(Usuario.gerarHash('abc')));
    });

    test('hash SHA2 puro do InsertExemplo.sql não é aceito pelo app', () {
      // SHA2('123456',256) — formato usado no script de exemplo
      const sha2 =
          '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92';
      expect(Usuario.verificarSenha('123456', sha2), isFalse);
    });

    test('toMap/fromMap ida e volta', () {
      final u = Usuario(
        id: 7,
        nome: 'Ana',
        dataCadastro: DateTime(2026, 1, 1, 8),
        cpf: '123',
        telefone: '',
        email: 'a@a.com',
        senhaHash: 'x:y',
        setorId: 2,
        tipoUsuario: TipoUsuario.administrador,
      );
      final m = u.toMap();
      expect(m['telefone'], isNull);
      expect(m['tipo_usuario'], 'administrador');
      final v = Usuario.fromMap(m);
      expect(v.id, 7);
      expect(v.isAdmin, isTrue);
      expect(v.telefone, '');
      expect(v.dataCadastro, DateTime(2026, 1, 1, 8));
    });

    test('TipoUsuario.fromCodigo/fromNome', () {
      expect(TipoUsuario.fromCodigo(1), TipoUsuario.administrador);
      expect(TipoUsuario.fromNome('comum'), TipoUsuario.comum);
      expect(() => TipoUsuario.fromNome('xx'), throwsStateError);
    });
  });

  group('Sessao', () {
    tearDown(Sessao.encerrar);
    test('iniciar/encerrar e isAdmin', () {
      expect(Sessao.estaLogado, isFalse);
      expect(Sessao.isAdmin, isFalse);
      Sessao.iniciar(Usuario(
          nome: 'x', cpf: '1', telefone: '', email: 'e', senhaHash: 'h', setorId: 1,
          tipoUsuario: TipoUsuario.administrador));
      expect(Sessao.estaLogado, isTrue);
      expect(Sessao.isAdmin, isTrue);
      Sessao.encerrar();
      expect(Sessao.estaLogado, isFalse);
    });
  });

  group('OrdemDeServico.validar', () {
    test('corretiva válida passa', () => expect(() => _os().validar(), returnsNormally));
    test('título vazio', () => expect(() => _os(titulo: '  ').validar(), throwsArgumentError));
    test('prioridade inválida', () => expect(() => _os(prioridade: 'X').validar(), throwsArgumentError));
    test('status inválido', () => expect(() => _os(status: 'X').validar(), throwsArgumentError));
    test('tipo inválido', () => expect(() => _os(tipo: 'X').validar(), throwsArgumentError));
    test('fim antes do início', () => expect(
        () => _os(inicio: DateTime(2026, 2, 2), fim: DateTime(2026, 2, 1)).validar(),
        throwsArgumentError));
    test('corretiva recorrente é rejeitada', () =>
        expect(() => _os(recorrente: true).validar(), throwsArgumentError));
    test('preventiva sem recorrência é rejeitada', () =>
        expect(() => _os(tipo: OrdemDeServico.preventiva).validar(), throwsArgumentError));
    test('preventiva completa passa', () => expect(
        () => _os(
                tipo: OrdemDeServico.preventiva,
                recorrente: true,
                intervalo: 30,
                duracao: 1,
                proxima: DateTime(2026, 12, 1))
            .validar(),
        returnsNormally));
  });

  group('OrdemDeServico.atrasada', () {
    final ontem = DateTime.now().subtract(const Duration(days: 1));
    final amanha = DateTime.now().add(const Duration(days: 1));
    test('prazo vencido e aberta = atrasada', () => expect(_os(prazo: ontem).atrasada, isTrue));
    test('prazo futuro = não atrasada', () => expect(_os(prazo: amanha).atrasada, isFalse));
    test('concluída nunca atrasada', () => expect(
        _os(prazo: ontem, status: OrdemDeServico.statusConcluida).atrasada, isFalse));
    test('cancelada nunca atrasada', () => expect(
        _os(prazo: ontem, status: OrdemDeServico.statusCancelada).atrasada, isFalse));
    test('sem prazo = não atrasada', () => expect(_os().atrasada, isFalse));
  });

  group('OrdemDeServico map', () {
    test('toMap/fromMap ida e volta', () {
      final os = _os(
        tipo: OrdemDeServico.preventiva,
        recorrente: true,
        intervalo: 15,
        duracao: 2,
        proxima: DateTime(2026, 12, 1),
        inicio: DateTime(2026, 11, 1, 9, 30),
      );
      final m = os.toMap();
      expect(m.containsKey('data_abertura'), isFalse);
      expect(m['recorrente'], 1);
      expect(m['data_inicio'], '2026-11-01 09:30:00');
      expect(m['proxima_data'], '2026-12-01');
      final v = OrdemDeServico.fromMap(m);
      expect(v.recorrente, isTrue);
      expect(v.intervaloDias, 15);
      expect(v.dataInicio, DateTime(2026, 11, 1, 9, 30));
    });

    test('copyWith limparDataFim', () {
      final os = _os(fim: DateTime(2026, 1, 1));
      expect(os.copyWith(limparDataFim: true).dataFim, isNull);
      expect(os.copyWith(titulo: 'n').dataFim, DateTime(2026, 1, 1));
    });
  });

  group('Material', () {
    test('fromMap tolera strings e valores ausentes', () {
      final m = Material.fromMap({
        'idMATERIAL': '3',
        'nome': 'Cabo',
        'quantidade': '10.50',
        'valor_material': '2.00',
        'data_compra': '2026-05-01',
      });
      expect(m.id, 3);
      expect(m.quantidade, 10.5);
      expect(m.dataCompra, DateTime(2026, 5, 1));
      final vazio = Material.fromMap({});
      expect(vazio.nome, '');
      expect(vazio.quantidade, 0);
    });

    test('toMap data_compra começa com a data (MySQL trunca a hora na coluna DATE)', () {
      final m = Material(
          nome: 'x', quantidade: 1, valorMaterial: 1, dataCompra: DateTime(2026, 5, 1));
      expect(m.toMap()['data_compra'], startsWith('2026-05-01'));
    });
  });

  group('Patrimonio / Setor / Localizacao', () {
    test('Patrimonio ida e volta', () {
      final p = Patrimonio(
          id: 1, nome: 'Bomba', localizacaoId: 2, valor: 99.9,
          estadoConservacao: 'Bom', dataCompra: DateTime(2025, 1, 2));
      final m = p.toMap()..['idPATRIMONIO'] = 1;
      final v = Patrimonio.fromMap(m);
      expect(v.nome, 'Bomba');
      expect(v.valor, 99.9);
      expect(v.dataCompra, DateTime(2025, 1, 2));
    });

    test('Setor ida e volta', () {
      final s = Setor.fromMap(Setor(id: 1, nome: 'TI').toMap());
      expect(s.nome, 'TI');
      expect(s.descricao, isNull);
    });

    test('Localizacao copyWith removerPai', () {
      final l = Localizacao(id: 1, nome: 'Sala', paiId: 5);
      expect(l.copyWith(removerPai: true).paiId, isNull);
      expect(l.copyWith(nome: 'B').paiId, 5);
      final m = l.toMap()..['idLOCALIZACAO'] = 1;
      expect(Localizacao.fromMap(m).paiId, 5);
    });
  });

  group('UsoMaterialDetalhe', () {
    test('subtotal', () {
      final u = UsoMaterialDetalhe.fromMap({
        'idITEM': 1,
        'ORDEMSERVICO_idORDEMSERVICO': 2,
        'MATERIAL_idMATERIAL': 3,
        'nome': 'Fita',
        'quantidade_usada': '2.5',
        'valor_unitario': '4.00',
        'data_uso': '2026-01-01 10:00:00',
      });
      expect(u.subtotal, 10.0);
    });
  });
}
