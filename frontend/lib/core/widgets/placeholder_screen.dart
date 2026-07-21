import 'package:flutter/material.dart';

/// Tela provisoria — cada feature troca isso pela implementacao de verdade
/// quando chegar a vez dela (auth -> users -> project-types -> projects ->
/// tasks -> notes -> sessions -> dashboard -> search -> trash, mesma ordem
/// do backend).
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          '$title — em construcao',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
