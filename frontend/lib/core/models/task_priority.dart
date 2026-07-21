import 'package:json_annotation/json_annotation.dart';

/// Espelha o enum `Priority` do Prisma (`Low | Medium | High`). Ao contrario
/// de `Task.status` (String livre, validado dinamicamente contra
/// `ProjectType.availableStatus` — ver log 02/03 do backend), prioridade e
/// um enum de verdade dos dois lados, entao vale a pena tipar como enum aqui
/// tambem em vez de String solta.
@JsonEnum(valueField: 'wireValue')
enum TaskPriority {
  low('Low'),
  medium('Medium'),
  high('High');

  const TaskPriority(this.wireValue);

  /// Valor exato que a API espera/devolve.
  final String wireValue;
}
