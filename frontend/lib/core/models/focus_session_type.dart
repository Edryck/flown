import 'package:json_annotation/json_annotation.dart';

/// Espelha o enum `FocusSessionType` do Prisma (`pomodoro | stopwatch`).
@JsonEnum(valueField: 'wireValue')
enum FocusSessionKind {
  pomodoro('pomodoro'),
  stopwatch('stopwatch');

  const FocusSessionKind(this.wireValue);

  final String wireValue;
}
