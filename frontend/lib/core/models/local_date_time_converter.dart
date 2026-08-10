import 'package:freezed_annotation/freezed_annotation.dart';

/// Sem isso, `DateTime.parse` de um ISO UTC do backend (ex.:
/// "2026-08-08T02:59:00.000Z") fica com `isUtc = true`, e qualquer leitura
/// direta de `.year`/`.day`/`.hour` (telas, formulário de edição, DateFormat)
/// pega os componentes em UTC em vez dos componentes locais — só o instante
/// fica certo, a "hora de parede" exibida fica errada (ex.: 23:59 de
/// 07/08 em Brasília aparecendo como 08/08 02:59). Aplicar `.toLocal()` uma
/// única vez aqui, no parse, evita que cada tela precise lembrar de
/// converter antes de ler os campos.
class LocalDateTimeConverter implements JsonConverter<DateTime, String> {
  const LocalDateTimeConverter();

  @override
  DateTime fromJson(String json) => DateTime.parse(json).toLocal();

  @override
  String toJson(DateTime object) => object.toUtc().toIso8601String();
}

/// Mesma conversão de [LocalDateTimeConverter] para campos `DateTime?`.
class NullableLocalDateTimeConverter
    implements JsonConverter<DateTime?, String?> {
  const NullableLocalDateTimeConverter();

  @override
  DateTime? fromJson(String? json) =>
      json == null ? null : DateTime.parse(json).toLocal();

  @override
  String? toJson(DateTime? object) => object?.toUtc().toIso8601String();
}
