import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'constants/app_theme.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'router/app_router.dart';
import 'screens/configuracao_pendente_screen.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');

  if (!DefaultFirebaseOptions.configurado) {
    runApp(const ConfiguracaoPendenteApp());
    return;
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Modo offline: cache local ilimitado + fila de escrita do Firestore.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(const ObraFacilApp());
}

class ObraFacilApp extends StatefulWidget {
  const ObraFacilApp({super.key});

  @override
  State<ObraFacilApp> createState() => _ObraFacilAppState();
}

class _ObraFacilAppState extends State<ObraFacilApp> {
  late final AuthProvider _auth = AuthProvider(AuthService());
  late final router = criarRouter(_auth);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _auth),
        Provider(create: (_) => FirestoreService()),
      ],
      child: MaterialApp.router(
        title: 'ObraFácil',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        routerConfig: router,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}
