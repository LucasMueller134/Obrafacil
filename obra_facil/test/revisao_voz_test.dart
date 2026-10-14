import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/models/lancamento_model.dart';
import 'package:obra_facil/services/ia/diario_voz_service.dart';
import 'package:obra_facil/services/ia/numero_extenso.dart';
import 'package:obra_facil/services/ia/vocabulario_obra.dart';
import 'package:obra_facil/services/ia/voz_service.dart';

/// Casos achados pela revisão adversarial da IA de voz: cada um falhava
/// antes da correção e trava a regressão daquela classe de erro.
void main() {
  final agora = DateTime(2026, 10, 14, 10);
  LancamentoPorVoz l(String f) => VozService.interpretar(f, agora: agora);
  DiarioPorVoz d(String f) => DiarioVozService.interpretar(f, agora: agora);

  group('Revisão: o normalizador não troca plural comum por termo de obra', () {
    test('cerâmicos fica cerâmicos', () {
      expect(VocabularioObra.corrigir('500 tijolos cerâmicos'),
          '500 tijolos cerâmicos');
    });
    test('tijolo cerâmico vai ao estoque como Tijolo', () {
      expect(l('comprei 500 tijolos cerâmicos por 450').itens.single.material,
          'Tijolo');
    });
    test('bloco cerâmico vai ao estoque como bloco', () {
      expect(l('comprei 500 blocos cerâmicos 600 reais').itens.single.material,
          isNot('Piso cerâmico'));
    });
    test('pedreiras não vira pedreiros (categoria)', () {
      expect(l('comprei brita nas pedreiras 500 reais').categoria,
          CategoriaCusto.material);
    });
    test('diário: assentar blocos cerâmicos é alvenaria', () {
      expect(d('hoje assentamos os blocos cerâmicos da parede da cozinha').fase,
          'Alvenaria');
    });
    test('diário: fundição não vira fundação', () {
      final r =
          d('o serralheiro trouxe as grades da fundição e instalou no portão');
      expect(r.fase, isNot('Fundação'));
      expect(r.descricao, contains('fundição'));
    });
    test('materiais hidráulicos', () {
      expect(VocabularioObra.corrigir('os materiais hidráulicos'),
          'os materiais hidráulicos');
    });
  });

  group('Revisão: "o cento" e "por cento" não viram 100', () {
    test('a 80 o cento', () {
      expect(l('comprei 500 tijolos a 80 o cento').valor, 400);
    });
    test('300 telhas a 150 o cento', () {
      expect(l('comprei 300 telhas a 150 o cento').valor, 450);
    });
    test('por cento', () {
      expect(NumeroExtenso.normalizar('30 por cento'), '30 por cento');
      expect(l('paguei 30 por cento de entrada 3 mil reais').valor, 3000);
    });
  });

  group('Revisão: "35 e 50" é R\$ 35,50, não uma soma', () {
    test('a 35 e 50 cada', () {
      expect(l('comprei 10 sacos de cimento a 35 e 50 cada').valor, 355);
    });
    test('deu 89 e 90', () {
      expect(l('deu 89 e 90 a tinta').valor, 89.9);
    });
  });

  group('Revisão: número que identifica obra, casa ou produto não é dinheiro',
      () {
    test('obra 2 soma 2 reais', () {
      expect(l('comprei 500 reais de tijolo pra obra 2').valor, 500);
    });
    test('casa 3 soma 3 reais', () {
      expect(l('paguei o pedreiro da casa 3 250 reais').valor, 250);
    });
    test('pra casa 2 sem valor', () {
      expect(l('levei 3 sacos de cimento pra casa 2').valor, isNull);
    });
    test('o motorista fez 2 (viagens) troca o valor', () {
      expect(l('paguei 300 de frete o motorista fez 2').valor, 300);
    });
  });

  group('Revisão: "a 60 o metro" multiplica pela metragem em m² ou m³', () {
    test('porcelanato a 60 o metro', () {
      expect(l('comprei 25 metros quadrados de porcelanato a 60 o metro').valor,
          1500);
    });
    test('areia a 120 o metro', () {
      expect(l('comprei 2 metros cúbicos de areia a 120 o metro').valor, 240);
    });
  });

  group('Revisão: o tamanho da embalagem não vira a quantidade do estoque', () {
    test('cimento 50 quilos 10 sacos', () {
      final i = l('comprei cimento 50 quilos 10 sacos por 350').itens.single;
      expect('${i.quantidade} ${i.unidade}', '10.0 sc');
    });
    test('cal 20 quilos 10 sacos', () {
      final i = l('comprei cal 20 quilos 10 sacos 120 reais').itens.single;
      expect('${i.quantidade} ${i.unidade}', '10.0 sc');
    });
  });

  group('Revisão: no diário, "mais N lajes/pontos/fiadas" não é gente', () {
    test('mais 2 lajes', () {
      expect(d('hoje concretamos mais 2 lajes, 3 pedreiros').numeroPessoas, 3);
    });
    test('mais 6 pontos de luz', () {
      expect(d('o eletricista passou mais 6 pontos de luz').numeroPessoas, 1);
    });
    test('mais 3 fiadas', () {
      expect(
          d('o pedreiro e o servente subiram mais 3 fiadas de bloco')
              .numeroPessoas,
          2);
    });
  });
}
