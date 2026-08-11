import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/task_priority.dart';

part 'settings_preferences.g.dart';

const _kDefaultPriority = 'settings.defaultPriority';
const _kDefaultStatus = 'settings.defaultStatus';
const _kShowCompletedTasks = 'settings.showCompletedTasks';
const _kAutoArchiveDone = 'settings.autoArchiveDone';
const _kDefaultNoteView = 'settings.defaultNoteView';
const _kAutoSaveNotes = 'settings.autoSaveNotes';
const _kShowNotePreview = 'settings.showNotePreview';
const _kNotifyDueDate = 'settings.notifyDueDate';
const _kNotifyOverdue = 'settings.notifyOverdue';
const _kNotifyStatusChange = 'settings.notifyStatusChange';
const _kNotifyReminder = 'settings.notifyReminder';
const _kParticlesEnabled = 'settings.particlesEnabled';
const _kParticleCount = 'settings.particleCount';
const _kParticleSpeed = 'settings.particleSpeed';
const _kParticleLineDistance = 'settings.particleLineDistance';
const _kParticlesInteractive = 'settings.particlesInteractive';
const _kPomodoroFocusMinutes = 'settings.pomodoroFocusMinutes';
const _kPomodoroShortBreakMinutes = 'settings.pomodoroShortBreakMinutes';
const _kPomodoroLongBreakMinutes = 'settings.pomodoroLongBreakMinutes';
const _kPomodoroCyclesBeforeLongBreak = 'settings.pomodoroCyclesBeforeLongBreak';

/// Preferências de Settings.tsx (docs/prototype/screens/settings.md) que
/// não têm campo nenhum no backend real (`PATCH /users/me` só aceita
/// `name`/`email`) nem são lidas em nenhum outro lugar do app — no
/// protótipo são `useState` local que se perde ao recarregar a página.
///
/// Persistidas aqui via `shared_preferences` (equivalente ao `localStorage`
/// que o protótipo usaria se persistisse) — decisão tomada ao traduzir
/// Settings: o protótipo é só referência visual, a funcionalidade (inclusive
/// "Salvar alterações" salvando de verdade) deve ser real sempre que der,
/// mesmo sem endpoint dedicado no backend.
class SettingsPreferences {
  const SettingsPreferences({
    this.defaultPriority = TaskPriority.medium,
    this.defaultStatus = 'todo',
    this.showCompletedTasks = true,
    this.autoArchiveDone = false,
    this.defaultNoteView = 'grid',
    this.autoSaveNotes = true,
    this.showNotePreview = true,
    this.notifyDueDate = true,
    this.notifyOverdue = true,
    this.notifyStatusChange = false,
    this.notifyReminder = true,
    this.particlesEnabled = true,
    this.particleCount = 80,
    this.particleSpeed = 0.6,
    this.particleLineDistance = 120,
    this.particlesInteractive = true,
    this.pomodoroFocusMinutes = 25,
    this.pomodoroShortBreakMinutes = 5,
    this.pomodoroLongBreakMinutes = 15,
    this.pomodoroCyclesBeforeLongBreak = 4,
  });

  final TaskPriority defaultPriority;

  /// Só guardada/exibida — diferente de `defaultPriority`, não dá pra
  /// aplicar de verdade num novo `Task`: status válido depende do
  /// `ProjectType` do projeto escolhido, não existe um "status padrão"
  /// único e sempre válido (ver `task_form_dialog.dart`).
  final String defaultStatus;

  final bool showCompletedTasks;
  final bool autoArchiveDone;
  final String defaultNoteView;
  final bool autoSaveNotes;
  final bool showNotePreview;
  final bool notifyDueDate;
  final bool notifyOverdue;
  final bool notifyStatusChange;
  final bool notifyReminder;

  /// Configuração do fundo de partículas interativas do Modo Foco
  /// (`particles_network`, `ParticleNetwork` em `focus_screen.dart`) —
  /// ajustável no tópico "Aparência" das Configurações (sem referência no
  /// protótipo, que não tinha esse efeito).
  final bool particlesEnabled;
  final int particleCount;
  final double particleSpeed;
  final double particleLineDistance;

  /// Liga `touchActivation`/`hoverEffect` do `ParticleNetwork` — sem isso,
  /// as partículas só se movem sozinhas, sem reagir ao mouse/toque.
  final bool particlesInteractive;

  /// Duração dos ciclos do Modo Foco em modo Pomodoro (`focus_screen.dart`)
  /// — defaults clássicos da técnica (25min foco / 5min pausa curta / 15min
  /// pausa longa a cada 4 ciclos).
  final int pomodoroFocusMinutes;
  final int pomodoroShortBreakMinutes;
  final int pomodoroLongBreakMinutes;
  final int pomodoroCyclesBeforeLongBreak;

