import 'package:flutter/material.dart';
import '../game/stack_tower_game.dart';

class MenuOverlay extends StatelessWidget {
  final StackTowerGame game;
  const MenuOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent, 
    body: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, 
          end: Alignment.bottomCenter, 
          colors: [Colors.black.withOpacity(0.2), Colors.black.withOpacity(0.7)]
        )
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: [
            SizedBox(
              width: double.infinity, 
              child: Text(
                'STACK\nTOWER', 
                textAlign: TextAlign.center, 
                style: TextStyle(
                  color: Colors.amber.shade400, 
                  fontSize: 65, 
                  height: 0.9, 
                  fontWeight: FontWeight.w900, 
                  shadows: const [Shadow(blurRadius: 30, color: Colors.black, offset: Offset(5, 5))]
                )
              )
            ),
            const SizedBox(height: 60),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent, 
                foregroundColor: Colors.black, 
                padding: const EdgeInsets.symmetric(horizontal: 70, vertical: 25), 
                textStyle: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold), 
                elevation: 20
              ), 
              onPressed: () { 
                game.overlays.remove('mainMenu'); 
                game.restartGame(); 
              }, 
              child: const Text('START GAME')
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => game.showLeaderboardUI(), 
              icon: const Icon(Icons.emoji_events, color: Colors.amber, size: 30), 
              label: const Text('WORLD RANKINGS', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))
            ),
          ]
        )
      ),
    ),
  );
}
