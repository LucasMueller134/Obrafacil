// lib/constants/app_constants.dart

class AppConstants {
  // Cores principais
  static const String primaryColor = '#F97316'; // Laranja construção
  static const String secondaryColor = '#1E293B'; // Azul escuro
  static const String accentColor = '#FCD34D'; // Amarelo capacete

  // Firebase collections
  static const String usersCollection = 'usuarios';
  static const String obrasCollection = 'obras';
  static const String lancamentosCollection = 'lancamentos';
  static const String fornecedoresCollection = 'fornecedores';
  static const String estoqueCollection = 'estoque';
  static const String diarioCollection = 'diario';
  static const String cronogramaCollection = 'cronograma';
  static const String galeriaCollection = 'galeria';

  // Perfis de usuário
  static const String perfilDono = 'dono';
  static const String perfilMestre = 'mestre';

  // Categorias de lançamento
  static const List<String> categorias = [
    'Mão de Obra',
    'Materiais',
    'Equipamentos Alugados',
    'Transporte',
    'Serviços Terceirizados',
    'Outros',
  ];

  // Fases da obra
  static const List<String> fasesObra = [
    'Fundação',
    'Alvenaria',
    'Estrutura',
    'Cobertura',
    'Instalações Elétricas',
    'Instalações Hidráulicas',
    'Revestimento',
    'Acabamento',
    'Pintura',
    'Entrega',
  ];

  // Status da obra
  static const String statusEmAndamento = 'Em Andamento';
  static const String statusPausada = 'Pausada';
  static const String statusConcluida = 'Concluída';

  // Status do pagamento
  static const String pagamentoPago = 'Pago';
  static const String pagamentoAPagar = 'A Pagar';
  static const String pagamentoParcelado = 'Parcelado';

  // API Keys (substitua pelas suas)
  static const String claudeApiKey = 'SUA_CLAUDE_API_KEY_AQUI';
  static const String openAiApiKey = 'SUA_OPENAI_API_KEY_AQUI';
  static const String claudeApiUrl = 'https://api.anthropic.com/v1/messages';
  static const String whisperApiUrl = 'https://api.openai.com/v1/audio/transcriptions';

  // Configurações
  static const int maxFotosPorObra = 100;
  static const int limiteEstoqueAlerta = 5;
  static const int diasSemLancamentoAlerta = 3;
}
