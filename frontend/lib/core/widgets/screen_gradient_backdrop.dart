import 'package:flutter/material.dart';

/// Wash decorativo de gradiente no topo da tela — mais escuro em cima,
/// clareando até sumir num degradê, cobrindo só os primeiros ~260px (não a
/// tela inteira). Aplicado nas telas de conteúdo principal (Dashboard,
/// Tasks, Projects, Notes, Statistics); não existe equivalente no protótipo
/// React.
///
/// Fica atrás do conteúdo rolável (`Stack`) — como o `Positioned` não é
/// opaco no fim do degradê, o `scaffoldBackgroundColor` normal (do
/// `AppShell`) aparece por baixo assim que o conteúdo rola pra cima.
class ScreenGradientBackdrop extends StatelessWidget {
  const ScreenGradientBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 260,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.22),
                    colorScheme.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
