import 'package:freezed_annotation/freezed_annotation.dart';

import 'user.dart';

part 'auth_response.freezed.dart';
part 'auth_response.g.dart';

/// Espelha `authResponseSchema` — resposta de /auth/register e /auth/login.
@freezed
class AuthResponse with _$AuthResponse {
  const factory AuthResponse({
    required String accessToken,
    required String refreshToken,
    required User user,
  }) = _AuthResponse;

  factory AuthResponse.fromJson(Map<String, dynamic> json) => _$AuthResponseFromJson(json);
}

/// Espelha `refreshResponseSchema` — resposta de /auth/refresh.
@freezed
class RefreshResponse with _$RefreshResponse {
  const factory RefreshResponse({required String accessToken}) = _RefreshResponse;

  factory RefreshResponse.fromJson(Map<String, dynamic> json) => _$RefreshResponseFromJson(json);
}
