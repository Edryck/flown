import 'package:flutter/material.dart';

/// FAB fixo no canto inferior direito com menu de atalhos de criação
/// rápida. Tradução fiel de GlobalFloatingActionButton.tsx
/// (docs/prototype/components/global-floating-action-button.md): mesmo
/// fechamento automático ao navegar, mesmos 3 atalhos no menu (Nova tarefa/
/// Novo projeto/Nova anotação) e o mesmo fechar-ao-clicar-fora — usando
/// `TapRegion` em vez do listener de `mousedown` do DOM que o React usa.
///
/// Diferença do protótipo: só esconde em `/settings` (+ rotas com `/edit`
/// ou `/delete`) — `/tasks/new`/`/projects/new` não existem mais como rota,
/// "Nova tarefa"/"Novo projeto" abrem modal (`onCreateTask`/
/// `onCreateProject`) em vez de navegar.
class GlobalFloatingActionButton extends StatefulWidget {
  const GlobalFloatingActionButton({
    super.key,
    required this.currentPath,
    required this.onCreateTask,
    required this.onCreateProject,
    required this.onCreateNote,
  });

  final String currentPath;

  /// Abre o TaskForm como modal (`showTaskFormDialog`) — diferente do
  /// protótipo, "Nova tarefa" não navega mais pra `/tasks/new`.
  final VoidCallback onCreateTask;

  /// Idem, pro ProjectForm (`showProjectFormDialog`) — "Novo projeto" não
  /// navega mais pra `/projects/new`.
  final VoidCallback onCreateProject;

  /// Idem, pro NoteForm (`showNoteFormDialog`) — "Nova anotação" não navega
  /// mais pra `/notes?newNote=true`.
  final VoidCallback onCreateNote;

  @override
  State<GlobalFloatingActionButton> createState() => _GlobalFloatingActionButtonState();
}

class _GlobalFloatingActionButtonState extends State<GlobalFloatingActionButton> {
  bool _isOpen = false;

  // '/tasks/new' e '/projects/new' saíram da lista: nenhuma das duas rotas
  // existe mais (criação virou modal, `showTaskFormDialog`/
  // `showProjectFormDialog`), não tem mais tela nenhuma pra esconder o FAB.
  static const _hiddenPrefixes = ['/settings'];

  bool get _shouldHide {
    final path = widget.currentPath;
    return _hiddenPrefixes.any(path.startsWith) || path.contains('/edit') || path.contains('/delete');
  }

  @override
  void didUpdateWidget(covariant GlobalFloatingActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPath != widget.currentPath && _isOpen) {
      setState(() => _isOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_shouldHide) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TapRegion(
      onTapOutside: (_) {
        if (_isOpen) setState(() => _isOpen = false);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isOpen)
            Container(
              width: 224,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MenuItem(
                    icon: Icons.check_box_outlined,
                    label: 'Nova tarefa',
                    onTap: () {
                      setState(() => _isOpen = false);
                      widget.onCreateTask();
                    },
                  ),
                  _MenuItem(
                    icon: Icons.folder_outlined,
                    label: 'Novo projeto',
                    onTap: () {
                      setState(() => _isOpen = false);
                      widget.onCreateProject();
                    },
                  ),
                  _MenuItem(
                    icon: Icons.sticky_note_2_outlined,
                    label: 'Nova anotação',
                    onTap: () {
                      setState(() => _isOpen = false);
                      widget.onCreateNote();
                    },
                  ),
                ],
              ),
            ),
          FloatingActionButton(
            tooltip: _isOpen ? 'Fechar ações rápidas' : 'Criar novo item',
            onPressed: () => setState(() => _isOpen = !_isOpen),
            child: Icon(_isOpen ? Icons.close : Icons.add),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
