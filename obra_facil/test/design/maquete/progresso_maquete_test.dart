import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/constants/app_constants.dart';
import 'package:obra_facil/design/maquete/progresso_maquete.dart';
import 'package:obra_facil/models/cronograma_fase_model.dart';

CronogramaFaseModel _fase(String nome, int pct, {int ordem = 0}) =>
    CronogramaFaseModel(
      id: '$nome-$ordem',
      obraId: 'obra',
      nome: nome,
      ordem: ordem,
      dataInicio: DateTime(2026, 1, 1),
      dataFim: DateTime(2026, 12, 31),
      percentualConcluido: pct,
    );

/// O cronograma padrão com os percentuais dados, na ordem de fasesPadrao.
List<CronogramaFaseModel> _padrao(List<int> pcts) => [
      for (var i = 0; i < pcts.length; i++)
        _fase(AppConstants.fasesPadrao[i], pcts[i], ordem: i),
    ];

void main() {
  group('ProgressoMaquete.doCronograma', () {
    test('sem cronograma (null ou vazio) dá o vazio: tudo em desenho', () {
      for (final p in [
        ProgressoMaquete.doCronograma(null),
        ProgressoMaquete.doCronograma(const []),
      ]) {
        expect(p, ProgressoMaquete.vazio);
        expect(p.semCronograma, isTrue);
        expect(p.avancoPorFase, List.filled(10, 0.0));
        expect(p.estadoReserva, 0);
        expect(p.percentualObra, 0);
        expect(p.faseAtual, 0);
      }
    });

    test('cada fase padrão cai no seu índice, de 0 a 1', () {
      final p = ProgressoMaquete.doCronograma(
        _padrao([100, 100, 40, 0, 0, 0, 0, 0, 0, 0]),
      );
      expect(p.avancoPorFase, [1.0, 1.0, 0.4, 0, 0, 0, 0, 0, 0, 0]);
      expect(p.semCronograma, isFalse);
      expect(p.estadoReserva, 2);
      expect(p.faseAtual, 2);
      expect(p.fasesEmAndamento, [2]);
    });

    test('casa nomes sem acento, sem caixa e com espaços sobrando', () {
      final p = ProgressoMaquete.doCronograma([
        _fase('FUNDACAO', 100),
        _fase('  instalacoes   ELETRICAS ', 50),
        _fase('Instalações Hidráulicas', 25),
        _fase('reboco e CONTRAPISO', 10),
      ]);
      expect(p.avancoPorFase[0], 1);
      expect(p.avancoPorFase[4], 0.5);
      expect(p.avancoPorFase[5], 0.25);
      expect(p.avancoPorFase[6], closeTo(0.1, 1e-9));
    });

    test('índice de cada nome de AppConstants.fasesPadrao', () {
      for (var i = 0; i < AppConstants.fasesPadrao.length; i++) {
        expect(ProgressoMaquete.indiceDaFase(AppConstants.fasesPadrao[i]), i);
        expect(ProgressoMaquete.nomeDaFase(i), AppConstants.fasesPadrao[i]);
      }
      expect(ProgressoMaquete.indiceDaFase(''), isNull);
      expect(ProgressoMaquete.indiceDaFase('Muro de divisa'), isNull);
    });

    test('fase desconhecida não tem peça, mas conta no avanço da obra', () {
      final p = ProgressoMaquete.doCronograma([
        _fase('Fundação', 100),
        _fase('Muro de divisa', 0),
      ]);
      expect(p.avancoPorFase, [1.0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
      // Mesma conta das outras telas: média de todas as fases do cronograma.
      expect(p.percentualObra, 50);
      expect(p.estadoReserva, 1);
    });

    test('só fases desconhecidas: tudo em desenho, mas com cronograma', () {
      final p = ProgressoMaquete.doCronograma([_fase('Muro de divisa', 80)]);
      expect(p.avancoPorFase, List.filled(10, 0.0));
      expect(p.semCronograma, isFalse);
      expect(p.percentualObra, 80);
    });

    test('fase padrão repetida: vale a média', () {
      final p = ProgressoMaquete.doCronograma([
        _fase('Alvenaria', 100),
        _fase('alvenaria', 50, ordem: 1),
      ]);
      expect(p.avancoPorFase[2], 0.75);
    });

    test('percentual fora de 0..100 é limitado', () {
      final p = ProgressoMaquete.doCronograma([
        _fase('Fundação', 130),
        _fase('Estrutura', -20),
      ]);
      expect(p.avancoPorFase[0], 1);
      expect(p.avancoPorFase[1], 0);
    });

    test('estado da reserva só conta fases concluídas seguidas', () {
      // Alvenaria pronta, mas a estrutura não: a imagem é a estado_01.
      final p = ProgressoMaquete.doCronograma(
        _padrao([100, 60, 100, 0, 0, 0, 0, 0, 0, 0]),
      );
      expect(p.estadoReserva, 1);
      expect(p.faseAtual, 1);
      expect(p.fasesEmAndamento, [1]);
    });

    test('obra pronta: estado 10, sem fase atual', () {
      final p = ProgressoMaquete.doCronograma(_padrao(List.filled(10, 100)));
      expect(p.estadoReserva, 10);
      expect(p.concluida, isTrue);
      expect(p.faseAtual, isNull);
      expect(p.percentualObra, 100);
    });

    test('sem fase em andamento, a atual é a primeira que falta', () {
      final p = ProgressoMaquete.doCronograma(
        _padrao([100, 100, 100, 0, 0, 0, 0, 0, 0, 0]),
      );
      expect(p.fasesEmAndamento, isEmpty);
      expect(p.faseAtual, 3);
    });
  });

  group('ProgressoMaquete.estado e .fases', () {
    test('estado(n) = n fases prontas, o quadro da estado_n', () {
      for (var n = 0; n <= 10; n++) {
        final p = ProgressoMaquete.estado(n);
        expect(p.estadoReserva, n);
        expect(p.percentualObra, n * 10);
      }
      expect(ProgressoMaquete.estado(-3).estadoReserva, 0);
      expect(ProgressoMaquete.estado(42).estadoReserva, 10);
    });

    test('fases() completa com zero, corta o excesso e limita valores', () {
      final p = ProgressoMaquete.fases([1.5, double.nan, 0.5]);
      expect(p.avancoPorFase, [1.0, 0, 0.5, 0, 0, 0, 0, 0, 0, 0]);
      expect(ProgressoMaquete.fases(List.filled(14, 1.0)).avancoPorFase,
          hasLength(10));
      expect(() => p.avancoPorFase[0] = 0, throwsUnsupportedError);
    });

    test('igualdade por valor', () {
      expect(ProgressoMaquete.estado(3), ProgressoMaquete.estado(3));
      expect(ProgressoMaquete.estado(3).hashCode,
          ProgressoMaquete.estado(3).hashCode);
      expect(ProgressoMaquete.estado(3), isNot(ProgressoMaquete.estado(4)));
    });
  });

  group('descrição para o leitor de tela', () {
    test('fase em andamento e o avanço da obra', () {
      final p = ProgressoMaquete.fases(
        [1, 1, 0.5, 0, 0, 0, 0, 0, 0, 0],
        percentualObra: 38,
      );
      expect(
          p.descricao, 'Maquete da obra: Alvenaria em andamento, 38% da obra');
    });

    test('duas fases em andamento', () {
      final p = ProgressoMaquete.fases(
        [1, 1, 1, 1, 0.5, 0.2, 0, 0, 0, 0],
        percentualObra: 47,
      );
      expect(
        p.descricao,
        'Maquete da obra: Instalações elétricas e Instalações hidráulicas '
        'em andamento, 47% da obra',
      );
    });

    test('nenhuma em andamento, obra pronta e sem cronograma', () {
      expect(
        ProgressoMaquete.estado(3).descricao,
        'Maquete da obra: próxima fase Cobertura, 30% da obra',
      );
      expect(
        ProgressoMaquete.estado(10).descricao,
        'Maquete da obra: todas as fases concluídas, 100% da obra',
      );
      expect(
        ProgressoMaquete.vazio.descricao,
        'Maquete da obra: sem cronograma, a casa toda em desenho',
      );
    });
  });
}
