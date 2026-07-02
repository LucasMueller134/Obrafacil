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

    test('texto irrelevante não encontra nada', () {
      final nota = OcrNotaService.parsearTexto('apenas um rabisco');
      expect(nota.encontrouAlgo, isFalse);
    });
  });
}
