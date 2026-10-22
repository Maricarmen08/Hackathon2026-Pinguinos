import 'package:flutter/material.dart';
import 'api_client.dart';
import 'app.dart' show showError;
import '../ui/widgets/finki_brand.dart';

class InsightsPage extends StatefulWidget {
  final ApiClient api;
  final String businessId;
  const InsightsPage({super.key, required this.api, required this.businessId});
  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  final question = TextEditingController();
  String? answer;
  bool busy = false;
  Future<void> ask(String q) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final r = await widget.api.request(
          'POST', '/negocios/${widget.businessId}/consultas',
          body: {'pregunta': q});
      if (mounted) setState(() => answer = r['respuesta'] as String);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const FinkiBrandHeader(subtitle: 'Mis preguntas')),
      body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
        Text('Entiende tu negocio',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Respuestas basadas en lo que registraste en tu negocio.'),
        const SizedBox(height: 20),
        Wrap(spacing: 8, runSpacing: 10, children: [
          for (final q in [
            '¿Cuánto vendí hoy?',
            '¿Cuánto vendí este mes?',
            '¿En qué gasto más?',
            '¿Cuánto gasté esta semana?',
            '¿Cuánto me deben?',
            '¿Vendí más que el mes pasado?',
            '¿Cuánto dinero cobré esta semana?',
            '¿Cuánto gasté en mercadería?',
            'Mi resumen semanal'
          ])
            ActionChip(onPressed: busy ? null : () => ask(q), label: Text(q)),
        ]),
        const SizedBox(height: 12),
        TextField(
            controller: question,
            maxLength: 300,
            decoration: const InputDecoration(labelText: 'Tu pregunta'),
            onSubmitted: busy ? null : ask),
        FilledButton(
            onPressed: busy ? null : () => ask(question.text),
            child: const Text('Consultar mis registros')),
        if (busy) const Center(child: CircularProgressIndicator()),
        if (answer != null)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SelectableText(answer!,
                      style: const TextStyle(fontSize: 18, height: 1.5)))),
      ])));
}
