import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/models/models.dart';
import 'package:obra_facil/services/ia/assistente_ia_servidor.dart';
import 'package:obra_facil/services/ia/perguntas_obra_service.dart';
import 'package:obra_facil/services/ia/resumo_obra_ia.dart';

final _ref = DateTime(2026, 11, 9);

DadosObraChat _dados() {
  final obra = ObraModel(
    id: 'o1',
    nome: 'Casa Verde',
    endereco: 'Rua X',
    orcamento: 300000,
    dataInicio: DateTime(2026, 3, 2),
    previsaoTermino: DateTime(2026, 12, 15),
    donoId: 'dono',
    codigoConvite: 'ABC123',
    criadoEm: DateTime(2026, 3, 2),
  );
  LancamentoModel lanc(String id, DateTime data, double valor, CategoriaCusto cat,
          {String? fornecedor, StatusLancamento status = StatusLancamento.aprovado}) =>
      LancamentoModel(
        id: id,
        obraId: 'o1',
        descricao: 'Compra $id',
        valor: valor,
        categoria: cat,
        status: status,
        fornecedorNome: fornecedor,
        data: data,
        criadoPorId: 'u1',
        criadoPorNome: 'Mestre',
        criadoEm: data,
      );
  CronogramaFaseModel fase(String nome, int ordem, DateTime ini, DateTime fim, int pct) => CronogramaFaseModel(
      id: nome, obraId: 'o1', nome: nome, ordem: ordem, dataInicio: ini, dataFim: fim, percentualConcluido: pct);
  return DadosObraChat(
    obra: obra,
    lancamentos: [
      lanc('a', DateTime(2026, 11, 3), 12100, CategoriaCusto.material, fornecedor: 'Casa do Construtor'),
      lanc('b', DateTime(2026, 11, 5), 5800, CategoriaCusto.maoDeObra),
      lanc('c', DateTime(2026, 10, 2), 1000.5, CategoriaCusto.material, fornecedor: 'Depósito São José'),
      lanc('d', DateTime(2026, 11, 8), 4210, CategoriaCusto.material, status: StatusLancamento.pendente),
    ],
    diario: [
      DiarioEntradaModel(
        id: 'd1',
        obraId: 'o1',
        descricao: 'Reboco da sala',
        fase: 'Reboco e contrapiso',
        numeroPessoas: 6,
        clima: 'Ensolarado',
        registradoPorId: 'u1',
        registradoPorNome: 'Mestre',
        data: DateTime(2026, 11, 8),
        criadoEm: DateTime(2026, 11, 8),
      ),
    ],
    cronograma: [
      fase('Alvenaria', 2, DateTime(2026, 6, 1), DateTime(2026, 8, 31), 100),
      fase('Cobertura', 3, DateTime(2026, 9, 1), DateTime(2026, 10, 31), 80),
      fase('Pintura', 4, DateTime(2026, 12, 1), DateTime(2026, 12, 14), 0),
    ],
    estoque: [
      EstoqueItemModel(
          id: 'e1', obraId: 'o1', material: 'Cimento', quantidade: 4, unidade: 'sc',
          quantidadeMinima: 10, atualizadoEm: DateTime(2026, 11, 8)),
    ],
    movimentos: const [],
  );
}

void main() {
  group('resumo da obra para a IA', () {
    test('dono recebe os números iguais aos do app', () {
      final r = resumoObraParaIa(_dados(), modoCliente: false, agora: _ref);
      expect(r['avanco_obra_pct'], 60);
      expect((r['fase_atual'] as Map)['nome'], 'Cobertura');
      expect((r['fases'] as List)[1]['situacao'], 'atrasada');
      expect((r['fases'] as List)[2]['situacao'], 'a começar');
      expect(r['gastos_aprovados_total'], r'R$ 18.900,50');
      expect(r['gastos_aprovados_mes'], r'R$ 17.900,00');
      expect(r['pendentes_de_aprovacao'], {'quantidade': 1, 'total': r'R$ 4.210,00'});
      expect((r['maiores_fornecedores'] as List).first['nome'], 'Casa do Construtor');
      expect((r['estoque'] as List).first['abaixo_do_minimo'], isTrue);
    });

    test('cliente não recebe nada de dinheiro', () {
      final r = resumoObraParaIa(_dados(), modoCliente: true, agora: _ref);
      final texto = jsonEncode(r);
      expect(texto.contains(r'R$'), isFalse);
      expect(texto.contains('12100'), isFalse);
      expect(texto.contains('Casa do Construtor'), isFalse);
      for (final chave in ['orcamento', 'gastos_aprovados_total', 'pendentes_de_aprovacao', 'ultimos_gastos']) {
        expect(r.containsKey(chave), isFalse, reason: chave);
      }
      expect(r['avanco_obra_pct'], 60);
      expect((r['diario_ultimos'] as List).first['pessoas'], 6);
    });
  });

  group('cliente HTTP da IA do servidor', () {
    late HttpServer servidor;
    late List<Map<String, Object?>> recebidos;
    var status = 200;

    setUp(() async {
      recebidos = [];
      status = 200;
      servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      servidor.listen((req) async {
        final corpo = jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, Object?>;
        recebidos.add({...corpo, 'auth': req.headers.value('authorization'), 'caminho': req.uri.path});
        req.response.statusCode = status;
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode({'texto': 'Faltam 4 sacos de cimento.', 'resposta_id': 'r1'}));
        await req.response.close();
      });
    });

    tearDown(() => servidor.close(force: true));

    AssistenteIaServidor ia({String? token = 'tk'}) => AssistenteIaServidor(
        url: 'http://127.0.0.1:${servidor.port}/', token: () async => token);

    test('manda pergunta, perfil, resumo e o token do login', () async {
      final r = await ia().perguntar(pergunta: 'oq ta acabando?', perfil: 'dono', obra: {'nome': 'Casa Verde'});
      expect(r?.texto, 'Faltam 4 sacos de cimento.');
      expect(r?.respostaId, 'r1');
      expect(recebidos.single['auth'], 'Bearer tk');
      expect(recebidos.single['caminho'], '/api/obra/pergunta');
      expect(recebidos.single['perfil'], 'dono');
      expect((recebidos.single['obra'] as Map)['nome'], 'Casa Verde');
    });

    test('sem login, erro do servidor ou sem endereço: devolve null e o chat segue com as regras', () async {
      expect(await ia(token: null).perguntar(pergunta: 'x', perfil: 'dono', obra: {}), isNull);
      status = 503;
      expect(await ia().perguntar(pergunta: 'x', perfil: 'dono', obra: {}), isNull);
      final desligada = AssistenteIaServidor(url: '', token: () async => 'tk');
      expect(desligada.ligado, isFalse);
      expect(await desligada.perguntar(pergunta: 'x', perfil: 'dono', obra: {}), isNull);
    });

    test('servidor fora do ar: devolve null rápido', () async {
      final fora = AssistenteIaServidor(url: 'http://127.0.0.1:1', token: () async => 'tk');
      expect(await fora.perguntar(pergunta: 'x', perfil: 'dono', obra: {}), isNull);
    });
  });
}