  SettingsPreferences copyWith({
    TaskPriority? defaultPriority,
    String? defaultStatus,
    bool? showCompletedTasks,
    bool? autoArchiveDone,
    String? defaultNoteView,
    bool? autoSaveNotes,
    bool? showNotePreview,
    bool? notifyDueDate,
    bool? notifyOverdue,
    bool? notifyStatusChange,
    bool? notifyReminder,
    bool? particlesEnabled,
    int? particleCount,
    double? particleSpeed,
    double? particleLineDistance,
    bool? particlesInteractive,
    int? pomodoroFocusMinutes,
    int? pomodoroShortBreakMinutes,
    int? pomodoroLongBreakMinutes,
    int? pomodoroCyclesBeforeLongBreak,
  }) {
    return SettingsPreferences(
      defaultPriority: defaultPriority ?? this.defaultPriority,
      defaultStatus: defaultStatus ?? this.defaultStatus,
      showCompletedTasks: showCompletedTasks ?? this.showCompletedTasks,
      autoArchiveDone: autoArchiveDone ?? this.autoArchiveDone,
      defaultNoteView: defaultNoteView ?? this.defaultNoteView,
      autoSaveNotes: autoSaveNotes ?? this.autoSaveNotes,
      showNotePreview: showNotePreview ?? this.showNotePreview,
      notifyDueDate: notifyDueDate ?? this.notifyDueDate,
      notifyOverdue: notifyOverdue ?? this.notifyOverdue,
      notifyStatusChange: notifyStatusChange ?? this.notifyStatusChange,
      notifyReminder: notifyReminder ?? this.notifyReminder,
      particlesEnabled: particlesEnabled ?? this.particlesEnabled,
      particleCount: particleCount ?? this.particleCount,
      particleSpeed: particleSpeed ?? this.particleSpeed,
      particleLineDistance: particleLineDistance ?? this.particleLineDistance,
      particlesInteractive: particlesInteractive ?? this.particlesInteractive,
      pomodoroFocusMinutes: pomodoroFocusMinutes ?? this.pomodoroFocusMinutes,
      pomodoroShortBreakMinutes:
          pomodoroShortBreakMinutes ?? this.pomodoroShortBreakMinutes,
      pomodoroLongBreakMinutes:
          pomodoroLongBreakMinutes ?? this.pomodoroLongBreakMinutes,
      pomodoroCyclesBeforeLongBreak:
          pomodoroCyclesBeforeLongBreak ?? this.pomodoroCyclesBeforeLongBreak,
    );
  }
}

@riverpod
class SettingsPreferencesController extends _$SettingsPreferencesController {
  @override
  FutureOr<SettingsPreferences> build() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsPreferences(
      defaultPriority:
          TaskPriority.values
              .where((p) => p.wireValue == prefs.getString(_kDefaultPriority))
              .firstOrNull ??
          TaskPriority.medium,
      defaultStatus: prefs.getString(_kDefaultStatus) ?? 'todo',
      showCompletedTasks: prefs.getBool(_kShowCompletedTasks) ?? true,
      autoArchiveDone: prefs.getBool(_kAutoArchiveDone) ?? false,
      defaultNoteView: prefs.getString(_kDefaultNoteView) ?? 'grid',
      autoSaveNotes: prefs.getBool(_kAutoSaveNotes) ?? true,
      showNotePreview: prefs.getBool(_kShowNotePreview) ?? true,
      notifyDueDate: prefs.getBool(_kNotifyDueDate) ?? true,
      notifyOverdue: prefs.getBool(_kNotifyOverdue) ?? true,
      notifyStatusChange: prefs.getBool(_kNotifyStatusChange) ?? false,
      notifyReminder: prefs.getBool(_kNotifyReminder) ?? true,
      particlesEnabled: prefs.getBool(_kParticlesEnabled) ?? true,
      particleCount: prefs.getInt(_kParticleCount) ?? 80,
      particleSpeed: prefs.getDouble(_kParticleSpeed) ?? 0.6,
      particleLineDistance: prefs.getDouble(_kParticleLineDistance) ?? 120,
      particlesInteractive: prefs.getBool(_kParticlesInteractive) ?? true,
      pomodoroFocusMinutes: prefs.getInt(_kPomodoroFocusMinutes) ?? 25,
      pomodoroShortBreakMinutes:
          prefs.getInt(_kPomodoroShortBreakMinutes) ?? 5,
      pomodoroLongBreakMinutes:
          prefs.getInt(_kPomodoroLongBreakMinutes) ?? 15,
      pomodoroCyclesBeforeLongBreak:
          prefs.getInt(_kPomodoroCyclesBeforeLongBreak) ?? 4,
    );
  }

  Future<void> save(SettingsPreferences prefs) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kDefaultPriority, prefs.defaultPriority.wireValue);
    await sp.setString(_kDefaultStatus, prefs.defaultStatus);
    await sp.setBool(_kShowCompletedTasks, prefs.showCompletedTasks);
    await sp.setBool(_kAutoArchiveDone, prefs.autoArchiveDone);
    await sp.setString(_kDefaultNoteView, prefs.defaultNoteView);
    await sp.setBool(_kAutoSaveNotes, prefs.autoSaveNotes);
    await sp.setBool(_kShowNotePreview, prefs.showNotePreview);
    await sp.setBool(_kParticlesEnabled, prefs.particlesEnabled);
    await sp.setInt(_kParticleCount, prefs.particleCount);
    await sp.setDouble(_kParticleSpeed, prefs.particleSpeed);
    await sp.setDouble(_kParticleLineDistance, prefs.particleLineDistance);
    await sp.setBool(_kParticlesInteractive, prefs.particlesInteractive);
    await sp.setBool(_kNotifyDueDate, prefs.notifyDueDate);
    await sp.setBool(_kNotifyOverdue, prefs.notifyOverdue);
    await sp.setBool(_kNotifyStatusChange, prefs.notifyStatusChange);
    await sp.setBool(_kNotifyReminder, prefs.notifyReminder);
    await sp.setInt(_kPomodoroFocusMinutes, prefs.pomodoroFocusMinutes);
    await sp.setInt(
      _kPomodoroShortBreakMinutes,
      prefs.pomodoroShortBreakMinutes,
    );
    await sp.setInt(
      _kPomodoroLongBreakMinutes,
      prefs.pomodoroLongBreakMinutes,
    );
    await sp.setInt(
      _kPomodoroCyclesBeforeLongBreak,
      prefs.pomodoroCyclesBeforeLongBreak,
    );
    state = AsyncData(prefs);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
