import 'package:flutter/material.dart';

// --- OYUN KİMLİKLERİ ---
const String ID_LEADERBOARD = 'CgkI0JfKtagIEAIQAw';
const String ID_PERFECT_KING = 'CgkI0JfKtagIEAIQAA';
const String ID_NIGHT_OWL = 'CgkI0JfKtagIEAIQAQ';
const String ID_CLOUD_BUILDER = 'CgkI0JfKtagIEAIQAg';

// --- ADMOB ID'LERİ ---
const String PRODUCTION_INTERSTITIAL = 'ca-app-pub-3944855115101715/2814132766';
const String PRODUCTION_REWARDED = 'ca-app-pub-3944855115101715/1355796961';

enum GameState { menu, playing, gameOver }

// --- OYUN AYARLARI (ZORLUK VE DENGELER) ---
class GameConfig {
  // Blok Toleransları (Daha Kolay Ayarlar)
  static const double perfectTolerance = 8.0;     // 15.0 -> 8.0 (Perfect yapmak artık beceri ister!)
  static const double gameOverThreshold = 10.0;
  
  // Hız Ayarları (Daha Yavaş Zorlaşma)
  static const double initialSpeed = 140.0;
  static const double maxSpeed = 550.0;           // 650 -> 550 (Maksimum hız düşürüldü)
  static const double speedIncrement = 1.5;       // 3.0 -> 1.5 (Yarı yarıya daha yavaş hızlanma)
  
  // Rüzgar Ayarları (Daha Geç Başlama)
  static const double windStartScore = 40.0;      // 25 -> 40 (Rüzgar daha geç gelir)
  static const double windStrengthFactor = 1.2;   // 1.5 -> 1.2 (Rüzgar daha hafif eser)
  static const double maxWindStrength = 120.0;    // 150 -> 120
  
  // Görsel ve Boyut Ayarları
  static const double baseBlockWidth = 200.0;
  static const double blockHeight = 28.0;
  static const double blockYGap = 30.0;           
  static const double baseBlockYOffset = 80.0;    
  
  // Renkler
  static const Color perfectTextColor = Colors.amber;
  static const Color scoreTextColor = Colors.white;
  static const Color windTextColor = Colors.redAccent;
}
