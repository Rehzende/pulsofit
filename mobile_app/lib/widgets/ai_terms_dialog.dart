import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// Dialog that displays AI self-responsibility terms.
/// Must be accepted before using AI-generated workouts or the workout library.
class AiTermsDialog extends StatefulWidget {
  /// Called after the user accepts the terms.
  final VoidCallback? onAccepted;

  const AiTermsDialog({super.key, this.onAccepted});

  /// Shows the dialog. Returns true if accepted, false if dismissed.
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AiTermsDialog(),
    );
    return result == true;
  }

  @override
  State<AiTermsDialog> createState() => _AiTermsDialogState();
}

class _AiTermsDialogState extends State<AiTermsDialog> {
  bool _accepted = false;
  bool _isLoading = false;

  Future<void> _confirm() async {
    if (!_accepted) return;
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.acceptAiTerms();
      if (mounted) {
        widget.onAccepted?.call();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao registrar aceite: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFF1A1A2E),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.shield_outlined,
                      color: theme.primaryColor, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Termo de Responsabilidade',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Leia antes de continuar',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Terms content scrollable
            Container(
              height: 220,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _termsText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[300],
                    height: 1.6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Checkbox
            GestureDetector(
              onTap: () => setState(() => _accepted = !_accepted),
              behavior: HitTestBehavior.opaque,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _accepted ? theme.primaryColor : Colors.transparent,
                      border: Border.all(
                        color: _accepted ? theme.primaryColor : Colors.grey[600]!,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: _accepted
                        ? const Icon(Icons.check, color: Colors.black, size: 14)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Li e aceito os termos. Entendo que os treinos gerados por IA não substituem avaliação médica profissional.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[300],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[700]!),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_accepted && !_isLoading) ? _confirm : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      disabledBackgroundColor: theme.primaryColor.withOpacity(0.3),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Aceitar e Continuar',
                            style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static const String _termsText = '''
TERMO DE CIÊNCIA E RESPONSABILIDADE — TREINOS GERADOS POR INTELIGÊNCIA ARTIFICIAL

Ao utilizar os recursos de geração automática de treinos pelo aplicativo PULSO, o usuário declara estar ciente de que:

1. NATUREZA DO SERVIÇO: Os treinos sugeridos pelo sistema de Inteligência Artificial do PULSO são gerados de forma automatizada com base nas informações fornecidas pelo próprio usuário (anamnese, objetivos, histórico). Não constituem prescrição médica ou avaliação individualizada por profissional habilitado.

2. NÃO SUBSTITUIÇÃO DE AVALIAÇÃO PROFISSIONAL: Os treinos gerados pela IA não substituem a avaliação, prescrição ou acompanhamento de médico, educador físico ou profissional de saúde. Recomendamos fortemente a consulta a um profissional antes de iniciar qualquer programa de exercícios.

3. LIMITAÇÕES DO USUÁRIO: O usuário é o único responsável por conhecer suas próprias limitações físicas, condições de saúde, lesões ou restrições. Exercícios realizados além da capacidade física individual podem causar lesões.

4. VERACIDADE DAS INFORMAÇÕES: O usuário garante que as informações fornecidas na anamnese são verdadeiras e completas. Informações incorretas ou omissões podem resultar em sugestões inadequadas de treino.

5. ISENÇÃO DE RESPONSABILIDADE: O PULSO, seus criadores, desenvolvedores e colaboradores não se responsabilizam por eventuais lesões, danos à saúde ou qualquer consequência decorrente do uso dos treinos gerados pela IA.

6. AUTONOMIA E CONSCIÊNCIA: O usuário declara ter plena consciência dos riscos inerentes à prática de atividade física e assume total responsabilidade pela execução dos exercícios sugeridos, podendo interromper qualquer exercício que cause desconforto ou dor.

Ao aceitar este termo, confirmo que li, compreendi e concordo com todas as condições acima.
''';
}
