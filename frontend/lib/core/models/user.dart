import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

/// Espelha `userResponseSchema` (backend/src/schemas/user.schema.ts).
/// `password` nunca vem do backend nessa resposta — nao existe campo aqui.
@freezed
class User with _$User {
  const factory User({
    required String id,
    required String name,
    required String email,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
