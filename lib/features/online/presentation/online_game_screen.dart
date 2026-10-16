import 'package:flutter/material.dart';

import '../../../app/theme/app_type.dart';

/// The online game (checkpoint 3 replaces this placeholder).
class OnlineGameScreen extends StatelessWidget {
  const OnlineGameScreen({super.key, required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Online game')),
      body: Center(child: Text('Game $gameId', style: AppType.body)),
    );
  }
}
