/// Constantes de domínio do ObraFácil.
abstract class AppConstants {
  static const String appName = 'ObraFácil';
  static const String slogan =
      'Menos caderninho. Mais controle. Inteligência no canteiro.';

  /// Fases padrão sugeridas ao criar o cronograma de uma obra.
  static const List<String> fasesPadrao = [
    'Fundação',
    'Estrutura',
    'Alvenaria',
    'Cobertura',
    'Instalações elétricas',
    'Instalações hidráulicas',
    'Reboco e contrapiso',
    'Revestimentos',
    'Pintura',
    'Acabamento',
  ];

  /// Unidades de medida usadas no estoque.
  static const List<String> unidades = [
    'un',
    'sc', // saco
    'm',
    'm²',
    'm³',
    'kg',
    'L',
    'br', // barra
    'lt', // lata
    'pc', // pacote
  ];

  /// Condições de clima do diário de obra.
  static const List<String> climas = [
    'Ensolarado',
    'Nublado',
    'Chuvoso',
    'Chuva forte',
  ];

  /// Materiais comuns — usados como sugestão no estoque e no
  /// mapeamento do reconhecimento de imagem.
  static const List<String> materiaisComuns = [
    'Cimento',
    'Areia',
    'Brita',
    'Tijolo',
    'Bloco de concreto',
    'Vergalhão de aço',
    'Madeira',
    'Telha',
    'Tinta',
    'Cano PVC',
    'Fio elétrico',
    'Argamassa',
    'Cal',
    'Piso cerâmico',
    'Porta',
    'Janela',
  ];
}
