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
  // Blok Toleransları
  static const double perfectTolerance = 12.0;    // "Perfect" sayılması için gereken max sapma
  static const double gameOverThreshold = 15.0;   // Minimum tutunma genişliği (altında düşer)
  
  // Hız Ayarları
  static const double initialSpeed = 140.0;
  static const double maxSpeed = 650.0;
  static const double speedIncrement = 3.0;       // Skor başına hız artışı
  
  // Rüzgar Ayarları
  static const double windStartScore = 25.0;
  static const double windStrengthFactor = 1.5;
  static const double maxWindStrength = 150.0;    // Rüzgarın ulaşabileceği max güç
  
  // Görsel ve Boyut Ayarları
  static const double baseBlockWidth = 200.0;
  static const double blockHeight = 28.0;
  static const double blockYGap = 30.0;           // Bloklar arası dikey mesafe
  static const double baseBlockYOffset = 80.0;    // Alttan yükseklik
  
  // Renkler
  static const Color perfectTextColor = Colors.amber;
  static const Color scoreTextColor = Colors.white;
  static const Color windTextColor = Colors.redAccent;
}
