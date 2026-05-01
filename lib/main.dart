import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/stack_tower_game.dart';
import 'overlays/menu_overlay.dart';
import 'overlays/game_over_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Reklamları ve SharedPreferences'ı aynı anda başlatıyoruz
  final initAds = MobileAds.instance.initialize().then((_) {
    RequestConfiguration configuration = RequestConfiguration(
      testDeviceIds: ["YOUR_HASHED_DEVICE_ID_HERE"],
    );
    MobileAds.instance.updateRequestConfiguration(configuration);
  });
  
  final prefsFuture = SharedPreferences.getInstance();

  // Sadece SharedPreferences'ın bitmesini bekliyoruz, reklamlar arkada dolmaya devam eder
  final prefs = await prefsFuture;
  
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: GameWidget(
      game: StackTowerGame(prefs: prefs),
      overlayBuilderMap: {
        'mainMenu': (ctx, game) => MenuOverlay(game: game as StackTowerGame),
        'gameOver': (ctx, game) => GameOverOverlay(game: game as StackTowerGame),
      },
    ),
  ));
}
