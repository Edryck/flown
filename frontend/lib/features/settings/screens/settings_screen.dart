import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/models/task_priority.dart';
import '../../../core/navigation/nav_layout_provider.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/theme/theme_preset_provider.dart';
import '../../../core/theme/theme_presets.dart';
import '../../../core/widgets/priority_badge.dart';
import '../../auth/providers/auth_controller.dart';
import '../../auth/providers/auth_repository.dart';
import '../providers/settings_preferences.dart';

enum _SettingsSection {
  account,
  appearance,
  focusMode,
  tasks,
  notes,
  notifications,
  about,
}

/// Tela de Configurações — tradução de Settings.tsx
/// (docs/prototype/screens/settings.md): mesmos campos/controles dos cards
/// de Aparência/Preferências de Tarefas/Preferências de Anotações/
/// Notificações/Informações do App. Diferenças deliberadas do protótipo:
///   - navegação por sidebar em vez dos cards empilhados um embaixo do
///     outro — a tela cresceu (6 seções + Conta) e ficou longa demais pra
///     rolar; decisão tomada depois de traduzir a versão empilhada, não
///     parte da tradução original;
///   - "Conta" é a primeira seção (não existe no protótipo — ele não
///     modela login/logout) — editar nome/e-mail, trocar senha, sair;
///   - "Salvar alterações" persiste de verdade (`shared_preferences`,
///     `settings_preferences.dart`) — o protótipo só mostra um toast e
///     esquece tudo ao recarregar;
///   - "Lixeira" fica fora do painel de seções, como atalho de navegação
///     separado (não é uma preferência).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  _SettingsSection _section = _SettingsSection.account;

  bool _prefsHydrated = false;
  TaskPriority _defaultPriority = TaskPriority.medium;
  String _defaultStatus = 'todo';
  bool _showCompletedTasks = true;
  bool _autoArchiveDone = false;
  String _defaultNoteView = 'grid';
  bool _autoSaveNotes = true;
  bool _showNotePreview = true;
  bool _notifyDueDate = true;
  bool _notifyOverdue = true;
  bool _notifyStatusChange = false;
  bool _notifyReminder = true;
  bool _particlesEnabled = true;
  int _particleCount = 80;
  double _particleSpeed = 0.6;
  double _particleLineDistance = 120;
  bool _particlesInteractive = true;
  int _pomodoroFocusMinutes = 25;
  int _pomodoroShortBreakMinutes = 5;
  int _pomodoroLongBreakMinutes = 15;
  int _pomodoroCyclesBeforeLongBreak = 4;
  bool _savingPrefs = false;

  bool _accountHydrated = false;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _savingAccount = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _hydratePrefs(SettingsPreferences prefs) {
    _defaultPriority = prefs.defaultPriority;
    _defaultStatus = prefs.defaultStatus;
    _showCompletedTasks = prefs.showCompletedTasks;
    _autoArchiveDone = prefs.autoArchiveDone;
    _defaultNoteView = prefs.defaultNoteView;
    _autoSaveNotes = prefs.autoSaveNotes;
    _showNotePreview = prefs.showNotePreview;
    _notifyDueDate = prefs.notifyDueDate;
    _notifyOverdue = prefs.notifyOverdue;
    _notifyStatusChange = prefs.notifyStatusChange;
    _notifyReminder = prefs.notifyReminder;
    _particlesEnabled = prefs.particlesEnabled;
    _particleCount = prefs.particleCount;
    _particleSpeed = prefs.particleSpeed;
    _particleLineDistance = prefs.particleLineDistance;
    _particlesInteractive = prefs.particlesInteractive;
    _pomodoroFocusMinutes = prefs.pomodoroFocusMinutes;
    _pomodoroShortBreakMinutes = prefs.pomodoroShortBreakMinutes;
    _pomodoroLongBreakMinutes = prefs.pomodoroLongBreakMinutes;
    _pomodoroCyclesBeforeLongBreak = prefs.pomodoroCyclesBeforeLongBreak;
    _prefsHydrated = true;
  }

  Future<void> _savePreferences() async {
    setState(() => _savingPrefs = true);
    try {
      await ref
          .read(settingsPreferencesControllerProvider.notifier)
          .save(
            SettingsPreferences(
              defaultPriority: _defaultPriority,
              defaultStatus: _defaultStatus,
              showCompletedTasks: _showCompletedTasks,
              autoArchiveDone: _autoArchiveDone,
              defaultNoteView: _defaultNoteView,
              autoSaveNotes: _autoSaveNotes,
              showNotePreview: _showNotePreview,
              notifyDueDate: _notifyDueDate,
              notifyOverdue: _notifyOverdue,
              notifyStatusChange: _notifyStatusChange,
              notifyReminder: _notifyReminder,
              particlesEnabled: _particlesEnabled,
              particleCount: _particleCount,
              particleSpeed: _particleSpeed,
              particleLineDistance: _particleLineDistance,
              particlesInteractive: _particlesInteractive,
              pomodoroFocusMinutes: _pomodoroFocusMinutes,
              pomodoroShortBreakMinutes: _pomodoroShortBreakMinutes,
              pomodoroLongBreakMinutes: _pomodoroLongBreakMinutes,
              pomodoroCyclesBeforeLongBreak: _pomodoroCyclesBeforeLongBreak,
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurações salvas com sucesso')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPrefs = false);
    }
  }

  Future<void> _saveAccount() async {
    setState(() => _savingAccount = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateProfile(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conta atualizada com sucesso')),
        );
      }
    } catch (e) {
      if (mounted) {
        final message = e is ApiException
            ? e.message
            : 'Erro ao atualizar a conta';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _savingAccount = false);
    }
  }

  Future<void> _changePassword() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trocar senha'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentController,
                decoration: const InputDecoration(labelText: 'Senha atual'),
                obscureText: true,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newController,
                decoration: const InputDecoration(labelText: 'Nova senha'),
                obscureText: true,
                validator: (v) => (v == null || v.length < 8)
                    ? 'Mínimo de 8 caracteres'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Trocar senha'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref
            .read(authRepositoryProvider)
            .changePassword(
              currentPassword: currentController.text,
              newPassword: newController.text,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Senha alterada com sucesso')),
          );
        }
      } catch (e) {
        if (mounted) {
          final message = e is ApiException
              ? e.message
              : 'Erro ao trocar a senha';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      }
    }
    currentController.dispose();
    newController.dispose();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
          'Você vai precisar entrar de novo pra acessar suas tarefas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefsAsync = ref.watch(settingsPreferencesControllerProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final themePreset =
        ref.watch(appThemePresetProvider).valueOrNull ?? ThemePreset.flown;
    final navLayout = ref.watch(appNavLayoutProvider).valueOrNull ?? NavLayout.sidebar;
    final isDark = switch (themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };
    final authState = ref.watch(authControllerProvider);
    final user = authState.valueOrNull;

    prefsAsync.whenData((prefs) {
      if (!_prefsHydrated) _hydratePrefs(prefs);
    });
    if (user != null && !_accountHydrated) {
      _nameController.text = user.name;
      _emailController.text = user.email;
      _accountHydrated = true;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configurações',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Personalize o Flown de acordo com suas preferências.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 220,
                      child: _Sidebar(
                        selected: _section,
                        onSelected: (s) => setState(() => _section = s),
                      ),
                    ),
                    VerticalDivider(
                      width: 1,
                      color: theme.colorScheme.outlineVariant,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: switch (_section) {
                          _SettingsSection.account => _AccountSection(
                            nameController: _nameController,
                            emailController: _emailController,
                            saving: _savingAccount,
                            onSave: _saveAccount,
                            onChangePassword: _changePassword,
                            onLogout: _logout,
                          ),
                          _SettingsSection.appearance => _AppearanceSection(
                            isDark: isDark,
                            onChanged: (dark) => ref
                                .read(appThemeModeProvider.notifier)
                                .toggle(
                                  dark ? Brightness.light : Brightness.dark,
                                ),
                            themePreset: themePreset,
                            onThemePresetChanged: (preset) => ref
                                .read(appThemePresetProvider.notifier)
                                .select(preset),
                            navLayout: navLayout,
                            onNavLayoutChanged: (layout) => ref
                                .read(appNavLayoutProvider.notifier)
                                .select(layout),
                            particlesEnabled: _particlesEnabled,
                            onParticlesEnabledChanged: (v) =>
                                setState(() => _particlesEnabled = v),
                            particleCount: _particleCount,
                            onParticleCountChanged: (v) =>
                                setState(() => _particleCount = v),
                            particleSpeed: _particleSpeed,
                            onParticleSpeedChanged: (v) =>
                                setState(() => _particleSpeed = v),
                            particleLineDistance: _particleLineDistance,
                            onParticleLineDistanceChanged: (v) =>
                                setState(() => _particleLineDistance = v),
                            particlesInteractive: _particlesInteractive,
                            onParticlesInteractiveChanged: (v) =>
                                setState(() => _particlesInteractive = v),
                            saving: _savingPrefs,
                            onSave: _savePreferences,
                          ),
                          _SettingsSection.focusMode => _FocusModeSection(
                            pomodoroFocusMinutes: _pomodoroFocusMinutes,
                            onPomodoroFocusMinutesChanged: (v) =>
                                setState(() => _pomodoroFocusMinutes = v),
                            pomodoroShortBreakMinutes:
                                _pomodoroShortBreakMinutes,
                            onPomodoroShortBreakMinutesChanged: (v) => setState(
                              () => _pomodoroShortBreakMinutes = v,
                            ),
                            pomodoroLongBreakMinutes:
                                _pomodoroLongBreakMinutes,
                            onPomodoroLongBreakMinutesChanged: (v) => setState(
                              () => _pomodoroLongBreakMinutes = v,
                            ),
                            pomodoroCyclesBeforeLongBreak:
                                _pomodoroCyclesBeforeLongBreak,
                            onPomodoroCyclesBeforeLongBreakChanged: (v) =>
                                setState(
                                  () => _pomodoroCyclesBeforeLongBreak = v,
                                ),
                            saving: _savingPrefs,
                            onSave: _savePreferences,
                          ),
                          _SettingsSection.tasks => _TaskPrefsSection(
                            defaultPriority: _defaultPriority,
                            onDefaultPriorityChanged: (v) =>
                                setState(() => _defaultPriority = v),
                            defaultStatus: _defaultStatus,
                            onDefaultStatusChanged: (v) =>
                                setState(() => _defaultStatus = v),
                            showCompletedTasks: _showCompletedTasks,
                            onShowCompletedTasksChanged: (v) =>
                                setState(() => _showCompletedTasks = v),
                            autoArchiveDone: _autoArchiveDone,
                            onAutoArchiveDoneChanged: (v) =>
                                setState(() => _autoArchiveDone = v),
                            saving: _savingPrefs,
                            onSave: _savePreferences,
                          ),
                          _SettingsSection.notes => _NotePrefsSection(
                            defaultNoteView: _defaultNoteView,
                            onDefaultNoteViewChanged: (v) =>
                                setState(() => _defaultNoteView = v),
                            autoSaveNotes: _autoSaveNotes,
                            onAutoSaveNotesChanged: (v) =>
                                setState(() => _autoSaveNotes = v),
                            showNotePreview: _showNotePreview,
                            onShowNotePreviewChanged: (v) =>
                                setState(() => _showNotePreview = v),
                            saving: _savingPrefs,
                            onSave: _savePreferences,
                          ),
                          _SettingsSection.notifications =>
                            _NotificationsSection(
                              notifyDueDate: _notifyDueDate,
                              onNotifyDueDateChanged: (v) =>
                                  setState(() => _notifyDueDate = v),
                              notifyOverdue: _notifyOverdue,
                              onNotifyOverdueChanged: (v) =>
                                  setState(() => _notifyOverdue = v),
                              notifyStatusChange: _notifyStatusChange,
                              onNotifyStatusChangeChanged: (v) =>
                                  setState(() => _notifyStatusChange = v),
                              notifyReminder: _notifyReminder,
                              onNotifyReminderChanged: (v) =>
                                  setState(() => _notifyReminder = v),
                              saving: _savingPrefs,
                              onSave: _savePreferences,
                            ),
                          _SettingsSection.about => _AboutSection(
                            isDark: isDark,
                          ),
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              // `ListTile` pinta o splash de tinta no `Material` ancestral mais
              // próximo — sem isso, o `Container` decorado (com `color`) acima
              // escondia o efeito de toque (aviso do framework em runtime).
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Lixeira'),
                  subtitle: const Text(
                    'Projetos, tarefas e anotações excluídos',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/trash'),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selected, required this.onSelected});

  final _SettingsSection selected;
  final ValueChanged<_SettingsSection> onSelected;

  static const _items = [
    (
      section: _SettingsSection.account,
      icon: Icons.person_outline,
      label: 'Conta',
    ),
    (
      section: _SettingsSection.appearance,
      icon: Icons.palette_outlined,
      label: 'Aparência',
    ),
    (
      section: _SettingsSection.focusMode,
      icon: Icons.timer_outlined,
      label: 'Modo Foco',
    ),
    (
      section: _SettingsSection.tasks,
      icon: Icons.check_box_outlined,
      label: 'Tarefas',
    ),
    (
      section: _SettingsSection.notes,
      icon: Icons.description_outlined,
      label: 'Anotações',
    ),
    (
      section: _SettingsSection.notifications,
      icon: Icons.notifications_outlined,
      label: 'Notificações',
    ),
    (section: _SettingsSection.about, icon: Icons.info_outline, label: 'Sobre'),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Material(
                color: item.section == selected
                    ? colorScheme.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onSelected(item.section),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          size: 18,
                          color: item.section == selected
                              ? colorScheme.onPrimary
                              : colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: item.section == selected
                                ? colorScheme.onPrimary
                                : colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({
    required this.nameController,
    required this.emailController,
    required this.saving,
    required this.onSave,
    required this.onChangePassword,
    required this.onLogout,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onChangePassword;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SectionHeader(title: 'Conta'),
        TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Nome'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: emailController,
          decoration: const InputDecoration(labelText: 'E-mail'),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton(
              onPressed: saving ? null : onSave,
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar conta'),
            ),
            OutlinedButton(
              onPressed: onChangePassword,
              child: const Text('Trocar senha'),
            ),
            TextButton.icon(
              onPressed: onLogout,
              icon: Icon(
                Icons.logout,
                size: 18,
                color: theme.colorScheme.error,
              ),
              label: Text(
                'Sair',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({
    required this.isDark,
    required this.onChanged,
    required this.themePreset,
    required this.onThemePresetChanged,
    required this.navLayout,
    required this.onNavLayoutChanged,
    required this.particlesEnabled,
    required this.onParticlesEnabledChanged,
    required this.particleCount,
    required this.onParticleCountChanged,
    required this.particleSpeed,
    required this.onParticleSpeedChanged,
    required this.particleLineDistance,
    required this.onParticleLineDistanceChanged,
    required this.particlesInteractive,
    required this.onParticlesInteractiveChanged,
    required this.saving,
    required this.onSave,
  });

  final bool isDark;
  final ValueChanged<bool> onChanged;
  final ThemePreset themePreset;
  final ValueChanged<ThemePreset> onThemePresetChanged;
  final NavLayout navLayout;
  final ValueChanged<NavLayout> onNavLayoutChanged;
  final bool particlesEnabled;
  final ValueChanged<bool> onParticlesEnabledChanged;
  final int particleCount;
  final ValueChanged<int> onParticleCountChanged;
  final double particleSpeed;
  final ValueChanged<double> onParticleSpeedChanged;
  final double particleLineDistance;
  final ValueChanged<double> onParticleLineDistanceChanged;
  final bool particlesInteractive;
  final ValueChanged<bool> onParticlesInteractiveChanged;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SectionHeader(title: 'Aparência'),
        _SettingRow(
          label: 'Tema',
          description: themePreset == ThemePreset.flown
              ? 'Escolha entre modo claro e escuro'
              : 'Fixo em "${themePreset.label}" — escolha "Padrão Flown" na paleta abaixo pra liberar claro/escuro',
          control: IgnorePointer(
            ignoring: themePreset != ThemePreset.flown,
            child: Opacity(
              opacity: themePreset == ThemePreset.flown ? 1 : 0.4,
              child: _ThemeSegmentedControl(isDark: isDark, onChanged: onChanged),
            ),
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            'Paleta',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          'Cada paleta tem visual próprio e fixo, independente do modo claro/escuro',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _ThemePresetPicker(
          selected: themePreset,
          onSelected: onThemePresetChanged,
        ),
        const Divider(),
        _SettingRow(
          label: 'Navegação',
          description: 'Menu lateral (recolhível, cobre celular) ou a barra superior original',
          control: _NavLayoutSegmentedControl(layout: navLayout, onChanged: onNavLayoutChanged),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            'Partículas do Modo Foco',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          'Fundo animado e interativo da tela de foco',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        _SettingRow(
          label: 'Ativar partículas',
          description: 'Mostra o fundo animado no Modo Foco',
          control: Switch(
            value: particlesEnabled,
            onChanged: onParticlesEnabledChanged,
          ),
        ),
        if (particlesEnabled) ...[
          const Divider(),
          _SettingRow(
            label: 'Reagir ao mouse',
            description: 'Partículas perto do cursor se destacam e se atraem',
            control: Switch(
              value: particlesInteractive,
              onChanged: onParticlesInteractiveChanged,
            ),
          ),
          const Divider(),
          _SliderSettingRow(
            label: 'Quantidade de partículas',
            valueLabel: '$particleCount',
            value: particleCount.toDouble(),
            min: 10,
            max: 300,
            divisions: 29,
            onChanged: (v) => onParticleCountChanged(v.round()),
          ),
          _SliderSettingRow(
            label: 'Velocidade',
            valueLabel: particleSpeed.toStringAsFixed(1),
            value: particleSpeed,
            min: 0.1,
            max: 3.0,
            divisions: 29,
            onChanged: onParticleSpeedChanged,
          ),
          _SliderSettingRow(
            label: 'Distância de conexão',
            valueLabel: '${particleLineDistance.round()}px',
            value: particleLineDistance,
            min: 40,
            max: 250,
            divisions: 21,
            onChanged: onParticleLineDistanceChanged,
          ),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: saving ? null : onSave,
            child: saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvar alterações'),
          ),
        ),
      ],
    );
  }
}

class _SliderSettingRow extends StatelessWidget {
  const _SliderSettingRow({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              Text(
                valueLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Duração dos ciclos do modo Pomodoro do Modo Foco (`focus_screen.dart`).
class _FocusModeSection extends StatelessWidget {
  const _FocusModeSection({
    required this.pomodoroFocusMinutes,
    required this.onPomodoroFocusMinutesChanged,
    required this.pomodoroShortBreakMinutes,
    required this.onPomodoroShortBreakMinutesChanged,
    required this.pomodoroLongBreakMinutes,
    required this.onPomodoroLongBreakMinutesChanged,
    required this.pomodoroCyclesBeforeLongBreak,
    required this.onPomodoroCyclesBeforeLongBreakChanged,
    required this.saving,
    required this.onSave,
  });

  final int pomodoroFocusMinutes;
  final ValueChanged<int> onPomodoroFocusMinutesChanged;
  final int pomodoroShortBreakMinutes;
  final ValueChanged<int> onPomodoroShortBreakMinutesChanged;
  final int pomodoroLongBreakMinutes;
  final ValueChanged<int> onPomodoroLongBreakMinutesChanged;
  final int pomodoroCyclesBeforeLongBreak;
  final ValueChanged<int> onPomodoroCyclesBeforeLongBreakChanged;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SectionHeader(title: 'Modo Foco'),
        Text(
          'Duração dos ciclos do modo Pomodoro',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        _SliderSettingRow(
          label: 'Foco',
          valueLabel: '${pomodoroFocusMinutes}min',
          value: pomodoroFocusMinutes.toDouble(),
          min: 5,
          max: 60,
          divisions: 55,
          onChanged: (v) => onPomodoroFocusMinutesChanged(v.round()),
        ),
        _SliderSettingRow(
          label: 'Pausa curta',
          valueLabel: '${pomodoroShortBreakMinutes}min',
          value: pomodoroShortBreakMinutes.toDouble(),
          min: 1,
          max: 30,
          divisions: 29,
          onChanged: (v) => onPomodoroShortBreakMinutesChanged(v.round()),
        ),
        _SliderSettingRow(
          label: 'Pausa longa',
          valueLabel: '${pomodoroLongBreakMinutes}min',
          value: pomodoroLongBreakMinutes.toDouble(),
          min: 5,
          max: 60,
          divisions: 55,
          onChanged: (v) => onPomodoroLongBreakMinutesChanged(v.round()),
        ),
        _SliderSettingRow(
          label: 'Ciclos até a pausa longa',
          valueLabel: '$pomodoroCyclesBeforeLongBreak',
          value: pomodoroCyclesBeforeLongBreak.toDouble(),
          min: 2,
          max: 8,
          divisions: 6,
          onChanged: (v) =>
              onPomodoroCyclesBeforeLongBreakChanged(v.round()),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: saving ? null : onSave,
            child: saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvar alterações'),
          ),
        ),
      ],
    );
  }
}

class _TaskPrefsSection extends StatelessWidget {
  const _TaskPrefsSection({
    required this.defaultPriority,
    required this.onDefaultPriorityChanged,
    required this.defaultStatus,
    required this.onDefaultStatusChanged,
    required this.showCompletedTasks,
    required this.onShowCompletedTasksChanged,
    required this.autoArchiveDone,
    required this.onAutoArchiveDoneChanged,
    required this.saving,
    required this.onSave,
  });

  final TaskPriority defaultPriority;
  final ValueChanged<TaskPriority> onDefaultPriorityChanged;
  final String defaultStatus;
  final ValueChanged<String> onDefaultStatusChanged;
  final bool showCompletedTasks;
  final ValueChanged<bool> onShowCompletedTasksChanged;
  final bool autoArchiveDone;
  final ValueChanged<bool> onAutoArchiveDoneChanged;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SectionHeader(title: 'Preferências de Tarefas'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<TaskPriority>(
                initialValue: defaultPriority,
                decoration: const InputDecoration(
                  labelText: 'Prioridade padrão',
                ),
                items: [
                  for (final p in TaskPriority.values)
                    DropdownMenuItem(
                      value: p,
                      child: Text(PriorityBadge.labels[p]!),
                    ),
                ],
                onChanged: (v) =>
                    onDefaultPriorityChanged(v ?? TaskPriority.medium),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: defaultStatus,
                decoration: const InputDecoration(labelText: 'Status padrão'),
                items: const [
                  DropdownMenuItem(value: 'backlog', child: Text('Backlog')),
                  DropdownMenuItem(value: 'todo', child: Text('A fazer')),
                  DropdownMenuItem(
                    value: 'in_progress',
                    child: Text('Em andamento'),
                  ),
                ],
                onChanged: (v) => onDefaultStatusChanged(v ?? 'todo'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _SettingRow(
          label: 'Exibir tarefas concluídas',
          description: 'Mostra tarefas com status "Concluído" na listagem',
          control: Switch(
            value: showCompletedTasks,
            onChanged: onShowCompletedTasksChanged,
          ),
        ),
        const Divider(),
        _SettingRow(
          label: 'Arquivar concluídas automaticamente',
          description: 'Move tarefas concluídas para o arquivo após 7 dias',
          control: Switch(
            value: autoArchiveDone,
            onChanged: onAutoArchiveDoneChanged,
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: saving ? null : onSave,
            child: saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvar alterações'),
          ),
        ),
      ],
    );
  }
}

class _NotePrefsSection extends StatelessWidget {
  const _NotePrefsSection({
    required this.defaultNoteView,
    required this.onDefaultNoteViewChanged,
    required this.autoSaveNotes,
    required this.onAutoSaveNotesChanged,
    required this.showNotePreview,
    required this.onShowNotePreviewChanged,
    required this.saving,
    required this.onSave,
  });

  final String defaultNoteView;
  final ValueChanged<String> onDefaultNoteViewChanged;
  final bool autoSaveNotes;
  final ValueChanged<bool> onAutoSaveNotesChanged;
  final bool showNotePreview;
  final ValueChanged<bool> onShowNotePreviewChanged;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SectionHeader(title: 'Preferências de Anotações'),
        DropdownButtonFormField<String>(
          initialValue: defaultNoteView,
          decoration: const InputDecoration(labelText: 'Visualização padrão'),
          items: const [
            DropdownMenuItem(value: 'grid', child: Text('Grade')),
            DropdownMenuItem(value: 'list', child: Text('Lista')),
          ],
          onChanged: (v) => onDefaultNoteViewChanged(v ?? 'grid'),
        ),
        const SizedBox(height: 8),
        _SettingRow(
          label: 'Salvar automaticamente',
          description: 'Salva anotações enquanto você digita',
          control: Switch(
            value: autoSaveNotes,
            onChanged: onAutoSaveNotesChanged,
          ),
        ),
        const Divider(),
        _SettingRow(
          label: 'Exibir prévia das anotações',
          description: 'Mostra os primeiros caracteres do conteúdo no card',
          control: Switch(
            value: showNotePreview,
            onChanged: onShowNotePreviewChanged,
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: saving ? null : onSave,
            child: saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvar alterações'),
          ),
        ),
      ],
    );
  }
}

class _NotificationsSection extends StatelessWidget {
  const _NotificationsSection({
    required this.notifyDueDate,
    required this.onNotifyDueDateChanged,
    required this.notifyOverdue,
    required this.onNotifyOverdueChanged,
    required this.notifyStatusChange,
    required this.onNotifyStatusChangeChanged,
    required this.notifyReminder,
    required this.onNotifyReminderChanged,
    required this.saving,
    required this.onSave,
  });

  final bool notifyDueDate;
  final ValueChanged<bool> onNotifyDueDateChanged;
  final bool notifyOverdue;
  final ValueChanged<bool> onNotifyOverdueChanged;
  final bool notifyStatusChange;
  final ValueChanged<bool> onNotifyStatusChangeChanged;
  final bool notifyReminder;
  final ValueChanged<bool> onNotifyReminderChanged;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SectionHeader(title: 'Notificações'),
        _SettingRow(
          label: 'Prazo se aproximando',
          description: 'Notifica quando uma tarefa estiver prestes a vencer',
          control: Switch(
            value: notifyDueDate,
            onChanged: onNotifyDueDateChanged,
          ),
        ),
        const Divider(),
        _SettingRow(
          label: 'Tarefas atrasadas',
          description: 'Notifica sobre tarefas com prazo vencido',
          control: Switch(
            value: notifyOverdue,
            onChanged: onNotifyOverdueChanged,
          ),
        ),
        const Divider(),
        _SettingRow(
          label: 'Alteração de status',
          description: 'Notifica quando o status de uma tarefa for alterado',
          control: Switch(
            value: notifyStatusChange,
            onChanged: onNotifyStatusChangeChanged,
          ),
        ),
        const Divider(),
        _SettingRow(
          label: 'Lembretes diários',
          description: 'Envia um resumo das tarefas do dia pela manhã',
          control: Switch(
            value: notifyReminder,
            onChanged: onNotifyReminderChanged,
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: saving ? null : onSave,
            child: saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvar alterações'),
          ),
        ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SectionHeader(title: 'Informações do Aplicativo'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: _InfoItem(label: 'Versão', value: '1.0.0-beta'),
            ),
            Expanded(
              child: _InfoItem(
                label: 'Ambiente',
                value: kDebugMode ? 'Desenvolvimento' : 'Produção',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: _InfoItem(
                label: 'Última atualização',
                value: 'Julho de 2026',
              ),
            ),
            Expanded(
              child: _InfoItem(
                label: 'Tema ativo',
                value: isDark ? 'Escuro' : 'Claro',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ThemePresetPicker extends StatelessWidget {
  const _ThemePresetPicker({required this.selected, required this.onSelected});

  final ThemePreset selected;
  final ValueChanged<ThemePreset> onSelected;

  @override
  Widget build(BuildContext context) {
    final lightPresets = ThemePreset.values.where((p) => p.isLight);
    final darkPresets = ThemePreset.values.where((p) => p.isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ThemePresetCard(
          preset: ThemePreset.flown,
          selected: selected == ThemePreset.flown,
          onTap: () => onSelected(ThemePreset.flown),
        ),
        const SizedBox(height: 16),
        _ThemePresetGroup(
          label: 'Claro',
          presets: lightPresets,
          selected: selected,
          onSelected: onSelected,
        ),
        const SizedBox(height: 16),
        _ThemePresetGroup(
          label: 'Escuro',
          presets: darkPresets,
          selected: selected,
          onSelected: onSelected,
        ),
      ],
    );
  }
}

class _ThemePresetGroup extends StatelessWidget {
  const _ThemePresetGroup({
    required this.label,
    required this.presets,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final Iterable<ThemePreset> presets;
  final ThemePreset selected;
  final ValueChanged<ThemePreset> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final preset in presets)
              _ThemePresetCard(
                preset: preset,
                selected: preset == selected,
                onTap: () => onSelected(preset),
              ),
          ],
        ),
      ],
    );
  }
}

class _ThemePresetCard extends StatelessWidget {
  const _ThemePresetCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final ThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final swatch = preset.swatch;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 128,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                for (final color in swatch)
                  Expanded(
                    child: Container(height: 20, color: color),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    preset.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, size: 16, color: colorScheme.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavLayoutSegmentedControl extends StatelessWidget {
  const _NavLayoutSegmentedControl({required this.layout, required this.onChanged});

  final NavLayout layout;
  final ValueChanged<NavLayout> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ThemeOption(
            icon: Icons.view_sidebar_outlined,
            label: 'Lateral',
            selected: layout == NavLayout.sidebar,
            onTap: () => onChanged(NavLayout.sidebar),
          ),
          _ThemeOption(
            icon: Icons.view_headline,
            label: 'Superior',
            selected: layout == NavLayout.topBar,
            onTap: () => onChanged(NavLayout.topBar),
          ),
        ],
      ),
    );
  }
}

class _ThemeSegmentedControl extends StatelessWidget {
  const _ThemeSegmentedControl({required this.isDark, required this.onChanged});

  final bool isDark;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ThemeOption(
            icon: Icons.wb_sunny_outlined,
            label: 'Claro',
            selected: !isDark,
            onTap: () => onChanged(false),
          ),
          _ThemeOption(
            icon: Icons.nightlight_outlined,
            label: 'Escuro',
            selected: isDark,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: selected
          ? theme.cardTheme.color ?? colorScheme.surface
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      elevation: selected ? 1 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.description,
    required this.control,
  });

  final String label;
  final String description;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          control,
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}
