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
          'continuamos o serviço normalmente',
          agora: agora);
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
      expect(
          faseDe('passamos a fiação dos conduítes'), 'Instalações elétricas');
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
          DiarioVozService.interpretar('na sexta passada choveu', agora: agora)
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

    test('o ruído do reconhecedor é corrigido também no texto', () {
      final r = DiarioVozService.interpretar('passamos o chap isco na parede',
          agora: agora);
      expect(r.descricao, 'Passamos o chapisco na parede');
      expect(r.transcricao, 'passamos o chap isco na parede');
    });
  });

  group('Clima com negação', () {
    String? climaDe(String frase) =>
        DiarioVozService.interpretar(frase, agora: agora).clima;

    test('o que não aconteceu não conta', () {
      expect(climaDe('tempo fechado mas não choveu'), 'Nublado');
      expect(climaDe('não choveu, sol o dia todo'), 'Ensolarado');
      expect(climaDe('ameaçou chover mas não choveu'), 'Nublado');
      expect(climaDe('o sol não apareceu hoje'), isNull);
    });

    test('"sem chuva" sozinho não diz se teve sol: fica vazio', () {
      expect(climaDe('dia sem chuva, trabalhamos normal'), isNull);
    });

    test('termo mais longo vence o que está dentro dele', () {
      expect(climaDe('choveu forte a tarde toda'), 'Chuva forte');
      expect(climaDe('com cara de chuva o dia inteiro'), 'Nublado');
      expect(climaDe('dia nublado, sem sol'), 'Nublado');
    });

    test('dupla negação e previsão', () {
      expect(climaDe('não parou de chover'), 'Chuvoso');
      expect(climaDe('hoje sol, amanhã vai chover'), 'Ensolarado');
    });

    test('palavra comum não vira clima', () {
      expect(climaDe('deixamos o terreno limpo'), isNull);
      expect(climaDe('molhamos a laje pra cura'), isNull);
      expect(climaDe('fizemos a solda do portão'), isNull);
    });
  });

  group('Quem estava no canteiro', () {
    int? pessoasDe(String frase) =>
        DiarioVozService.interpretar(frase, agora: agora).numeroPessoas;

    test('profissão no singular, sem número, é uma pessoa', () {
      expect(
          pessoasDe('o carpinteiro e o ajudante dele montaram as formas'), 2);
      expect(pessoasDe('o encanador e 2 serventes'), 3);
      expect(pessoasDe('o eletricista veio passar a fiação'), 1);
    });

    test('quem fala conta quando se inclui na equipe', () {
      expect(pessoasDe('eu e o ajudante fizemos o contrapiso'), 2);
      expect(pessoasDe('eu e mais dois terminamos o muro'), 3);
      // "e eu" na narração não é equipe
      expect(pessoasDe('choveu e eu fui embora mais cedo'), isNull);
    });

    test('a mesma pessoa citada duas vezes conta uma', () {
      expect(
          pessoasDe('o pedreiro chegou cedo, o pedreiro terminou o reboco'), 1);
      expect(pessoasDe('3 pedreiros vieram, o pedreiro mais novo rebocou'), 3);
    });

    test('quem só passou para ver não é da equipe', () {
      expect(pessoasDe('o engenheiro passou para ver a laje'), isNull);
      expect(pessoasDe('3 pedreiros e o engenheiro passou para ver'), 3);
    });

    test('quem faltou ou só vem amanhã não conta', () {
      expect(pessoasDe('o servente faltou, o pedreiro veio'), 1);
      expect(pessoasDe('amanhã vem o eletricista'), isNull);
    });

    test('total anunciado vence a soma das profissões', () {
      expect(pessoasDe('equipe de 6: 2 pedreiros e 4 serventes'), 6);
    });

    test('plural sem número fica vazio em vez de chutar', () {
      expect(pessoasDe('os pedreiros terminaram o reboco'), isNull);
    });

    test('número que não é gente não conta', () {
      expect(pessoasDe('tinha 3 sacos de cimento'), isNull);
      expect(pessoasDe('trabalharam 8 horas'), isNull);
      expect(pessoasDe('com cara de chuva o dia inteiro'), isNull);
    });
  });

  group('Fase pela atividade', () {
    String? faseDe(String frase) =>
        DiarioVozService.interpretar(frase, agora: agora).fase;

    test('verbos conjugados', () {
      expect(faseDe('rebocamos a sala'), 'Reboco e contrapiso');
      expect(faseDe('pintaram a fachada'), 'Pintura');
      expect(faseDe('concretamos as sapatas'), 'Fundação');
      expect(faseDe('levantamos a parede da cozinha'), 'Alvenaria');
      expect(faseDe('erguemos o muro'), 'Alvenaria');
    });

    test('atividade pesa mais que o objeto onde ela foi feita', () {
      expect(faseDe('chapisco das paredes da cozinha'), 'Reboco e contrapiso');
      expect(faseDe('pintamos a parede do quarto'), 'Pintura');
    });

    test('verbo genérico vira atividade pelo objeto', () {
      expect(faseDe('assentamos o piso da cozinha'), 'Revestimentos');
      expect(faseDe('subimos o material pra laje e assentamos os blocos'),
          'Alvenaria');
      expect(faseDe('colocamos as portas e janelas'), 'Acabamento');
      expect(faseDe('instalamos as tomadas'), 'Instalações elétricas');
    });

    test('a atividade principal vence a menção secundária', () {
      expect(
          faseDe('fizemos o contrapiso da sala, e o eletricista passou uns '
              'fios'),
          'Reboco e contrapiso');
      expect(faseDe('hoje rebocamos a sala, amanhã vamos começar a pintura'),
          'Reboco e contrapiso');
    });

    test('falsos positivos', () {
      expect(faseDe('de forma geral foi um dia tranquilo'), isNull);
      expect(faseDe('pintou um problema com a betoneira'), isNull);
      expect(faseDe('não deu pra rebocar por causa da chuva'), isNull);
    });

    test('empate sem atividade dominante fica vazio', () {
      expect(faseDe('terminamos o reboco e começamos a pintura'), isNull);
    });

    test('ruído do reconhecedor não esconde a fase', () {
      expect(faseDe('passamos o chap isco na parede'), 'Reboco e contrapiso');
      expect(faseDe('fizemos o balde drame'), 'Fundação');
      expect(faseDe('concretamos o contra piso'), 'Reboco e contrapiso');
    });
  });

  group('Hipóteses do reconhecedor no diário', () {
    test('troca a 1ª cortada por uma alternativa que diz mais', () {
      final r = DiarioVozService.interpretarHipoteses([
        ('hoje choveu e trabalharam três pedreiros e', 0.7),
        ('hoje choveu e trabalharam três pedreiros e rebocamos a sala', 0.5),
      ], agora: agora);
      expect(r.fase, 'Reboco e contrapiso');
      expect(r.transcricao,
          'hoje choveu e trabalharam três pedreiros e rebocamos a sala');
    });

    test('alternativa parecida não tira a 1ª', () {
      final r = DiarioVozService.interpretarHipoteses([
        ('rebocamos a sala', 0.9),
        ('rebocamos a sala ontem', 0.3),
      ], agora: agora);
      expect(r.transcricao, 'rebocamos a sala');
    });
  });

  group('Clima dito com verbo no meio', () {
    String? climaDe(String frase) =>
        DiarioVozService.interpretar(frase, agora: agora).clima;

    test('"o tempo ficou fechado", "o céu ficou limpo"', () {
      expect(climaDe('hoje o tempo ficou fechado mas não choveu'), 'Nublado');
      expect(climaDe('o céu ficou limpo depois do almoço'), 'Ensolarado');
      expect(climaDe('o tempo estava bom mas esfriou'), 'Ensolarado');
      expect(climaDe('não teve sol, só nuvem'), 'Nublado');
    });

    test('expectativa e negação não viram clima', () {
      expect(climaDe('esperando o tempo ficar bom'), isNull);
      expect(climaDe('o tempo não ficou bom'), isNull);
      expect(climaDe('achei que ia chover'), isNull);
    });
  });

  group('Quem fala e quem trabalha junto', () {
    int? pessoasDe(String frase) =>
        DiarioVozService.interpretar(frase, agora: agora).numeroPessoas;

    test('o falante numa lista com vírgula', () {
      expect(pessoasDe('eu, o pedreiro e 2 ajudantes'), 4);
      expect(pessoasDe('o pedreiro, o ajudante e eu'), 3);
      // vírgula depois de "eu" sem equipe não é lista
      expect(pessoasDe('eu, a princípio, achei que ia chover'), isNull);
    });

    test('parente ao lado do falante conta', () {
      expect(pessoasDe('eu e meu filho trabalhamos'), 2);
      expect(pessoasDe('meu irmão e eu fizemos o muro'), 2);
      expect(pessoasDe('trabalhei com o ajudante'), 2);
      // longe do falante, parente não é equipe
      expect(pessoasDe('o filho do dono passou aqui'), isNull);
    });

    test('"éramos em 5" é o total', () {
      expect(pessoasDe('éramos em 5 na obra'), 5);
    });
  });
}
