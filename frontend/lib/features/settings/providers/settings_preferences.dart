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
    );
  }
}

@riverpod
class SettingsPreferencesController extends _$SettingsPreferencesController {
  @override
  FutureOr<SettingsPreferences> build() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsPreferences(
      defaultPriority: TaskPriority.values
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
    await sp.setBool(_kNotifyDueDate, prefs.notifyDueDate);
    await sp.setBool(_kNotifyOverdue, prefs.notifyOverdue);
    await sp.setBool(_kNotifyStatusChange, prefs.notifyStatusChange);
    await sp.setBool(_kNotifyReminder, prefs.notifyReminder);
    state = AsyncData(prefs);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
