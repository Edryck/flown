import 'package:flutter/material.dart';

import '../../features/search/providers/search_repository.dart';
import '../models/note.dart';
import '../models/project.dart';
import '../models/task.dart';

/// Dropdown de resultados de busca global - extraído de `top_nav_bar.dart`
/// pra ser reaproveitado também por `AppSidebar` (mesmo `SearchRepository`,
/// duas âncoras visuais diferentes - horizontal na barra, vertical na
/// sidebar). 3 seções (Projetos/Tarefas/Anotações), só as que tiverem
/// resultado.
class SearchResultsPanel extends StatelessWidget {
  const SearchResultsPanel({
    super.key,
    required this.width,
    required this.future,
    required this.onTapTask,
    required this.onTapProject,
    required this.onTapNote,
  });

  final double width;
  final Future<SearchResults>? future;
  final ValueChanged<Task> onTapTask;
  final ValueChanged<Project> onTapProject;
  final ValueChanged<Note> onTapNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      color: theme.cardTheme.color ?? colorScheme.surface,
      child: Container(
        width: width,
        constraints: const BoxConstraints(maxHeight: 420),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: FutureBuilder<SearchResults>(
          future: future,
          builder: (context, snapshot) {
            if (future == null) return const SizedBox.shrink();

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Erro ao buscar: ${snapshot.error}',
                  style: TextStyle(color: colorScheme.error, fontSize: 13),
                ),
              );
            }

            final results = snapshot.data;
            if (results == null || results.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Nenhum resultado encontrado',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (results.projects.isNotEmpty)
                    _SearchSection(
                      title: 'Projetos',
                      children: [
                        for (final project in results.projects)
                          _SearchResultTile(
                            icon: Icons.folder_outlined,
                            title: project.name,
                            onTap: () => onTapProject(project),
                          ),
                      ],
                    ),
                  if (results.tasks.isNotEmpty)
                    _SearchSection(
                      title: 'Tarefas',
                      children: [
                        for (final task in results.tasks)
                          _SearchResultTile(
                            icon: Icons.check_box_outlined,
                            title: task.title,
                            subtitle: task.status,
                            onTap: () => onTapTask(task),
                          ),
                      ],
                    ),
                  if (results.notes.isNotEmpty)
                    _SearchSection(
                      title: 'Anotações',
                      children: [
                        for (final note in results.notes)
                          _SearchResultTile(
                            icon: Icons.description_outlined,
                            title: note.title,
                            onTap: () => onTapNote(note),
                          ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SearchSection extends StatelessWidget {
  const _SearchSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (subtitle != null) ...[
              const SizedBox(width: 8),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
