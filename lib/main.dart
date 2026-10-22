import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'v1/api_client.dart';
import 'v1/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(PinguinosAiApp(api: ApiClient()));
}

class PinguinosAiApp extends StatelessWidget {
  final ApiClient api;
  const PinguinosAiApp({super.key, required this.api});
  @override
  Widget build(BuildContext context) => MaterialApp(
      title: 'FINKI',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'PE'),
      supportedLocales: const [Locale('es', 'PE')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      theme: AppTheme.lightTheme,
      home: SessionGate(api: api));
}
