import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/services/cep_service.dart';

void main() {
  group('Formato do CEP', () {
    test('aceita com e sem máscara', () {
      expect(CepService.normalizar('89250-000'), '89250000');
      expect(CepService.normalizar('89250000'), '89250000');
      expect(CepService.normalizar(' 89.250-000 '), '89250000');
    });

    test('recusa o que não tem 8 dígitos', () {
      expect(CepService.normalizar('8925000'), isNull);
      expect(CepService.normalizar('892500001'), isNull);
      expect(CepService.normalizar('abcdefgh'), isNull);
      expect(CepService.normalizar(''), isNull);
    });

    test('recusa CEP zerado', () {
      expect(CepService.normalizar('00000000'), isNull);
    });

    test('formata para exibição', () {
      expect(CepService.formatar('89250000'), '89250-000');
      expect(CepService.formatar('89250-000'), '89250-000');
    });
  });

  group('Resposta dos Correios', () {
    test('CEP existente vira endereço preenchido', () {
      const corpo = '''
{"cep":"89250-000","logradouro":"Rua Exemplo","complemento":"",
"bairro":"Centro","localidade":"Jaraguá do Sul","uf":"SC"}''';
      final r = CepService.interpretar(corpo, '89250000');

      expect(r.valido, isTrue);
      expect(r.situacao, SituacaoCep.encontrado);
      expect(r.endereco!.cidade, 'Jaraguá do Sul');
      expect(r.endereco!.uf, 'SC');
      expect(r.endereco!.linha,
          'Rua Exemplo, Centro, Jaraguá do Sul - SC');
      expect(r.endereco!.cepFormatado, '89250-000');
    });

    test('CEP inexistente é recusado', () {
      final r = CepService.interpretar('{"erro": true}', '99999999');
      expect(r.valido, isFalse);
      expect(r.situacao, SituacaoCep.inexistente);
      expect(r.mensagem.toLowerCase(), contains('não existe'));
    });

    test('resposta sem cidade também é recusada', () {
      final r = CepService.interpretar('{"cep":"99999-999"}', '99999999');
      expect(r.situacao, SituacaoCep.inexistente);
    });

    test('resposta quebrada não afirma que o CEP é falso', () {
      // Portal de wi-fi, HTML de erro, JSON cortado: nesses casos o certo
      // é dizer que não deu para conferir, não acusar o usuário.
      for (final corpo in ['<html>erro</html>', '', '{"cep":']) {
        final r = CepService.interpretar(corpo, '89250000');
        expect(r.situacao, SituacaoCep.semResposta, reason: 'corpo: $corpo');
        expect(r.mensagem.toLowerCase(), contains('sem internet'));
      }
    });

    test('CEP de logradouro vazio (cidade inteira) ainda vale', () {
      const corpo = '''
{"cep":"89250-970","logradouro":"","bairro":"","localidade":"Jaraguá do Sul",
"uf":"SC"}''';
      final r = CepService.interpretar(corpo, '89250970');
      expect(r.valido, isTrue);
      expect(r.endereco!.linha, 'Jaraguá do Sul - SC');
    });
  });

  group('Consulta sem formato válido nem toca a rede', () {
    test('formato inválido volta na hora', () async {
      final r = await CepService.consultar('123');
      expect(r.situacao, SituacaoCep.formatoInvalido);
      expect(r.mensagem, contains('8 números'));
    });
  });
}
