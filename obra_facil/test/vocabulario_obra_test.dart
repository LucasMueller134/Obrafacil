import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/services/ia/vocabulario_obra.dart';

void main() {
  String c(String s) => VocabularioObra.corrigir(s);

  group('Vocabulário de obra — palavra partida pelo reconhecedor', () {
    test('junta as partes que formam exatamente um termo de obra', () {
      expect(c('comprei 10 barras de verga lhão'),
          'comprei 10 barras de vergalhão');
      expect(
          c('fizemos o contra piso da sala'), 'fizemos o contrapiso da sala');
      expect(c('passamos o chap isco'), 'passamos o chapisco');
      expect(c('passamos os eletro dutos'), 'passamos os eletrodutos');
      expect(c('concretamos o bal drame'), 'concretamos o baldrame');
    });

    test('junção com palavra que existe sozinha vem da lista explícita', () {
      expect(c('armamos o balde drame'), 'armamos o baldrame');
      expect(c('caixa dágua de mil litros'), "caixa d'água de mil litros");
    });

    test('palavra de ligação nunca entra numa junção', () {
      expect(c('troquei a telha do galpão'), 'troquei a telha do galpão');
      expect(c('o balde da obra'), 'o balde da obra');
      expect(c('encostou contra a parede'), 'encostou contra a parede');
    });
  });

  group('Vocabulário de obra — homófonos', () {
    test('troca o que soa igual', () {
      expect(c('comprei 10 sacos de semento'), 'comprei 10 sacos de cimento');
      expect(c('paguei na cesta feira'), 'paguei na sexta-feira');
      expect(c('paguei sem reais de frete'), 'paguei cem reais de frete');
      expect(c('sento e vinte reais'), 'cento e vinte reais');
    });

    test('a palavra comum sozinha continua a mesma', () {
      expect(c('comprei uma cesta básica'), 'comprei uma cesta básica');
      expect(c('fiquei sem cimento'), 'fiquei sem cimento');
      expect(c('eu sento ali'), 'eu sento ali');
    });
  });

  group('Vocabulário de obra — correção aproximada', () {
    test('palavra longa a uma letra de um termo de obra', () {
      expect(c('armamos o baudrame'), 'armamos o baldrame');
      expect(c('fechamos a cumieira'), 'fechamos a cumeeira');
      expect(c('10 barras de vergalão'), '10 barras de vergalhão');
      expect(c('fizemos o contrapizo'), 'fizemos o contrapiso');
    });

    test('mantém o plural e a maiúscula do começo', () {
      expect(c('Baudrames prontos'), 'Baldrames prontos');
      expect(c('os vergalões'), 'os vergalhões');
    });

    test('palavras comuns parecidas não são estragadas', () {
      const comuns = [
        'comprei brita na pedreira',
        'apareceu uma serpente no terreno',
        'fiz o conserto do portão',
        'teve um concerto na praça',
        'a viga estrutural ficou pronta',
        'a madeira talhada',
        'a cacimba secou',
        'troquei a botoneira do elevador',
        'a pintora veio hoje',
        'o portão está com ferrugem',
        'um investimento alto',
        'continuamos o serviço normalmente',
        'trabalhamos até tarde',
        'o soldado da esquadra',
        'a parede concreta',
        'cimentou o piso ontem',
        'plantamos sementes no jardim',
        'material de primeira',
        'paguei o pagamento do mês',
        'o ciumento do vizinho reclamou',
        'eu comento com ele amanhã',
        'forragem pro gado',
        'deu assentimento ao projeto',
        // as duas grafias valem: uma não "corrige" a outra
        'serviço de terraplenagem',
        'serviço de terraplanagem',
      ];
      for (final frase in comuns) {
        expect(c(frase), frase, reason: frase);
      }
    });

    test('nome próprio com maiúscula no meio da frase fica', () {
      expect(
          c('comprei na Baudrame Materiais'), 'comprei na Baudrame Materiais');
    });

    test('números e pontuação passam intactos', () {
      expect(c('paguei R\$ 1.200,50, ontem.'), 'paguei R\$ 1.200,50, ontem.');
      expect(c(''), '');
    });
  });

  group('Contagem de termos de obra', () {
    test('frase de obra pontua mais que uma parecida sem sentido', () {
      expect(VocabularioObra.contarTermos('comprei 10 sacos de cimento'),
          greaterThan(VocabularioObra.contarTermos('comprei 10 sapos de sim')));
    });

    test('conta depois de corrigir o ruído', () {
      expect(VocabularioObra.contarTermos('fizemos o contra piso'), 1);
      expect(VocabularioObra.contarTermos('fomos ao cinema'), 0);
    });
  });
}
