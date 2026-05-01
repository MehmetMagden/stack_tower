import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../game/stack_tower_game.dart';

class GameOverOverlay extends StatelessWidget {
  final StackTowerGame game;
  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black54, 
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          const Text(
            'GAME OVER', 
            style: TextStyle(color: Colors.redAccent, fontSize: 50, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 10, color: Colors.black)])
          ),
          Text(
            'SCORE: ${game.score}', 
            style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w300)
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center, 
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15), 
                  backgroundColor: Colors.white10
                ), 
                onPressed: () { 
                  game.overlays.remove('gameOver'); 
                  game.restartGame(); 
                }, 
                child: const Text('RETRY', style: TextStyle(fontSize: 22, color: Colors.white))
              ),
              const SizedBox(width: 15),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), 
                  backgroundColor: Colors.amber.shade700
                ), 
                onPressed: () => game.showLeaderboardUI(), 
                child: const Icon(Icons.emoji_events, color: Colors.white, size: 30)
              ),
            ]
          ),
          const SizedBox(height: 20),
          if (game.canContinue) 
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber, 
                foregroundColor: Colors.black, 
                padding: const EdgeInsets.all(20)
              ), 
              onPressed: () {
                if (game.rewardedAd != null) { 
                  game.rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
                    onAdDismissedFullScreenContent: (ad) { 
                      game.continueGame(); 
                      ad.dispose(); 
                      game.loadAds(); 
                    }
                  ); 
                  game.rewardedAd!.show(onUserEarnedReward: (_, __) => debugPrint('Reward Granted')); 
                } 
                else { 
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ad not ready yet!'))); 
                  game.loadAds(); 
                }
              }, 
              child: const Row(
                mainAxisSize: MainAxisSize.min, 
                children: [
                  Icon(Icons.play_circle_fill, size: 30), 
                  SizedBox(width: 15), 
                  Text('CONTINUE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))
                ]
              )
            ),
        ]
      )
    ),
  );
}
