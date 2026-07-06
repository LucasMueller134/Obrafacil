import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../models/item_material_model.dart';
import '../../models/lancamento_model.dart';
import 'data_falada.dart';
import 'itens_parser.dart';
import 'numero_extenso.dart';

/// Lançamento interpretado a partir da fala.
class LancamentoPorVoz {
  final String descricao;
  final double? valor;
  final CategoriaCusto categoria;
  final String? fornecedorNome;

  /// Data falada ("ontem", "dia 5 de julho") — null quando o usuário
  /// não disse quando foi, e aí a tela mantém a data de hoje.
  final DateTime? data;

  /// Materiais detectados na fala — vão para o estoque na aprovação.
  final List<ItemMaterialModel> itens;
  final String transcricao;

  const LancamentoPorVoz({
    required this.descricao,
    this.valor,
    required this.categoria,
    this.fornecedorNome,
    this.data,
    this.itens = const [],
    required this.transcricao,
  });

  bool get temAlgo => valor != null || itens.isNotEmpty;
}

/// IA on-device nº 2b — lançamento por voz.
///
/// Pipeline: fala → transcrição (reconhecedor do Android) →
/// normalização de números por extenso ("trezentos e cinquenta" → 350) →
/// parsers de valor, data, categoria, fornecedor e materiais.
/// A interpretação é pura e rápida, então roda ao vivo a cada
/// resultado parcial.
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
      listenOptions: SpeechListenOptions(
        localeId: 'pt_BR',
        partialResults: true,
        listenMode: ListenMode.dictation,
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 6),
      ),
      onResult: (SpeechRecognitionResult r) =>
          onTexto(r.recognizedWords, r.finalResult),
    );
  }

  Future<void> parar() => _stt.stop();

  Future<void> cancelar() => _stt.cancel();

  // ------------------------------------------------------------- Parser

  /// Valor em reais, com centavos opcionais:
  /// "350 reais", "89,90 reais", "25 reais e 50 centavos", "40 conto".
  static final RegExp _valorReais = RegExp(
      r'(\d+(?:[.,]\d{1,2})?)\s*(?:reais|real|conto[s]?|pila[s]?)'
      r'(?:\s*e\s*(\d{1,2})\s*centavos?)?',
      caseSensitive: false);
  static final RegExp _valorComRs = RegExp(
      r'r\$\s*(\d+(?:[.,]\d{1,2})?)',
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
  /// Chamado ao vivo a cada resultado parcial — precisa ser leve.
  /// [agora] fixa o "hoje" das datas relativas nos testes.
  static LancamentoPorVoz interpretar(String transcricao, {DateTime? agora}) {
    final original = transcricao.trim();
    // "trezentos e cinquenta reais" → "350 reais"
    final texto = NumeroExtenso.normalizar(original);
    return LancamentoPorVoz(
      descricao: _limparDescricao(texto),
      valor: _extrairValor(texto),
      categoria: _classificarCategoria(texto),
      // nomes próprios ficam melhores no texto original
      fornecedorNome: _extrairFornecedor(original),
      // "ontem", "dia 5 de julho", "sexta passada"…
      data: DataFalada.extrair(texto, agora: agora),
      itens: ItensParser.deTexto(texto),
      transcricao: original,
    );
  }

  static double? _extrairValor(String texto) {
    final comReais = _valorReais.firstMatch(texto);
    if (comReais != null) {
      final base =
          double.tryParse(comReais.group(1)!.replaceAll(',', '.')) ?? 0;
      final centavos = int.tryParse(comReais.group(2) ?? '') ?? 0;
      final valor = base + centavos / 100;
      if (valor > 0) return valor;
    }
    final m = _valorComRs.firstMatch(texto) ?? _valorAposPor.firstMatch(texto);
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

  /// Remove data relativa e verbo iniciais para deixar uma descrição limpa
  /// ("Ontem comprei 10 sacos…" → "10 sacos…" — a data já foi capturada).
  static String _limparDescricao(String texto) {
    var d = texto
        .replaceFirst(
            RegExp(r'^\s*(hoje|ontem|anteontem)\s*,?\s+', caseSensitive: false),
            '')
        .replaceFirst(RegExp(r'^\s*(comprei|paguei|gastei|lancei|lançei|anota(r|í)?|registra(r)?)\s+',
            caseSensitive: false), '')
        .trim();
    if (d.isEmpty) return texto;
    return d[0].toUpperCase() + d.substring(1);
  }
}
