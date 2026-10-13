
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/api_client.dart';
import 'core/theme.dart';
import 'features/auth/auth_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    RusmediaApp(api: ApiClient()),
  );
}

class RusmediaApp extends StatelessWidget {
  const RusmediaApp({
    super.key,
    required this.api,
  });

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RUSMEDIA',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('id'),
      supportedLocales: const [
        Locale('id'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AuthGate(api: api),
    );
  }
}
