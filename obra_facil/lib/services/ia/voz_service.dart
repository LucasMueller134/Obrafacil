import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../models/lancamento_model.dart';

/// Lançamento interpretado a partir da fala.
class LancamentoPorVoz {
  final String descricao;
  final double? valor;
  final CategoriaCusto categoria;
  final String? fornecedorNome;
  final String transcricao;

  const LancamentoPorVoz({
    required this.descricao,
    this.valor,
    required this.categoria,
    this.fornecedorNome,
    required this.transcricao,
  });
}

/// IA on-device nº 2b — lançamento por voz.
///
/// A transcrição usa o reconhecimento de fala do próprio Android
/// (speech_to_text); a interpretação da frase ("comprei 10 sacos de cimento
/// por 350 reais no Depósito São José") é feita por um parser em Dart.
class VozService {
  final SpeechToText _stt = SpeechToText();
  bool _inicializado = false;

  Future<bool> inicializar() async {
    if (_inicializado) return true;
    _inicializado = await _stt.initialize();
    return _inicializado;
  }

  bool get ouvindo => _stt.isListening;

  Future<void> ouvir(void Function(String textoParcial, bool finalizou) onTexto) async {
    await _stt.listen(
      // Modo ditado: tolera pausas na fala em vez de encerrar na primeira
      // respiração. Encerra após ~6s de silêncio ou quando o usuário toca
      // em "Concluir" (limite máximo de 2 minutos).
      listenFor: const Duration(minutes: 2),
      pauseFor: const Duration(seconds: 6),
      listenOptions: SpeechListenOptions(
        localeId: 'pt_BR',
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
      onResult: (SpeechRecognitionResult r) =>
          onTexto(r.recognizedWords, r.finalResult),
    );
  }

  Future<void> parar() => _stt.stop();

  // ------------------------------------------------------------- Parser

  static final RegExp _valorComMoeda = RegExp(
      r'(?:r\$\s*)?(\d+(?:[.,]\d{1,2})?)\s*(?:reais|real|conto[s]?|pila[s]?)',
      caseSensitive: false);
  static final RegExp _valorAposPor = RegExp(
      r'\bpor\s+(?:r\$\s*)?(\d+(?:[.,]\d{1,2})?)\b',
      caseSensitive: false);
  static final RegExp _fornecedorRegex = RegExp(
      r'\b(?:n[ao]|d[ao])\s+((?:loja|dep[oó]sito|mercado|madeireira|material(?:es)?)\s+[\wÀ-ÿ ]{2,30}|[A-ZÀ-Ý][\wÀ-ÿ]+(?:\s+[A-ZÀ-Ý][\wÀ-ÿ]+){0,3})\s*$');

  static const Map<CategoriaCusto, List<String>> _palavrasCategoria = {
    CategoriaCusto.maoDeObra: [
      'pedreiro', 'servente', 'diária', 'diaria', 'mão de obra', 'mao de obra',
      'eletricista', 'encanador', 'pintor', 'ajudante', 'empreiteiro',
      'carpinteiro', 'salário', 'salario', 'pagamento do', 'semana do',
    ],
    CategoriaCusto.material: [
      'cimento', 'areia', 'brita', 'tijolo', 'bloco', 'vergalhão', 'vergalhao',
      'ferro', 'madeira', 'telha', 'tinta', 'cano', 'pvc', 'fio', 'cabo',
      'argamassa', 'cal', 'piso', 'cerâmica', 'ceramica', 'porta', 'janela',
      'prego', 'parafuso', 'material', 'saco', 'massa corrida', 'reboco',
    ],
    CategoriaCusto.equipamento: [
      'betoneira', 'andaime', 'furadeira', 'serra', 'martelete',
      'aluguel', 'alugou', 'locação', 'locacao', 'equipamento', 'máquina',
      'maquina', 'compactador', 'gerador',
    ],
  };

  /// Parser puro (testável): interpreta a frase transcrita.
  static LancamentoPorVoz interpretar(String transcricao) {
    final texto = transcricao.trim();
    return LancamentoPorVoz(
      descricao: _limparDescricao(texto),
      valor: _extrairValor(texto),
      categoria: _classificarCategoria(texto),
      fornecedorNome: _extrairFornecedor(texto),
      transcricao: texto,
    );
  }

  static double? _extrairValor(String texto) {
    final m = _valorComMoeda.firstMatch(texto) ?? _valorAposPor.firstMatch(texto);
    if (m == null) return null;
    return double.tryParse(m.group(1)!.replaceAll(',', '.'));
  }

  static CategoriaCusto _classificarCategoria(String texto) {
    final t = texto.toLowerCase();
    var melhor = CategoriaCusto.outros;
    var melhorPontos = 0;
    for (final entry in _palavrasCategoria.entries) {
      final pontos =
          entry.value.where((palavra) => t.contains(palavra)).length;
      if (pontos > melhorPontos) {
        melhorPontos = pontos;
        melhor = entry.key;
      }
    }
    return melhor;
  }

  static String? _extrairFornecedor(String texto) {
    final m = _fornecedorRegex.firstMatch(texto);
    if (m == null) return null;
    final nome = m.group(1)!.trim();
    // Evita capturar restos de frase como "no total" ou "na obra".
    const ruido = ['total', 'obra', 'casa', 'terreno', 'serviço', 'servico'];
    if (ruido.any((r) => nome.toLowerCase() == r)) return null;
    return nome;
  }

  /// Remove a parte do valor/fornecedor para deixar uma descrição limpa.
  static String _limparDescricao(String texto) {
    var d = texto
        .replaceFirst(RegExp(r'^\s*(comprei|paguei|gastei|lancei|lançei|anota(r|í)?|registra(r)?)\s+',
            caseSensitive: false), '')
        .trim();
    if (d.isEmpty) return texto;
    return d[0].toUpperCase() + d.substring(1);
  }
}
