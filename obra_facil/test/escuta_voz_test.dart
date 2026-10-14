import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/services/ia/escuta_voz.dart';

void main() {
  group('Erro do reconhecedor — cada código vira mensagem e saída', () {
    TipoErroVoz tipo(String codigo, {bool online = false}) =>
        ErroVoz.de(codigo, online: online).tipo;

    test('não entendeu a fala: tentar de novo', () {
      for (final codigo in ['error_no_match', 'error_speech_timeout']) {
        final e = ErroVoz.de(codigo);
        expect(e.tipo, TipoErroVoz.naoEntendi, reason: codigo);
        expect(e.mensagem, contains('Não entendi'), reason: codigo);
        expect(e.mensagem, contains('Tente de novo'), reason: codigo);
        expect(e.ofereceOnline, isFalse, reason: codigo);
      }
    });

    test('sem permissão: fala do microfone', () {
      final e = ErroVoz.de('error_permission');
      expect(e.tipo, TipoErroVoz.microfone);
      expect(e.mensagem, contains('microfone'));
      expect(e.ofereceOnline, isFalse);
    });

    test('ocupado: esperar e tentar de novo', () {
      final e = ErroVoz.de('error_busy');
      expect(e.tipo, TipoErroVoz.ocupado);
      expect(e.mensagem, contains('Tentar de novo'));
    });

    test('áudio, excesso de pedidos, cliente e desconhecido', () {
      expect(tipo('error_audio_error'), TipoErroVoz.audio);
      expect(tipo('error_too_many_requests'), TipoErroVoz.muitasTentativas);
      expect(tipo('error_client'), TipoErroVoz.desconhecido);
      expect(tipo('error_unknown (5)'), TipoErroVoz.desconhecido);
      expect(tipo('qualquer coisa nova'), TipoErroVoz.desconhecido);
    });

    test('no aparelho, idioma, rede ou servidor = falta o pacote offline', () {
      const codigos = [
        'error_language_not_supported',
        'error_language_unavailable',
        'error_network',
        'error_network_timeout',
        'error_server',
        'error_server_disconnected',
      ];
      for (final codigo in codigos) {
        final e = ErroVoz.de(codigo);
        expect(e.tipo, TipoErroVoz.pacoteOffline, reason: codigo);
        // A saída é escolha do usuário: instrução + botão do online.
        expect(e.ofereceOnline, isTrue, reason: codigo);
        expect(e.mensagem, ErroVoz.instrucaoPacoteOffline, reason: codigo);
      }
      expect(ErroVoz.instrucaoPacoteOffline, contains('offline'));
      expect(ErroVoz.instrucaoPacoteOffline, contains('Português (Brasil)'));
      expect(ErroVoz.instrucaoPacoteOffline, contains('Google'));
    });

    test('já no online, rede ou idioma não oferecem o online de novo', () {
      for (final codigo in [
        'error_network',
        'error_server',
        'error_language_unavailable',
      ]) {
        final e = ErroVoz.de(codigo, online: true);
        expect(e.tipo, TipoErroVoz.semInternet, reason: codigo);
        expect(e.ofereceOnline, isFalse, reason: codigo);
      }
    });

    test('maiúscula e espaço no código não atrapalham', () {
      expect(tipo('  ERROR_NO_MATCH '), TipoErroVoz.naoEntendi);
    });

    test('a escuta que nem começou tem saída', () {
      expect(ErroVoz.naoComecou.mensagem, contains('Tentar de novo'));
      expect(ErroVoz.naoComecou.ofereceOnline, isFalse);
    });
  });

  group('Aviso de confiança baixa', () {
    test('abaixo de 0,5 pede para conferir a transcrição', () {
      expect(ErroVoz.avisoDeConfianca(0.3), contains('confira a transcrição'));
      expect(ErroVoz.avisoDeConfianca(0.49), isNotNull);
    });

    test('confiança boa ou não informada não assusta ninguém', () {
      expect(ErroVoz.avisoDeConfianca(0.5), isNull);
      expect(ErroVoz.avisoDeConfianca(0.92), isNull);
      expect(ErroVoz.avisoDeConfianca(0), isNull);
      expect(ErroVoz.avisoDeConfianca(-1), isNull);
      expect(ErroVoz.avisoDeConfianca(null), isNull);
    });
  });

  group('Resultado do reconhecedor', () {
    const r = ResultadoVoz([
      ('paguei duzentos e', 0.8),
      ('paguei duzentos e oitenta', 0.3),
      ('pagamos duzentos e oitenta', -1),
    ], finalizou: true);

    test('a principal é a primeira hipótese', () {
      expect(r.texto, 'paguei duzentos e');
      expect(r.confianca, 0.8);
    });

    test('confiança da hipótese escolhida, não da principal', () {
      expect(r.confiancaDe('paguei duzentos e oitenta'), 0.3);
      expect(r.confiancaDe(' paguei duzentos e oitenta '), 0.3);
      expect(r.confiancaDe('pagamos duzentos e oitenta'), isNull);
      expect(r.confiancaDe('outra frase'), isNull);
    });

    test('sem hipóteses', () {
      const vazio = ResultadoVoz([], finalizou: false);
      expect(vazio.texto, '');
      expect(vazio.confianca, isNull);
    });
  });

  group('Fim da fala com barulho de obra', () {
    final t0 = DateTime(2026, 7, 6, 10);
    DateTime em(int ms) => t0.add(Duration(milliseconds: ms));

    test('antes de ouvir qualquer palavra, não encerra', () {
      final m = MonitorDeFala();
      expect(m.deveEncerrar(em(60000)), isFalse);
      m.registrar('', em(1000));
      expect(m.deveEncerrar(em(60000)), isFalse);
    });

    test('encerra ~4 s depois da última palavra nova', () {
      final m = MonitorDeFala();
      expect(m.registrar('paguei', em(0)), isTrue);
      expect(m.registrar('paguei o pedreiro', em(1500)), isTrue);
      expect(m.deveEncerrar(em(5000)), isFalse);
      expect(m.deveEncerrar(em(5500)), isTrue);
    });

    test('revisão da mesma palavra (ruído) não mantém a gravação aberta', () {
      final m = MonitorDeFala();
      m.registrar('paguei sento', em(0));
      // O reconhecedor troca "sento" por "cento" sem palavra nova.
      expect(m.registrar('paguei cento', em(3000)), isFalse);
      expect(m.registrar('Paguei  cento', em(3500)), isFalse);
      expect(m.deveEncerrar(em(4000)), isTrue);
    });

    test('nova gravação começa do zero', () {
      final m = MonitorDeFala()..registrar('paguei 50', em(0));
      m.reiniciar();
      expect(m.deveEncerrar(em(10000)), isFalse);
      expect(m.registrar('frete', em(10000)), isTrue);
    });

    test('o tempo de silêncio é configurável', () {
      final m = MonitorDeFala(silencio: const Duration(seconds: 2))
        ..registrar('frete 80', em(0));
      expect(m.deveEncerrar(em(1999)), isFalse);
      expect(m.deveEncerrar(em(2000)), isTrue);
    });
  });
}
