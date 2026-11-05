/// Uma imagem "como vai ficar" de uma vista da obra (a fachada ou um
/// cômodo), gerada pela Cloud Function gerarImagem. Fica em
/// `obras/{id}/imagens/{vista}`; o arquivo, no Storage.
class ImagemIaModel {
  const ImagemIaModel({
    required this.vista,
    required this.nome,
    required this.url,
    this.geracoes = 1,
    this.criadaEm,
    this.modelo,
  });

  /// "fachada" ou o id do cômodo.
  final String vista;
  final String nome;
  final String url;

  /// Quantas vezes esta vista já foi gerada (o limite é por vista).
  final int geracoes;
  final DateTime? criadaEm;
  final String? modelo;

  bool get ehFachada => vista == 'fachada';

  factory ImagemIaModel.fromMap(String id, Map<String, dynamic> m) {
    final criada = m['criadaEm'];
    return ImagemIaModel(
      vista: m['vista'] as String? ?? id,
      nome: m['nome'] as String? ?? id,
      url: m['url'] as String? ?? '',
      geracoes: (m['geracoes'] as num?)?.toInt() ?? 1,
      // Timestamp do Firestore (tem toDate) ou texto ISO.
      criadaEm: criada is String
          ? DateTime.tryParse(criada)
          : (criada as dynamic)?.toDate() as DateTime?,
      modelo: m['modelo'] as String?,
    );
  }
}
