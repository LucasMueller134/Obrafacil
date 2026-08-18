import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/services/ia/diario_voz_service.dart';

void main() {
  final agora = DateTime(2026, 7, 6); // segunda-feira

  group('Diário por voz — relato completo', () {
    test('separa clima, equipe, fase e texto de uma fala corrida', () {
      final r = DiarioVozService.interpretar(
          'hoje choveu de manhã, trabalharam três pedreiros e dois '
          'serventes, terminamos o reboco da fachada',
          agora: agora);

      expect(r.clima, 'Chuvoso');
      expect(r.numeroPessoas, 5);
      expect(r.fase, 'Reboco e contrapiso');
      expect(r.data, DateTime(2026, 7, 6));
      expect(r.descricao.toLowerCase(), contains('reboco'));
      expect(r.temAlgo, isTrue);
    });

    test('relato sem clima nem equipe não inventa valores', () {
      final r = DiarioVozService.interpretar(
          'continuamos o serviço normalmente', agora: agora);
      expect(r.clima, isNull);
      expect(r.numeroPessoas, isNull);
      expect(r.fase, isNull);
      expect(r.temAlgo, isFalse);
      expect(r.descricao, 'Continuamos o serviço normalmente');
    });
  });

  group('Clima', () {
    String? climaDe(String frase) =>
        DiarioVozService.interpretar(frase, agora: agora).clima;

    test('chuva forte vence chuva', () {
      expect(climaDe('caiu um temporal na hora do almoço'), 'Chuva forte');
      expect(climaDe('choveu muito a tarde toda'), 'Chuva forte');
      expect(climaDe('deu uma garoa de manhã'), 'Chuvoso');
    });

    test('nublado e ensolarado', () {
      expect(climaDe('dia nublado, sem sol'), 'Nublado');
      expect(climaDe('sol forte o dia inteiro'), 'Ensolarado');
      expect(climaDe('tempo bom, produzimos bastante'), 'Ensolarado');
    });
  });

  group('Equipe no canteiro', () {
    int? pessoasDe(String frase) =>
        DiarioVozService.interpretar(frase, agora: agora).numeroPessoas;

    test('soma as profissões citadas', () {
      expect(pessoasDe('vieram 2 pedreiros, 1 servente e 1 eletricista'), 4);
    });

    test('não conta duas vezes o mesmo grupo', () {
      expect(pessoasDe('trabalharam 3 pedreiros hoje'), 3);
      expect(pessoasDe('equipe de 6 pessoas no canteiro'), 6);
    });

    test('trabalhei sozinho conta uma pessoa', () {
      expect(pessoasDe('fiquei sozinho hoje, terminei a limpeza'), 1);
    });

    test('sem menção à equipe fica null', () {
      expect(pessoasDe('dia parado por causa da chuva'), isNull);
    });
  });

  group('Fase deduzida do relato', () {
    String? faseDe(String frase) =>
        DiarioVozService.interpretar(frase, agora: agora).fase;

    test('atividades típicas de cada etapa', () {
      expect(faseDe('concretamos a laje do primeiro andar'), 'Estrutura');
      expect(faseDe('assentamos os tijolos da parede dos fundos'), 'Alvenaria');
      expect(faseDe('subimos o telhado da área de serviço'), 'Cobertura');
      expect(faseDe('passamos a fiação dos conduítes'),
          'Instalações elétricas');
      expect(faseDe('pintamos a primeira demão da sala'), 'Pintura');
      expect(faseDe('começamos a escavação das sapatas'), 'Fundação');
    });

    test('relato genérico não força uma fase', () {
      expect(faseDe('dia de organização do canteiro'), isNull);
    });
  });

  group('Dia do registro', () {
    test('data falada volta no passado', () {
      expect(
          DiarioVozService.interpretar('ontem trabalhamos até tarde',
                  agora: agora)
              .data,
          DateTime(2026, 7, 5));
      expect(
          DiarioVozService.interpretar('na sexta passada choveu',
                  agora: agora)
              .data,
          DateTime(2026, 7, 3));
    });
  });

  group('Descrição', () {
    test('a abertura de comando sai do texto', () {
      final r = DiarioVozService.interpretar(
          'anota aí no diário que a equipe terminou o contrapiso',
          agora: agora);
      expect(r.descricao, 'A equipe terminou o contrapiso');
      expect(r.fase, 'Reboco e contrapiso');
    });
  });
}
