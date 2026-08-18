import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Card de seção de formulário - extraído de `task_form_dialog.dart`/
/// `project_form_dialog.dart` (`_FormCard`, duplicado idêntico nos dois) pra
/// um lugar só. Ícone opcional no título dá uma âncora visual pra escanear
/// rápido qual seção é qual, sem precisar ler o texto inteiro - mesma ideia
/// dos ícones em `_TaskOverviewCard`/`_WeeklyProductivityCard` do Dashboard.
class FormSectionCard extends StatelessWidget {
  const FormSectionCard({
    super.key,
    required this.title,
    this.icon,
    this.description,
    required this.children,
  });

  final String title;
  final IconData? icon;

  /// Legenda pequena e opcional abaixo do título - explica em 1 frase o que
  /// vai nessa seção/pra que serve, tipo um placeholder de seção. Sem isso,
  /// só o título curto ("Organização", "Cronograma") não dizia muito sobre o
  /// que esperar antes de olhar os campos.
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: 2),
            Text(
              description!,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
