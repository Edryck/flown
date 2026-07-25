import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:particles_network/particles_network.dart';

import '../../../core/models/checklist_item.dart';
import '../../../core/models/focus_session_type.dart';
import '../../../core/models/project.dart';
import '../../../core/models/task.dart';
import '../../../core/models/task_priority.dart';
import '../../../core/widgets/badge_size.dart';
import '../../../core/widgets/priority_badge.dart';
import '../../projects/providers/project_list_controller.dart';
import '../../settings/providers/settings_preferences.dart';
import '../../tasks/providers/task_list_controller.dart';
import '../../tasks/providers/task_repository.dart';
import '../providers/focus_session_repository.dart';

/// Tela de foco imersiva em tela cheia — tradução fiel de FocusMode.tsx
/// (docs/prototype/screens/focus-mode.md): cronômetro crescente (não é
/// Pomodoro, mesmo a dica de rodapé mencionar 25/5 minutos — isso é só
/// texto estático no protótipo também), task em foco escolhida
/// automaticamente, card com progresso/checklist, fundo escuro fixo (não
/// muda com o tema do app, por design).
///
/// Diferenças deliberadas do protótipo (decididas antes de traduzir):
///   - o cronômetro persiste de verdade: ao parar/sair/pular/concluir com
///     tempo acumulado, grava uma `FocusSession` real (`POST /sessions`,
///     `type: stopwatch`) — o protótipo zera tudo ao recarregar a página;
///   - Checklist, "Concluir Tarefa" e "Próxima Tarefa" funcionam de
///     verdade (eram só visuais/sem handler no protótipo);
///   - a task em foco continua escolhida automaticamente (sem seletor
///     manual), igual ao protótipo.
///
/// A regra de seleção usa o literal `'In Progress'` pra achar a task "em
/// andamento" — os dois `ProjectType` seedados (`software`/`general`) usam
/// exatamente essa string, mas é uma convenção, não uma garantia geral (um
/// `ProjectType` customizado poderia nomear o status de outro jeito) —
/// mesmo tipo de atalho que o backend já assume pra `COMPLETED_STATUS`
/// ("Done", `task.service.ts`).
///
/// Fundo com partículas interativas (`particles_network`, sem referência no
/// protótipo — pedido à parte do usuário), configurável em Configurações →
/// Aparência (`SettingsPreferences.particles*`). Pra reagir ao mouse só
/// quando ele está sobre o fundo (fora do cartão/timer/botões, não em cima
/// deles) sem precisar de nenhum truque manual: o `ParticleNetwork` fica
/// atrás, em `Positioned.fill`, e o conteúdo interativo fica num `Align` +
/// `ConstrainedBox(maxWidth: 720)` (não `Positioned.fill` direto no
/// `SingleChildScrollView` como antes) — como `Align`/`ConstrainedBox` não
/// têm gesture detector próprio, só a faixa central de 720px (onde o
/// `Scrollable` realmente ocupa) intercepta o hit-test; as margens laterais
/// (em telas largas) deixam o hover passar direto pro `ParticleNetwork`
/// por baixo. Descrito em detalhe porque não é o padrão óbvio — um
/// `Positioned.fill` direto no `SingleChildScrollView` (como era antes)
/// bloqueia o hover na tela inteira, já que o `Scrollable` interno usa
/// `HitTestBehavior.opaque` pra permitir arrastar/rolar mesmo a partir de
/// área "vazia".
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  static const _inProgressStatus = 'In Progress';
  static const _doneStatus = 'Done';

  Timer? _timer;
  bool _isRunning = false;
  int _elapsedSeconds = 0;
  DateTime? _sessionStartedAt;
  final Set<String> _skippedTaskIds = {};
  bool _busy = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Task? _pickFocusTask(List<Task> tasks) {
    var candidates = tasks
        .where(
          (t) =>
              t.status == _inProgressStatus && !_skippedTaskIds.contains(t.id),
        )
        .toList();
    if (candidates.isEmpty && _skippedTaskIds.isNotEmpty) {
      // Já pulou todas — dá a volta e considera todas de novo.
      candidates = tasks.where((t) => t.status == _inProgressStatus).toList();
    }
    if (candidates.isEmpty) return null;
    for (final task in candidates) {
      if (task.priority == TaskPriority.high) return task;
    }
    return candidates.first;
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _toggleRunning() {
    setState(() {
      _isRunning = !_isRunning;
      if (_isRunning) {
        _sessionStartedAt ??= DateTime.now();
        _timer = Timer.periodic(
          const Duration(seconds: 1),
          (_) => setState(() => _elapsedSeconds++),
        );
      } else {
        _timer?.cancel();
      }
    });
  }

  /// Grava a `FocusSession` acumulada (se houver) e zera o cronômetro local.
  Future<void> _flushSession(String? taskId) async {
    _timer?.cancel();
    final startedAt = _sessionStartedAt;
    final elapsed = _elapsedSeconds;
    setState(() {
      _isRunning = false;
      _elapsedSeconds = 0;
      _sessionStartedAt = null;
    });
    if (startedAt == null || elapsed <= 0) return;

    try {
      await ref
          .read(focusSessionRepositoryProvider)
          .create(
            type: FocusSessionKind.stopwatch,
            durationSeconds: elapsed,
            startedAt: startedAt,
            completedAt: DateTime.now(),
            taskId: taskId,
          );
    } catch (_) {
      // Sessão de foco é um registro auxiliar — falha ao salvar não deve
      // travar navegação, troca de task nem conclusão.
    }
  }

  Future<void> _reset() => _flushSession(null);

  Future<void> _skip(Task task) async {
    await _flushSession(task.id);
    setState(() => _skippedTaskIds.add(task.id));
  }

  Future<void> _complete(Task task) async {
    setState(() => _busy = true);
    await _flushSession(task.id);
    try {
      await ref
          .read(taskListControllerProvider.notifier)
          .updateTask(task.id, const TaskInput(status: _doneStatus));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao concluir tarefa: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exit(Task? task) async {
    await _flushSession(task?.id);
    if (mounted) context.go('/dashboard');
  }

  void _toggleChecklistItem(Task task, int index, bool done) {
    final updated = [
      for (var i = 0; i < task.checklist.length; i++)
        i == index
            ? ChecklistItem(text: task.checklist[i].text, done: done)
            : task.checklist[i],
    ];
    // Recalcula `progress` junto — mesma lógica de `TaskFormDialog`
    // (`_resolveProgress`). Sem isso, marcar um item aqui atualizava só o
    // checklist e a barra de progresso do card ficava com o valor antigo.
    final progress =
        ((updated.where((c) => c.done).length / updated.length) * 100).round();
    ref
        .read(taskListControllerProvider.notifier)
        .updateTask(task.id, TaskInput(checklist: updated, progress: progress));
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(taskListControllerProvider);
    final projectsAsync = ref.watch(projectListControllerProvider);
    final projects = projectsAsync.valueOrNull ?? const <Project>[];
    final projectNamesById = <String, String>{
      for (final p in projects) p.id: p.name,
    };
    final prefs = ref.watch(settingsPreferencesControllerProvider).valueOrNull;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2D3D4A), Color(0xFF1A2633)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: tasksAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white70),
          ),
          error: (error, _) => Center(
            child: Text(
              'Erro ao carregar tarefas: $error',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          data: (tasks) {
            final focusTask = _pickFocusTask(tasks);

            // Fundo de partículas antes do `if`/`else` de propósito — igual
            // com nenhuma task "In Progress" (estado vazio), a tela continua
            // imersiva; o efeito não pode desaparecer só porque não há
            // task em foco no momento.
            final particlesLayer = (prefs?.particlesEnabled ?? true)
                ? Positioned.fill(
                    child: ParticleNetwork(
                      particleCount: prefs?.particleCount ?? 80,
                      maxSpeed: prefs?.particleSpeed ?? 0.6,
                      lineDistance: prefs?.particleLineDistance ?? 120,
                      particleColor: Colors.white.withValues(alpha: 0.6),
                      lineColor: const Color(0xFF4A9E99),
                      touchColor: const Color(0xFF7BA3C7),
                      touchActivation: prefs?.particlesInteractive ?? true,
                      hoverEffect: prefs?.particlesInteractive ?? true,
                    ),
                  )
                : null;

            if (focusTask == null) {
              return Stack(
                children: [
                  ?particlesLayer,
                  Positioned.fill(
                    child: _EmptyFocusState(
                      onGoToTasks: () => context.go('/tasks'),
                    ),
                  ),
                ],
              );
            }

            return Stack(
              children: [
                ?particlesLayer,
                // `Positioned.fill` de propósito: filho não-posicionado de
                // `Stack` não preenche o Stack inteiro por padrão (só
                // alinha no canto superior-esquerdo, `topStart`) — sem
                // isso, `Align` não teria a área cheia da tela pra
                // centralizar contra. Ver doc da classe pra por que
                // `Align`/`ConstrainedBox` (não `Center` direto no
                // `SingleChildScrollView`) — é o que permite o hover
                // vazar pro `ParticleNetwork` nas margens.
                //
                // Fica ANTES do botão X de propósito: `Stack` testa/pinta
                // os filhos na ordem da lista (o último fica por cima) —
                // com o `Positioned.fill` depois do X, o scroll view
                // cobria a mesma área e roubava o clique do botão.
                Positioned.fill(
                  child: Align(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 64,
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF4A9E99,
                                ).withValues(alpha: 0.2),
                                border: Border.all(
                                  color: const Color(
                                    0xFF4A9E99,
                                  ).withValues(alpha: 0.3),
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const _PulsingDot(
                                    color: Color(0xFF4A9E99),
                                    size: 8,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Modo Foco Ativo',
                                    style: TextStyle(
                                      color: Color(0xFFD4EEEC),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 48),
                            Text(
                              _formatTime(_elapsedSeconds),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 64,
                                fontWeight: FontWeight.w300,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 150,
                                  child: _isRunning
                                      ? OutlinedButton.icon(
                                          onPressed: _toggleRunning,
                                          icon: const Icon(
                                            Icons.pause,
                                            size: 20,
                                          ),
                                          label: const Text('Pausa'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            side: const BorderSide(
                                              color: Colors.white38,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                          ),
                                        )
                                      : FilledButton.icon(
                                          onPressed: _toggleRunning,
                                          icon: const Icon(
                                            Icons.play_arrow,
                                            size: 20,
                                          ),
                                          label: const Text('Iniciar'),
                                          style: FilledButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 16),
                                OutlinedButton(
                                  onPressed: _reset,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: Colors.white38,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 20,
                                    ),
                                  ),
                                  child: const Text('Redefinir'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 48),
                            _FocusTaskCard(
                              task: focusTask,
                              projectName: focusTask.projectId == null
                                  ? null
                                  : projectNamesById[focusTask.projectId],
                              onToggleChecklistItem: (index, done) =>
                                  _toggleChecklistItem(focusTask, index, done),
                            ),
                            const SizedBox(height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => _skip(focusTask),
                                  icon: const Icon(Icons.skip_next, size: 18),
                                  label: const Text('Próxima Tarefa'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: Colors.white38,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                FilledButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => _complete(focusTask),
                                  icon: const Icon(
                                    Icons.check_circle_outline,
                                    size: 18,
                                  ),
                                  label: const Text('Concluir Tarefa'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF6BB88F),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Faça uma pausa de 5 minutos a cada 25 minutos para manter o foco e a produtividade',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 24,
                  right: 24,
                  child: IconButton(
                    onPressed: () => _exit(focusTask),
                    icon: const Icon(Icons.close, color: Colors.white70),
                    tooltip: 'Sair do Modo Foco',
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FocusTaskCard extends StatelessWidget {
  const _FocusTaskCard({
    required this.task,
    required this.projectName,
    required this.onToggleChecklistItem,
  });

  final Task task;
  final String? projectName;
  final void Function(int index, bool done) onToggleChecklistItem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final checklist = task.checklist;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(task.title, style: theme.textTheme.headlineSmall),
              ),
              const SizedBox(width: 12),
              PriorityBadge(priority: task.priority, size: BadgeSize.md),
            ],
          ),
          if ((task.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              task.description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 20),
          // `width: double.infinity` de propósito — sem isso, o Container
          // encolhe pra largura dos 3 itens (o Column pai usa
          // crossAxisAlignment.start), então a linha divisória e a fileira
          // de metadados paravam no meio do card em vez de ocupar a
          // largura toda. `Row` + `spaceBetween` (em vez de `Wrap`) espalha
          // os itens pela largura disponível, não só empilha à esquerda.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (projectName != null)
                  _MetaItem(label: 'Projeto', value: projectName!),
                if (task.dueDate != null)
                  _MetaItem(
                    label: 'Vencimento',
                    value: DateFormat('dd/MM/yyyy').format(task.dueDate!),
                  ),
                if ((task.estimatedTime ?? '').isNotEmpty)
                  _MetaItem(label: 'Estimado', value: task.estimatedTime!),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Progresso Geral',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              ),
              Text(
                '${task.progress ?? 0}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (task.progress ?? 0) / 100,
              minHeight: 10,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
          if (checklist.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Lista de Verificação',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < checklist.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onToggleChecklistItem(i, !checklist[i].done),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.6,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: checklist[i].done,
                          onChanged: (value) =>
                              onToggleChecklistItem(i, value ?? false),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            checklist[i].text,
                            style: checklist[i].done
                                ? TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: colorScheme.onSurfaceVariant,
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${checklist.where((c) => c.done).length} de ${checklist.length} concluído',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFocusState extends StatelessWidget {
  const _EmptyFocusState({required this.onGoToTasks});

  final VoidCallback onGoToTasks;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 40,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Nenhuma Tarefa Ativa',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Selecione uma tarefa da sua lista de tarefas para entrar em Modo Foco',
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onGoToTasks,
            child: const Text('Ir para Tarefas'),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.3).animate(_controller),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
