import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/services/ia/chave_acesso.dart';

/// Chaves montadas campo a campo, com o DV calculado à parte (módulo 11):
/// cUF 26, AAMM 2606, CNPJ 11.222.333/0001-81, modelo 65, série 001,
/// número 12345, emissão normal (1), código 12345678.
const _chaveNfce = '26260611222333000181650010000123451123456787';

/// A mesma loja, nota 12346 emitida em contingência offline (tpEmis 9).
const _chaveOffline = '26260611222333000181650010000123469876543213';

/// DANFE (modelo 55) de SP, maio de 2026, CNPJ 33.445.566/0001-86.
const _chaveDanfe = '35260533445566000186550010000007891112233447';

/// Soma dos pesos com resto 0: 11 - 0 = 11, que vira DV 0.
const _chaveDvZero = '26260611222333000181650010000000021123456780';

String _emGrupos(String chave) => [
      for (var i = 0; i < 44; i += 4) chave.substring(i, i + 4),
    ].join(' ');

void main() {
  group('Chave de acesso — dígito verificador', () {
    test('chave com DV certo é aceita', () {
      expect(ChaveAcesso.validar(_chaveNfce)?.digitos, _chaveNfce);
      expect(ChaveAcesso.validar(_chaveDanfe), isNotNull);
    });

    test('um dígito trocado pelo OCR é detectado', () {
      // troca o 7º dígito (dentro do CNPJ): o DV não fecha mais
      final errada = '${_chaveNfce.substring(0, 6)}2'
          '${_chaveNfce.substring(7)}';
      expect(ChaveAcesso.validar(errada), isNull);
      // DV trocado
      expect(ChaveAcesso.validar('${_chaveNfce.substring(0, 43)}0'), isNull);
    });

    test('resto 0 ou 1 dá DV 0', () {
      expect(ChaveAcesso.calcularDv(_chaveDvZero.substring(0, 43)), 0);
      expect(ChaveAcesso.validar(_chaveDvZero), isNotNull);
    });

    test('menos ou mais de 44 dígitos não é chave', () {
      expect(ChaveAcesso.validar(_chaveNfce.substring(1)), isNull);
      expect(ChaveAcesso.validar('${_chaveNfce}1'), isNull);
    });

    test('aceita a chave em grupos de 4, como vem impressa', () {
      expect(ChaveAcesso.validar(_emGrupos(_chaveNfce))?.digitos, _chaveNfce);
    });

    test('separa os campos da chave', () {
      final c = ChaveAcesso.validar(_chaveNfce)!;
      expect(c.uf, '26');
      expect(c.ano, 2026);
      expect(c.mes, 6);
      expect(c.cnpj, '11222333000181');
      expect(c.modelo, '65');
      expect(c.ehNfce, isTrue);
      expect(c.serie, '001');
      expect(c.numero, '000012345');
      expect(c.tipoEmissao, '1');
      expect(c.emContingencia, isFalse);
      expect(c.codigo, '12345678');
      expect(c.dv, 7);
      expect(ChaveAcesso.validar(_chaveOffline)!.emContingencia, isTrue);
      expect(ChaveAcesso.validar(_chaveDanfe)!.ehNfe, isTrue);
    });
  });

  group('Chave de acesso — códigos lidos na foto', () {
    test('QR da NFC-e emitida online: só a chave', () {
      final dados = DadosDoCodigo.ler(
          'https://nfce.sefaz.pe.gov.br/nfce/consulta?p=$_chaveNfce|2|1|1|'
          '3a9f1c2b4d5e6f708192a3b4c5d6e7f801234567');
      expect(dados?.chave.digitos, _chaveNfce);
      expect(dados?.diaEmissao, isNull);
      expect(dados?.valorTotal, isNull);
    });

    test('QR da contingência offline traz dia e valor com ponto decimal', () {
      final dados = DadosDoCodigo.ler(
          'http://nfce.sefaz.pe.gov.br/nfce/consulta?p=$_chaveOffline|2|1|'
          '15|350.00|6c4f5a3b2d1e0f9a8b7c6d5e4f3a2b1c0d9e8f7a|1|'
          '3a9f1c2b4d5e6f708192a3b4c5d6e7f801234567');
      expect(dados?.chave.digitos, _chaveOffline);
      expect(dados?.diaEmissao, 15);
      expect(dados?.valorTotal, 350.00);
    });

    test('QR com o separador codificado na URL (%7C)', () {
      final dados = DadosDoCodigo.ler('https://www.sefaz.rs.gov.br/NFCE/'
          'NFCE-COM.aspx?p=$_chaveOffline%7C2%7C1%7C03%7C1250.50%7Cabc%7C1%7Cff');
      expect(dados?.chave.digitos, _chaveOffline);
      expect(dados?.diaEmissao, 3);
      expect(dados?.valorTotal, 1250.50);
    });

    test('QR da versão 1, com chNFe, vNF e dhEmi em hexadecimal', () {
      // "2026-06-15T14:32:00-03:00" escrito em hexa, como o QR v1 traz
      final hexa = '2026-06-15T14:32:00-03:00'
          .codeUnits
          .map((c) => c.toRadixString(16).padLeft(2, '0'))
          .join();
      final dados = DadosDoCodigo.ler('http://nfce.sefaz.pe.gov.br/nfce?'
          'chNFe=$_chaveNfce&nVersao=100&tpAmb=1&dhEmi=$hexa&vNF=380.00');
      expect(dados?.chave.digitos, _chaveNfce);
      expect(dados?.dataEmissao, DateTime(2026, 6, 15));
      expect(dados?.valorTotal, 380.00);
    });

    test('CODE-128 do DANFE: os 44 dígitos', () {
      expect(DadosDoCodigo.ler(_chaveDanfe)?.chave.digitos, _chaveDanfe);
      expect(DadosDoCodigo.ler('NFe$_chaveDanfe')?.chave.digitos, _chaveDanfe);
    });

    test('código com DV errado ou que não é de nota é ignorado', () {
      expect(DadosDoCodigo.ler('${_chaveDanfe.substring(0, 43)}1'), isNull);
      expect(
          DadosDoCodigo.ler('https://www.loja.com.br/promocao?p=123'), isNull);
      expect(DadosDoCodigo.ler('7891234567895'), isNull); // EAN de produto
    });
  });

  group('Chave de acesso — no texto lido', () {
    test('em grupos de 4 perto de "CHAVE DE ACESSO"', () {
      final texto = 'Consulte pela Chave de Acesso em\n'
          'www.sefaz.pe.gov.br/nfce\n${_emGrupos(_chaveNfce)}\n'
          'CONSUMIDOR NAO IDENTIFICADO';
      expect(ChaveAcesso.procurarNoTexto(texto)?.digitos, _chaveNfce);
    });

    test('quebrada em duas linhas e com O no lugar de 0', () {
      final grupos = _emGrupos(_chaveNfce).split(' ');
      final texto = 'CHAVE DE ACESSO\n${grupos.take(6).join(' ')}\n'
              '${grupos.skip(6).join(' ')}'
          .replaceFirst('0611', 'O611');
      expect(ChaveAcesso.procurarNoTexto(texto)?.digitos, _chaveNfce);
    });

    test('rótulo colado na chave por dois-pontos', () {
      expect(
          ChaveAcesso.procurarNoTexto(
                  'CHAVE DE ACESSO:${_emGrupos(_chaveNfce)}')
              ?.digitos,
          _chaveNfce);
    });

    test('número colado na frente não esconde a chave', () {
      final texto = 'Protocolo 126260000123456 ${_emGrupos(_chaveDanfe)}';
      expect(ChaveAcesso.procurarNoTexto(texto)?.digitos, _chaveDanfe);
    });

    test('44 dígitos com DV errado não viram chave', () {
      final errada = '${_chaveNfce.substring(0, 10)}9'
          '${_chaveNfce.substring(11)}';
      expect(
          ChaveAcesso.procurarNoTexto('CHAVE DE ACESSO ${_emGrupos(errada)}'),
          isNull);
    });

    test('sem estrutura de chave (UF ou modelo impossível) não vira chave', () {
      // 44 dígitos com DV certo, mas UF 99 e modelo 00
      const base = '9926061122233300018100001000012345112345678';
      final chave = '$base${ChaveAcesso.calcularDv(base)}';
      expect(ChaveAcesso.validar(chave), isNotNull);
      expect(ChaveAcesso.procurarNoTexto(chave), isNull);
    });
  });
}
