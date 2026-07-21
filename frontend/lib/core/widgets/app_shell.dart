import 'package:flutter/material.dart';

/// Casca comum das telas autenticadas — navegacao lateral (desktop-first,
/// CLAUDE.md: "Plataformas: Desktop -> Web") + o conteudo da rota atual.
/// Equivalente ao `TopNavBar` + `RootLayout` do protototipo React, mas sem
/// copiar a estrutura dele — as rotas aqui sao as reais do backend, nao as
/// de demo do protótipo (ver docs/prototype/00-overview.md).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.currentPath, required this.onDestinationSelected, required this.child});

  final String currentPath;
  final ValueChanged<String> onDestinationSelected;
  final Widget child;

  static const _destinations = [
    (path: '/dashboard', icon: Icons.dashboard_outlined, label: 'Painel'),
    (path: '/projects', icon: Icons.folder_outlined, label: 'Projetos'),
    (path: '/tasks', icon: Icons.check_box_outlined, label: 'Tarefas'),
    (path: '/notes', icon: Icons.note_outlined, label: 'Anotações'),
    (path: '/focus', icon: Icons.timer_outlined, label: 'Foco'),
    (path: '/search', icon: Icons.search_outlined, label: 'Busca'),
    (path: '/trash', icon: Icons.delete_outline, label: 'Lixeira'),
    (path: '/settings', icon: Icons.settings_outlined, label: 'Configurações'),
  ];

  int get _selectedIndex {
    final index = _destinations.indexWhere((d) => currentPath.startsWith(d.path));
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) => onDestinationSelected(_destinations[index].path),
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
