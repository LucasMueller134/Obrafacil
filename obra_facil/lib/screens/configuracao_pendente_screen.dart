import 'package:flutter/material.dart';

import '../design/design.dart';
import '../router/transicoes.dart';
import 'demo_ia_screen.dart';

/// Mostrada quando o firebase_options.dart ainda tem placeholders —
/// orienta a configurar o projeto em vez de quebrar com erro de conexão.
class ConfiguracaoPendenteApp extends StatelessWidget {
  const ConfiguracaoPendenteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Obra na Mão — configuração',
      debugShowCheckedModeBanner: false,
      theme: TemaPrancheta.claro,
      darkTheme: TemaPrancheta.escuro,
      home: const TemaPrancheta(child: _Configuracao()),
    );
  }
}

class _Configuracao extends StatelessWidget {
  const _Configuracao();

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              Espaco.margem, Espaco.e48, Espaco.margem, Espaco.e32),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Icon(Icons.cloud_off_outlined, size: 48, color: c.grafite),
            ),
            const SizedBox(height: Espaco.e16),
            const Rotulo('Configuração'),
            const SizedBox(height: Espaco.e4),
            Text('Firebase ainda não configurado',
                style: Tipografia.tituloTela.copyWith(color: c.grafite)),
            const SizedBox(height: Espaco.e12),
            Text(
              'Para conectar o app ao seu projeto Firebase, rode no '
              'terminal, dentro da pasta do projeto:',
              style: Tipografia.corpo.copyWith(color: c.grafite2),
            ),
            const SizedBox(height: Espaco.e16),
            Folha(
              child: SelectableText(
                'dart pub global activate flutterfire_cli\n'
                'flutterfire configure',
                style: Tipografia.codigo.copyWith(color: c.grafite),
              ),
            ),
            const SizedBox(height: Espaco.e16),
            Text(
              'O comando gera o lib/firebase_options.dart com as chaves do '
              'seu projeto. Depois é só rodar o app de novo.',
              style: Tipografia.corpo.copyWith(color: c.grafite2),
            ),
            const SizedBox(height: Espaco.e32),
            BotaoContorno(
              rotulo: 'Testar as IAs sem conta (demonstração)',
              icone: Icons.auto_awesome_outlined,
              expandir: true,
              aoTocar: () =>
                  Navigator.of(context).push(rotaSuave(const DemoIaScreen())),
            ),
          ],
        ),
      ),
    );
  }
}
