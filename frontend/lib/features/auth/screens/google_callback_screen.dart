import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/auth_controller.dart';

/// Rota só de Web (`/auth/google/callback`) pra onde o backend redireciona
/// de volta depois do login no Google — o Desktop nunca chega aqui, ele usa
/// o servidor HTTP local de `google_login_launcher_io.dart` em vez de uma
/// rota do próprio app. Fora do `ShellRoute` de propósito, igual `/login`.
class GoogleCallbackScreen extends ConsumerStatefulWidget {
  const GoogleCallbackScreen({super.key, this.handoff, this.error});

  final String? handoff;
  final String? error;

  @override
  ConsumerState<GoogleCallbackScreen> createState() =>
      _GoogleCallbackScreenState();
}

class _GoogleCallbackScreenState extends ConsumerState<GoogleCallbackScreen> {
  @override
  void initState() {
    super.initState();
    final handoff = widget.handoff;
    if (handoff != null) {
      // Fora do build de propósito — troca o handoff por tokens de verdade
      // e atualiza o estado global de auth (o router reage sozinho quando
      // authControllerProvider virar autenticado, ver app_router.dart).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(authControllerProvider.notifier)
            .completeGoogleWebLogin(handoff);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    String title;
    String subtitle;
    IconData icon;
    Color iconColor;
    var showRetryButton = false;
    var loading = false;

    if (widget.error != null) {
      title = 'Login com Google cancelado ou recusado';
      subtitle = 'Volte pra tela de login e tente de novo.';
      icon = Icons.error_outline;
      iconColor = const Color(0xFFD97373);
      showRetryButton = true;
    } else if (widget.handoff == null) {
      title = 'Nada por aqui';
      subtitle = 'Volte pra tela de login.';
      icon = Icons.help_outline;
      iconColor = const Color(0xFF6B7B8F);
      showRetryButton = true;
    } else if (authState.hasError) {
      title = 'Não deu pra concluir o login';
      subtitle = authState.error.toString();
      icon = Icons.error_outline;
      iconColor = const Color(0xFFD97373);
      showRetryButton = true;
    } else {
      title = 'Entrando...';
      subtitle = 'Só um instante.';
      icon = Icons.check_circle_outline;
      iconColor = const Color(0xFF6BB88F);
      loading = true;
    }

    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFD4EEEC), Color(0xFFE8F1F8), Color(0xFFEBE6F3)],
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDDE4EC)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (loading)
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(icon, size: 40, color: iconColor),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A202C),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF6B7B8F)),
                    ),
                    if (showRetryButton) ...[
                      const SizedBox(height: 20),
                      OutlinedButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Voltar para o login'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
