import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_call.dart';
import '../../../core/api/api_client.dart';

part 'dashboard_stats_repository.g.dart';

/// Espelha a resposta de `GET /dashboard/stats`
/// (`backend/src/services/dashboard.service.ts`) — não tem schema Joi de
/// resposta formal (a rota devolve o objeto cru do service), então o
/// parsing aqui é manual em vez de gerado, mesmo padrão usado só pra
/// exibição (sem round-trip de escrita).
class DashboardStats {
  const DashboardStats({
    required this.windowDays,
    required this.productivity,
    required this.focus,
    required this.projectHealth,
  });

  final int windowDays;
  final ProductivityStats productivity;
  final FocusStats focus;
  final ProjectHealthStats projectHealth;

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
    windowDays: json['windowDays'] as int,
    productivity: ProductivityStats.fromJson(
      json['productivity'] as Map<String, dynamic>,
    ),
    focus: FocusStats.fromJson(json['focus'] as Map<String, dynamic>),
    projectHealth: ProjectHealthStats.fromJson(
      json['projectHealth'] as Map<String, dynamic>,
    ),
  );
}

class HeatmapEntry {
  const HeatmapEntry({required this.date, required this.count});

  final DateTime date;
  final int count;

  factory HeatmapEntry.fromJson(Map<String, dynamic> json) => HeatmapEntry(
    date: DateTime.parse(json['date'] as String),
    count: json['count'] as int,
  );
}

class CompletionRate {
  const CompletionRate({
    required this.created,
    required this.completed,
    required this.rate,
  });

  final int created;
  final int completed;

  /// 0..1 (não é porcentagem ainda).
  final double rate;

  factory CompletionRate.fromJson(Map<String, dynamic> json) => CompletionRate(
    created: json['created'] as int,
    completed: json['completed'] as int,
    rate: (json['rate'] as num).toDouble(),
  );
}

class ProductivityStats {
  const ProductivityStats({
    required this.heatmap,
    required this.completionRate,
    required this.averageTimeToCompleteByPriority,
  });

  final List<HeatmapEntry> heatmap;
  final CompletionRate completionRate;

  /// Horas médias até concluir, por prioridade (`Low`/`Medium`/`High`) —
  /// `null` quando não há nenhuma task concluída daquela prioridade.
  final Map<String, double?> averageTimeToCompleteByPriority;

  factory ProductivityStats.fromJson(Map<String, dynamic> json) =>
      ProductivityStats(
        heatmap: (json['heatmap'] as List<dynamic>)
            .map((e) => HeatmapEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        completionRate: CompletionRate.fromJson(
          json['completionRate'] as Map<String, dynamic>,
        ),
        averageTimeToCompleteByPriority:
            (json['averageTimeToCompleteByPriority'] as Map<String, dynamic>)
                .map(
                  (key, value) => MapEntry(key, (value as num?)?.toDouble()),
                ),
      );
}

class PeakHour {
  const PeakHour({required this.histogram, required this.peakHour});

  final List<int> histogram;
  final int? peakHour;

  factory PeakHour.fromJson(Map<String, dynamic> json) => PeakHour(
    histogram: (json['histogram'] as List<dynamic>)
        .map((e) => e as int)
        .toList(),
    peakHour: json['peakHour'] as int?,
  );
}

class FocusStats {
  const FocusStats({
    required this.streak,
    required this.peakHour,
    required this.todaySeconds,
    required this.todaySessionCount,
    required this.averageSessionSeconds,
  });

  final int streak;
  final PeakHour peakHour;

  /// Soma de `FocusSession.durationSeconds` de hoje (desde meia-noite).
  final int todaySeconds;
  final int todaySessionCount;

  /// `todaySeconds / todaySessionCount`, ou 0 se não houve sessão hoje.
  final double averageSessionSeconds;

  factory FocusStats.fromJson(Map<String, dynamic> json) => FocusStats(
    streak: json['streak'] as int,
    peakHour: PeakHour.fromJson(json['peakHour'] as Map<String, dynamic>),
    todaySeconds: json['todaySeconds'] as int,
    todaySessionCount: json['todaySessionCount'] as int,
    averageSessionSeconds: (json['averageSessionSeconds'] as num).toDouble(),
  );
}

class DueStatus {
  const DueStatus({
    required this.overdue,
    required this.onTrack,
    required this.completedOnTime,
    required this.completedLate,
  });

  final int overdue;
  final int onTrack;
  final int completedOnTime;
  final int completedLate;

  factory DueStatus.fromJson(Map<String, dynamic> json) => DueStatus(
    overdue: json['overdue'] as int,
    onTrack: json['onTrack'] as int,
    completedOnTime: json['completedOnTime'] as int,
    completedLate: json['completedLate'] as int,
  );
}

class TaskDistribution {
  const TaskDistribution({required this.byStatus, required this.byPriority});

  final Map<String, int> byStatus;
  final Map<String, int> byPriority;

  factory TaskDistribution.fromJson(Map<String, dynamic> json) =>
      TaskDistribution(
        byStatus: (json['byStatus'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, v as int),
        ),
        byPriority: (json['byPriority'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, v as int),
        ),
      );
}

class ProjectHealthStats {
  const ProjectHealthStats({
    required this.dueStatus,
    required this.distribution,
  });

  final DueStatus dueStatus;
  final TaskDistribution distribution;

  factory ProjectHealthStats.fromJson(Map<String, dynamic> json) =>
      ProjectHealthStats(
        dueStatus: DueStatus.fromJson(
          json['dueStatus'] as Map<String, dynamic>,
        ),
        distribution: TaskDistribution.fromJson(
          json['distribution'] as Map<String, dynamic>,
        ),
      );
}

class DashboardStatsRepository {
  DashboardStatsRepository(this._dio);

  final Dio _dio;

  Future<DashboardStats> getStats({int? days}) {
    return guardApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/dashboard/stats',
        queryParameters: days == null ? null : {'days': days},
      );
      return DashboardStats.fromJson(response.data!);
    });
  }
}

@riverpod
DashboardStatsRepository dashboardStatsRepository(
  DashboardStatsRepositoryRef ref,
) => DashboardStatsRepository(ref.watch(apiClientProvider));

@riverpod
Future<DashboardStats> dashboardStats(DashboardStatsRef ref) =>
    ref.watch(dashboardStatsRepositoryProvider).getStats();

/// Quantos dias se passaram desde 1º de janeiro do ano de [from] até [from],
/// inclusive — janela usada pro heatmap anual, que mostra o ano corrente
/// inteiro (1º de janeiro a 31 de dezembro), não um trailing window de 365
/// dias terminando hoje (isso fazia o heatmap "começar" no dia atual em vez
/// de janeiro, sem sentido fora de dezembro).
int daysSinceStartOfYear(DateTime from) {
  final startOfYear = DateTime(from.year, 1, 1);
  return DateTime(
        from.year,
        from.month,
        from.day,
      ).difference(startOfYear).inDays +
      1;
}

/// Busca separada (desde 1º de janeiro do ano corrente) só pro heatmap
/// anual (`CompletionHeatmap`) e pro gráfico mensal derivado dele — os
/// outros números da tela (taxa de conclusão, cards) continuam na janela
/// padrão de `dashboardStatsProvider` (90 dias, "desempenho recente").
@riverpod
Future<DashboardStats> annualDashboardStats(AnnualDashboardStatsRef ref) {
  final days = daysSinceStartOfYear(DateTime.now());
  return ref.watch(dashboardStatsRepositoryProvider).getStats(days: days);
}
