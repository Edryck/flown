import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/auth_controller.dart';

enum _AuthMode { login, register }

/// Tela de login/registro — sem referência no protótipo React (só tinha
/// telas autenticadas), então redesenhada do zero seguindo a identidade
/// visual dele: gradiente "fantasy" idêntico ao `.fantasy-gradient-magic` de
/// `theme.css` (`#d4eeec → #e8f1f8 → #ebe6f3`, os mesmos tons de
/// magic-teal/soft-blue/ethereal-purple usados no fundo decorativo do
/// Dashboard original), logo no mesmo estilo do quadrado arredondado da
/// `TopNavBar`, e o alternador Login/Registro como pílula segmentada — mesmo
/// idioma visual de `_NavTab`/`_ViewSwitcher` já usado no resto do app.
///
/// Modo claro forçado (`Theme(data: AppTheme.light, ...)`) independente da
/// preferência de tema salva (`appThemeModeProvider`) — pedido explícito:
/// é a porta de entrada do app, deve ficar sempre com a identidade clara do
/// protótipo, não a última preferência dark/light do usuário.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _AuthMode _mode = _AuthMode.login;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(authControllerProvider.notifier);
    if (_mode == _AuthMode.login) {
      await controller.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } else {
      await controller.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;
    final isRegister = _mode == _AuthMode.register;
    // Só chama o backend em debug — em release o botão nunca aparece,
    // independente da resposta.
    final showDevBypass =
        kDebugMode &&
        (ref.watch(devBypassAvailableProvider).valueOrNull ?? false);

    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            // Mesmos 3 tons/ângulo de `.fantasy-gradient-magic` (theme.css).
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFD4EEEC), Color(0xFFE8F1F8), Color(0xFFEBE6F3)],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDDE4EC)),
                    // Mesmos valores de `.fantasy-glow-soft` (theme.css).
                    boxShadow: const [
                      BoxShadow(color: Color(0x267BA3C7), blurRadius: 20),
                      BoxShadow(
                        color: Color(0x145A8A86),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF3D4E5C),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.check_box_outlined,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Flown',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A202C),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isRegister
                                  ? 'Crie sua conta para organizar suas tarefas'
                                  : 'Bem-vindo de volta! Entre para continuar',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFF6B7B8F)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _AuthModeToggle(
                          isRegister: isRegister,
                          onChanged: isLoading
                              ? null
                              : (register) => setState(
                                  () => _mode = register
                                      ? _AuthMode.register
                                      : _AuthMode.login,
                                ),
                        ),
                        const SizedBox(height: 24),
                        if (isRegister) ...[
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Nome',
                            ),
                            validator: (value) =>
                                (value == null || value.trim().length < 2)
                                ? 'Nome muito curto'
                                : null,
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'E-mail',
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) =>
                              (value == null || !value.contains('@'))
                              ? 'E-mail inválido'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(labelText: 'Senha'),
                          obscureText: true,
                          validator: (value) =>
                              (value == null || value.length < 8)
                              ? 'Mínimo de 8 caracteres'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        if (authState.hasError)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              authState.error.toString(),
                              style: const TextStyle(color: Color(0xFFD97373)),
                            ),
                          ),
                        FilledButton(
                          onPressed: isLoading ? null : _submit,
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(isRegister ? 'Criar conta' : 'Entrar'),
                        ),
                        if (!kIsWeb) ...[
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const Expanded(
                                child: Divider(color: Color(0xFFDDE4EC)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  'ou',
                                  style: const TextStyle(
                                    color: Color(0xFF6B7B8F),
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: Divider(color: Color(0xFFDDE4EC)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: isLoading
                                ? null
                                : () => ref
                                      .read(authControllerProvider.notifier)
                                      .loginWithGoogle(),
                            child: const Text('Continuar com Google'),
                          ),
                        ],
                        if (showDevBypass) ...[
                          const SizedBox(height: 20),
                          const Divider(color: Color(0xFFDDE4EC)),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: isLoading
                                ? null
                                : () => ref
                                      .read(authControllerProvider.notifier)
                                      .devBypass(),
                            child: const Text(
                              'Entrar sem login (dev, SKIP_AUTH)',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Alternador Login/Registro como pílula segmentada — mesmo idioma visual de
/// `_NavTab` (`TopNavBar`) e `_ViewSwitcher` (`TasksScreen`): fundo neutro,
/// opção ativa em destaque com cor primária.
class _AuthModeToggle extends StatelessWidget {
  const _AuthModeToggle({required this.isRegister, required this.onChanged});

  final bool isRegister;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AuthModeTab(
              label: 'Entrar',
              active: !isRegister,
              onTap: () => onChanged?.call(false),
            ),
          ),
          Expanded(
            child: _AuthModeTab(
              label: 'Criar conta',
              active: isRegister,
              onTap: () => onChanged?.call(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthModeTab extends StatelessWidget {
  const _AuthModeTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? const Color(0xFF3D4E5C) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: active ? Colors.white : const Color(0xFF6B7B8F),
            ),
          ),
        ),
      ),
    );
  }
}
