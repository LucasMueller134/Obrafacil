import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_theme.dart';
import 'demo_ia_screen.dart';

/// Mostrada quando o firebase_options.dart ainda tem placeholders —
/// orienta a configurar o projeto em vez de quebrar com erro de conexão.
class ConfiguracaoPendenteApp extends StatelessWidget {
  const ConfiguracaoPendenteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ObraFácil — configuração',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                const Icon(Icons.cloud_off,
                    size: 56, color: AppColors.amareloCapacete),
                const SizedBox(height: 16),
                Text('Firebase ainda não configurado',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                const Text(
                  'Para conectar o app ao seu projeto Firebase, rode no '
                  'terminal, dentro da pasta do projeto:',
                  style: TextStyle(color: AppColors.textoSecundario),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.superficie,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borda),
                  ),
                  child: const Text(
                    'dart pub global activate flutterfire_cli\n'
                    'flutterfire configure',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: AppColors.laranja,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'O comando gera o lib/firebase_options.dart com as chaves '
                  'do seu projeto. Depois é só rodar o app de novo.',
                  style: TextStyle(color: AppColors.textoSecundario),
                ),
                const SizedBox(height: 24),
                Builder(
                  builder: (ctx) => OutlinedButton.icon(
                    onPressed: () => Navigator.of(ctx).push(
                      MaterialPageRoute(
                          builder: (_) => const DemoIaScreen()),
                    ),
                    icon: const Icon(Icons.auto_awesome),
                    label:
                        const Text('Testar as IAs sem conta (demonstração)'),
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
