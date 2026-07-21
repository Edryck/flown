import 'package:flutter/material.dart';

/// Mostrada so durante o boot, enquanto `AuthController.build()` tenta
/// restaurar uma sessao anterior (ver core/router/app_router.dart). Some
/// assim que a checagem resolve, nunca e navegavel manualmente.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
