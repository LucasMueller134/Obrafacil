import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/services/ia/ocr_nota_service.dart';

void main() {
  group('Parser de nota fiscal (OCR)', () {
    test('extrai total, CNPJ, data e fornecedor de um cupom típico', () {
      const texto = '''
DEPOSITO SAO JOSE LTDA
Rua das Pedras, 123 - Centro
CNPJ: 12.345.678/0001-90
CUPOM FISCAL
10 SC CIMENTO CP-II 32,50 325,00
2 M3 AREIA MEDIA 90,00 180,00
TOTAL R\$ 505,00
15/06/2026 14:32
''';
      final nota = OcrNotaService.parsearTexto(texto);

      expect(nota.fornecedorNome, 'Deposito Sao Jose Ltda');
      expect(nota.cnpj, '12.345.678/0001-90');
      expect(nota.valorTotal, 505.00);
      expect(nota.data, DateTime(2026, 6, 15));
    });

    test('sem marcador de total, usa o maior valor monetário', () {
      const texto = '''
LOJA DO ZE MATERIAIS
TIJOLO 6 FUROS 450,00
FRETE 80,00
''';
      final nota = OcrNotaService.parsearTexto(texto);
      expect(nota.valorTotal, 450.00);
    });

    test('entende valores com separador de milhar', () {
      const texto = 'VALOR TOTAL 1.234,56';
      final nota = OcrNotaService.parsearTexto(texto);
      expect(nota.valorTotal, 1234.56);
    });

    test('ignora linhas de cabeçalho genéricas ao buscar o fornecedor', () {
      const texto = '''
CUPOM FISCAL ELETRONICO SAT
MADEIREIRA IPANEMA
TOTAL 99,90
''';
      final nota = OcrNotaService.parsearTexto(texto);
      expect(nota.fornecedorNome, 'Madeireira Ipanema');
    });

    test('descarta datas impossíveis', () {
      const texto = 'VENC 99/99/2026 TOTAL 10,00 EMISSAO 02/03/2026';
      final nota = OcrNotaService.parsearTexto(texto);
      expect(nota.data, DateTime(2026, 3, 2));
    });

    test('nota informal: valor inteiro com R\$ (sem centavos)', () {
      const texto = '''
DEPOSITO DO BAIRRO
areia e brita entregue
TOTAL R\$ 350
''';
      final nota = OcrNotaService.parsearTexto(texto);
      expect(nota.valorTotal, 350);
      expect(nota.fornecedorNome, 'Deposito do Bairro');
    });

    test('linha de total com inteiro sem R\$', () {
      final nota = OcrNotaService.parsearTexto('VALOR TOTAL 1.200');
      expect(nota.valorTotal, 1200);
    });

    test('datas com hífen e ponto também são aceitas', () {
      expect(OcrNotaService.parsearTexto('EMISSAO 03-06-2026').data,
          DateTime(2026, 6, 3));
      expect(OcrNotaService.parsearTexto('DATA 05.06.26').data,
          DateTime(2026, 6, 5));
    });

    test('rótulo "Razão Social" tem prioridade', () {
      const texto = '''
NOTA FISCAL
RAZAO SOCIAL: CASA DAS TINTAS LTDA
TOTAL 99,90
''';
      final nota = OcrNotaService.parsearTexto(texto);
      expect(nota.fornecedorNome, 'Casa das Tintas Ltda');
    });

    test('nome em caixa alta vizinho ao CNPJ é aceito', () {
      const texto = '''
DOCUMENTO AUXILIAR
PEDIDO 123
JOAQUIM SILVA
12.345.678/0001-90
TOTAL 55,00
''';
      final nota = OcrNotaService.parsearTexto(texto);
      expect(nota.fornecedorNome, 'Joaquim Silva');
      expect(nota.valorTotal, 55.00);
    });

    test('texto sem dados de nota não encontra nada', () {
      // Sem palavras com 4+ letras (candidatas a fornecedor), sem valores
      // monetários, CNPJ ou datas.
      final nota = OcrNotaService.parsearTexto('a1 b2\nc3 d4');
      expect(nota.encontrouAlgo, isFalse);
    });
  });

  group('Total: separa o valor da compra dos outros números do cupom', () {
    test('"total de itens" é contagem, não valor', () {
      const texto = '''
CASA DO CONSTRUTOR LTDA
CIMENTO CP-II 32,50
AREIA MEDIA 90,00
TOTAL DE ITENS: 2
TOTAL A PAGAR 122,50
''';
      expect(OcrNotaService.parsearTexto(texto).valorTotal, 122.50);
    });

    test('troco e desconto não são confundidos com o total', () {
      const texto = '''
TOTAL 250,00
DINHEIRO 300,00
TROCO 50,00
DESCONTO 15,00
''';
      expect(OcrNotaService.parsearTexto(texto).valorTotal, 250.00);
    });

    test('"valor total" vence um "total" solto no meio do cupom', () {
      const texto = '''
TOTAL ITEM 32,50
VALOR TOTAL 505,00
''';
      expect(OcrNotaService.parsearTexto(texto).valorTotal, 505.00);
    });

    test('subtotal só entra quando não há total', () {
      expect(OcrNotaService.parsearTexto('SUBTOTAL 80,00').valorTotal, 80.00);
      expect(
          OcrNotaService.parsearTexto('SUBTOTAL 80,00\nTOTAL 95,00').valorTotal,
          95.00);
    });

    test('rótulo numa linha e valor na seguinte', () {
      expect(
          OcrNotaService.parsearTexto('TOTAL A PAGAR\nR\$ 1.480,00').valorTotal,
          1480.00);
    });

    test('vírgula lida como ponto ainda vira valor', () {
      expect(OcrNotaService.parsearTexto('TOTAL R\$ 350.00').valorTotal, 350.00);
    });

    test('letra lida no lugar de dígito é corrigida', () {
      // O ML Kit troca 0 por O e 5 por S em impressão fraca.
      expect(OcrNotaService.parsearTexto('TOTAL R\$ 35O,OO').valorTotal, 350.00);
      expect(OcrNotaService.parsearTexto('VALOR TOTAL 1.2S0,00').valorTotal,
          1250.00);
    });

    test('data não é confundida com valor na ausência de total', () {
      final nota = OcrNotaService.parsearTexto('EMISSAO 05.06.26');
      expect(nota.valorTotal, isNull);
      expect(nota.data, DateTime(2026, 6, 5));
    });
  });

  group('CNPJ e data', () {
    test('prefere o CNPJ com dígito verificador válido', () {
      const texto = '''
CONSTRUMAIS LTDA
CNPJ 12.345.678/0001-90
CONTADOR 11.222.333/0001-81
TOTAL 10,00
''';
      expect(OcrNotaService.parsearTexto(texto).cnpj, '11.222.333/0001-81');
    });

    test('sem nenhum CNPJ válido, devolve o primeiro lido', () {
      final nota = OcrNotaService.parsearTexto('CNPJ 12.345.678/0001-90');
      expect(nota.cnpj, '12.345.678/0001-90');
    });

    test('valida dígito verificador', () {
      expect(OcrNotaService.cnpjValido('11222333000181'), isTrue);
      expect(OcrNotaService.cnpjValido('12345678000190'), isFalse);
      expect(OcrNotaService.cnpjValido('11111111111111'), isFalse);
    });

    test('emissão tem prioridade sobre vencimento', () {
      const texto = '''
VENCIMENTO 30/07/2026
EMISSAO 02/07/2026
''';
      expect(OcrNotaService.parsearTexto(texto).data, DateTime(2026, 7, 2));
    });

    test('data com hora é preferida à data solta', () {
      const texto = '''
28/05/2026
15/06/2026 14:32
''';
      expect(OcrNotaService.parsearTexto(texto).data, DateTime(2026, 6, 15));
    });
  });

  group('Fornecedor', () {
    test('rede conhecida é reconhecida em qualquer linha do topo', () {
      const texto = '''
CUPOM FISCAL ELETRONICO
LEROY MERLIN CIA BRASILEIRA
TOTAL 99,90
''';
      expect(OcrNotaService.parsearTexto(texto).fornecedorNome, 'Leroy Merlin');
    });

    test('CNPJ grudado no nome sai do nome', () {
      const texto = '''
CONSTRUMAIS MATERIAIS LTDA - CNPJ 11.222.333/0001-81
TOTAL 50,00
''';
      expect(OcrNotaService.parsearTexto(texto).fornecedorNome,
          'Construmais Materiais Ltda');
    });

    test('linha só de números não vira fornecedor', () {
      const texto = '''
4712 8899 0011 2233
DEPOSITO CENTRAL MATERIAIS
TOTAL 50,00
''';
      expect(OcrNotaService.parsearTexto(texto).fornecedorNome,
          'Deposito Central Materiais');
    });
  });
}
