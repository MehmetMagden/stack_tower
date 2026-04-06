import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'package:flame_audio/flame_audio.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:games_services/games_services.dart';
import 'package:flutter/services.dart';

// --- GOOGLE PLAY SERVICES ID'LERI ---
const String ID_LEADERBOARD = 'CgkI0JfKtagIEAIQAw';
const String ID_PERFECT_KING = 'CgkI0JfKtagIEAIQAA';
const String ID_NIGHT_OWL = 'CgkI0JfKtagIEAIQAQ';
const String ID_CLOUD_BUILDER = 'CgkI0JfKtagIEAIQAg';

// ─────────────────────────────────────────────
// AdMob ID'LERİ  ← PRODUCTION (gerçek hesap)
// ─────────────────────────────────────────────
// const String _kBannerAdId =
//     'ca-app-pub-3944855115101715/6952688320'; // Banner

// const String _kInterstitialAdId =
//     'ca-app-pub-3944855115101715/2814132766'; // Interstitial

// const String _kRewardedAdId =
//     'ca-app-pub-3944855115101715/1355796961'; // Rewarded

// App ID:     ca-app-pub-3944855115101715~9379541113
// Ad Unit ID: ca-app-pub-3944855115101715/1355796961
// ─────────────────────────────────────────────
// AdMob ID'LERİ
// ─────────────────────────────────────────────
// TEST modunda çalışırken bu ID'leri kullan.
// Release APK/AAB yaparken gerçek ID'lerle değiştir.
const String _kBannerAdId = 'ca-app-pub-3940256099942544/6300978111'; // TEST
const String _kInterstitialAdId =
    'ca-app-pub-3940256099942544/1033173712'; // TEST
const String _kRewardedAdId =
    'ca-app-pub-3940256099942544/5224354917'; // TEST — Rewarded Video

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await MobileAds.instance.initialize().timeout(
    const Duration(seconds: 5),
    onTimeout: () {
      debugPrint('⚠️ AdMob init timeout — devam ediliyor');
      return InitializationStatus({});
    },
  );

  try {
    await GamesServices.signIn();
    debugPrint('✅ PGS Giriş Başarılı');
  } catch (e) {
    debugPrint('❌ PGS Giriş Yapılamadı: $e');
  }

  runApp(const StackTowerApp());
}

class StackTowerApp extends StatefulWidget {
  const StackTowerApp({super.key});
  @override
  State<StackTowerApp> createState() => _StackTowerAppState();
}

class _StackTowerAppState extends State<StackTowerApp> {
  late BannerAd _bannerAd;
  bool _isBannerAdReady = false;
  final StackTowerGame _game = StackTowerGame();

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _kBannerAdId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerAdReady = true),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          setState(() => _isBannerAdReady = false);
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: Stack(
          children: [
            GameWidget(
              game: _game,
              overlayBuilderMap: {
                'mainMenu': (_, game) =>
                    MenuOverlay(game: game as StackTowerGame),
                'gameOver': (_, game) =>
                    GameOverOverlay(game: game as StackTowerGame),
              },
            ),
            if (_isBannerAdReady)
              Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: _bannerAd.size.height.toDouble(),
                  width: double.infinity,
                  child: AdWidget(ad: _bannerAd),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum GameState { menu, playing, gameOver }

class StackTowerGame extends FlameGame with TapCallbacks {
  final _random = math.Random();
  late SpriteComponent _bgLevel1, _bgLevel2, _bgLevel3;

  int _bgLevel = 0;

  GameState gameState = GameState.menu;
  late MovingBlock currentBlock;
  MovingBlock? previousBlock;
  int score = 0;
  int highScore = 0;
  int comboCount = 0;

  late TextComponent scoreText, comboText, heightText, windText;
  final List<MovingBlock> _placedBlocks = [];
  double _pendingScroll = 0.0;
  double windStrength = 0.0;
  bool windActive = false;

  // ─────────────────────────────────────────────
  // REWARDED VIDEO — Durum değişkenleri
  // ─────────────────────────────────────────────
  RewardedAd? _rewardedAd;
  bool _isRewardedAdReady = false;

  // Kullanıcı başına tek devam hakkı (her oyun için 1 kez)
  bool _continueUsed = false;

  // ─────────────────────────────────────────────
  InterstitialAd? _interstitialAd;
  int _gameOverCount = 0;

  final List<Color> blockColors = [
    Colors.tealAccent,
    Colors.pinkAccent,
    Colors.amberAccent,
    Colors.lightBlueAccent,
    Colors.purpleAccent,
  ];

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.center;

    _bgLevel1 = SpriteComponent(
      sprite: await loadSprite('bg_level1.png'),
      size: size,
    );
    _bgLevel2 = SpriteComponent(
      sprite: await loadSprite('bg_level2.png'),
      size: size,
    )..opacity = 0.0;
    _bgLevel3 = SpriteComponent(
      sprite: await loadSprite('bg_level3.png'),
      size: size,
    )..opacity = 0.0;
    addAll([_bgLevel1, _bgLevel2, _bgLevel3]);

    _setupUI();

    final prefs = await SharedPreferences.getInstance();
    highScore = prefs.getInt('highScore') ?? 0;

    _loadInterstitialAd();
    _loadRewardedAd(); // ← Rewarded video yüklemeye başla
    _setupBaseBlock();
    _spawnBlock();

    overlays.add('mainMenu');
    pauseEngine();

    await FlameAudio.audioCache.loadAll([
      'place.mp3',
      'perfect.mp3',
      'game_over.mp3',
      'backGroundMusic.mp3',
    ]);
  }

  // ─────────────────────────────────────────────
  // REWARDED AD — Yükleme
  // ─────────────────────────────────────────────
  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _kRewardedAdId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdReady = true;
          debugPrint('✅ Rewarded Ad hazır');

          // Reklam kapandığında: dispose + yeniden yükle
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              _isRewardedAdReady = false;
              _loadRewardedAd(); // Bir sonraki için önceden yükle
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('❌ Rewarded gösterilemedi: $error');
              ad.dispose();
              _rewardedAd = null;
              _isRewardedAdReady = false;
              _loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ Rewarded yüklenemedi: $error');
          _isRewardedAdReady = false;
          // 30 saniye sonra tekrar dene
          Future.delayed(const Duration(seconds: 30), _loadRewardedAd);
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // REWARDED AD — Gösterme (Game Over overlay'den çağrılır)
  // ─────────────────────────────────────────────
  void showRewardedAdAndContinue() {
    if (!_isRewardedAdReady || _rewardedAd == null) {
      debugPrint('⚠️ Rewarded ad henüz hazır değil');
      return;
    }

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        // ── Ödül kazanıldı: devam et ──
        debugPrint('🏆 Ödül kazanıldı: ${reward.amount} ${reward.type}');
        _continueGame();
      },
    );
  }

  // ─────────────────────────────────────────────
  // DEVAM ETMEKLİĞİ — Skoru sıfırlamadan oyunu sürdür
  // ─────────────────────────────────────────────
  void _continueGame() {
    _continueUsed = true;

    // Game Over overlay'i kapat
    overlays.remove('gameOver');

    // Mevcut bloğu kaldır (düşmüş blok)
    currentBlock.removeFromParent();

    // Yeni blok spawn et — aynı yerden devam
    _spawnBlock();

    // Motoru tekrar başlat
    gameState = GameState.playing;
    resumeEngine();

    // BGM devam etsin
    try {
      FlameAudio.bgm.play('backGroundMusic.mp3', volume: 0.3);
    } catch (_) {}
  }

  void _setupUI() {
    scoreText = TextComponent(
      text: '0',
      position: Vector2(size.x / 2, 80),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 60,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    comboText = TextComponent(
      text: '',
      position: Vector2(size.x / 2, 140),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.orangeAccent,
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    heightText = TextComponent(
      text: '0m',
      position: Vector2(20, 40),
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.white70, fontSize: 18),
      ),
    );
    windText = TextComponent(
      text: '',
      position: Vector2(size.x - 20, 40),
      anchor: Anchor.topRight,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.redAccent,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    camera.viewport.addAll([scoreText, comboText, heightText, windText]);
  }

  void _setupBaseBlock() {
    final base = MovingBlock(
      yPosition: size.y - 150,
      blockWidth: 200,
      blockColor: blockColors[0],
      startX: size.x / 2 - 100,
      speed: 0,
    )..moving = false;
    add(base);
    _placedBlocks.add(base);
    previousBlock = base;
  }

  void _spawnBlock() {
    double speed = (150 + score * 5).clamp(150, 500).toDouble();
    currentBlock = MovingBlock(
      yPosition: previousBlock!.position.y - 30,
      blockWidth: previousBlock!.size.x,
      blockColor: blockColors[(score + 1) % blockColors.length],
      startX: _random.nextBool() ? 0 : size.x - previousBlock!.size.x,
      speed: speed,
    );
    add(currentBlock);

    if (score >= 10 && score % 3 == 0) {
      windActive = true;
      windStrength = (_random.nextDouble() - 0.5) * (50 + score);
      windText.text = windStrength > 0 ? '💨 WIND >>' : '<< WIND 💨';
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_pendingScroll > 0) {
      double step = 400 * dt;
      if (step > _pendingScroll) step = _pendingScroll;
      _pendingScroll -= step;
      for (var b in _placedBlocks) b.position.y += step;
      currentBlock.position.y += step;
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (gameState != GameState.playing || !currentBlock.moving) return;
    currentBlock.moving = false;
    _checkOverlap();
  }

  void _checkOverlap() async {
    final overlapLeft = math.max(
      currentBlock.position.x,
      previousBlock!.position.x,
    );
    final overlapRight = math.min(
      currentBlock.position.x + currentBlock.size.x,
      previousBlock!.position.x + previousBlock!.size.x,
    );
    final overlapWidth = overlapRight - overlapLeft;

    if (overlapWidth <= 0) {
      _gameOver();
      return;
    }

    bool isPerfect =
        (currentBlock.position.x - previousBlock!.position.x).abs() < 7;
    if (isPerfect) {
      currentBlock.position.x = previousBlock!.position.x;
      currentBlock.size.x = previousBlock!.size.x;
      comboCount++;
      score += (1 + comboCount);
      FlameAudio.play('perfect.mp3');
      comboText.text = 'PERFECT X$comboCount';
      HapticFeedback.mediumImpact();

      if (comboCount >= 10) {
        try {
          await GamesServices.unlock(
            achievement: Achievement(androidID: ID_PERFECT_KING),
          );
        } catch (_) {}
      }
    } else {
      currentBlock.position.x = overlapLeft;
      currentBlock.size.x = overlapWidth;
      comboCount = 0;
      score++;
      comboText.text = '';
      FlameAudio.play('place.mp3');
      HapticFeedback.lightImpact();
    }

    scoreText.text = '$score';
    heightText.text = '${score * 3}m';
    _updateBackground(score * 3);

    _placedBlocks.add(currentBlock);
    previousBlock = currentBlock;
    if (currentBlock.position.y < size.y * 0.45) _pendingScroll += 30;
    _spawnBlock();
  }

  void _updateBackground(int height) {
    if (height >= 100 && height < 300 && _bgLevel < 1) {
      _bgLevel = 1;
      _bgLevel1.add(OpacityEffect.to(0.2, EffectController(duration: 1)));
      _bgLevel2.add(OpacityEffect.to(0.8, EffectController(duration: 1)));
    } else if (height >= 300 && _bgLevel < 2) {
      _bgLevel = 2;
      _bgLevel2.add(OpacityEffect.to(0.1, EffectController(duration: 1)));
      _bgLevel3.add(OpacityEffect.to(1.0, EffectController(duration: 1)));
    }
  }

  void _gameOver() async {
    gameState = GameState.gameOver;

    try {
      FlameAudio.bgm.stop();
    } catch (_) {}
    FlameAudio.play('game_over.mp3');
    HapticFeedback.vibrate();

    // PGS: Skor Gönderimi
    try {
      await GamesServices.submitScore(
        score: Score(androidLeaderboardID: ID_LEADERBOARD, value: score),
      );
      await GamesServices.increment(
        achievement: Achievement(androidID: ID_CLOUD_BUILDER, steps: score),
      );
    } catch (_) {}

    // PGS: Night Owl
    final hour = DateTime.now().hour;
    if (hour >= 0 && hour <= 5) {
      try {
        await GamesServices.unlock(
          achievement: Achievement(androidID: ID_NIGHT_OWL),
        );
      } catch (_) {}
    }

    if (score > highScore) {
      highScore = score;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('highScore', highScore);
    }

    _showInterstitialIfReady();
    overlays.add('gameOver');
    pauseEngine();
  }

  void restartGame() {
    // Devam hakkını sıfırla — yeni oyun başlıyor
    _continueUsed = false;

    score = 0;
    comboCount = 0;
    _pendingScroll = 0;
    _bgLevel = 0;
    windActive = false;
    windStrength = 0.0;

    scoreText.text = '0';
    heightText.text = '0m';
    comboText.text = '';
    windText.text = '';

    _bgLevel1.children.whereType<Effect>().toList().forEach(
      (e) => e.removeFromParent(),
    );
    _bgLevel2.children.whereType<Effect>().toList().forEach(
      (e) => e.removeFromParent(),
    );
    _bgLevel3.children.whereType<Effect>().toList().forEach(
      (e) => e.removeFromParent(),
    );
    _bgLevel1.opacity = 1.0;
    _bgLevel2.opacity = 0.0;
    _bgLevel3.opacity = 0.0;

    removeAll(_placedBlocks);
    _placedBlocks.clear();
    currentBlock.removeFromParent();
    _setupBaseBlock();
    _spawnBlock();

    gameState = GameState.playing;
    resumeEngine();

    try {
      FlameAudio.bgm.play('backGroundMusic.mp3', volume: 0.3);
    } catch (_) {}
  }

  Future<void> showLeaderboardUI() async {
    try {
      await GamesServices.showLeaderboards(
        androidLeaderboardID: ID_LEADERBOARD,
      );
    } catch (e) {
      debugPrint('Liderlik tablosu hatası: $e');
    }
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _kInterstitialAdId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadInterstitialAd();
              if (gameState == GameState.playing) resumeEngine();
            },
          );
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  void _showInterstitialIfReady() {
    _gameOverCount++;
    if (_gameOverCount % 3 == 0 && _interstitialAd != null) {
      _interstitialAd!.show();
    }
  }

  // ─────────────────────────────────────────────
  // DIŞARIDAN ERIŞIM — GameOverOverlay için getter'lar
  // ─────────────────────────────────────────────

  /// Rewarded ad hazır mı? (Overlay butonu buna göre etkinleşir)
  bool get isRewardedAdReady => _isRewardedAdReady;

  /// Bu oyunda devam hakkı kullanıldı mı? (Sadece 1 kez kullanılabilir)
  bool get continueUsed => _continueUsed;
}

// ─────────────────────────────────────────────
// MovingBlock
// ─────────────────────────────────────────────
class MovingBlock extends RectangleComponent
    with HasGameReference<StackTowerGame> {
  double speed;
  int direction = 1;
  bool moving = true;

  MovingBlock({
    required double yPosition,
    required double blockWidth,
    required Color blockColor,
    required double startX,
    required this.speed,
  }) : super(
         position: Vector2(startX, yPosition),
         size: Vector2(blockWidth, 30),
         paint: Paint()..color = blockColor,
       );

  @override
  void update(double dt) {
    super.update(dt);
    if (!moving) return;
    if (game.windActive) position.x += game.windStrength * dt;
    position.x += speed * direction * dt;
    if (position.x + size.x >= game.size.x || position.x <= 0) {
      direction *= -1;
      position.x = position.x.clamp(0, game.size.x - size.x);
    }
  }
}

// ─────────────────────────────────────────────
// MENU OVERLAY
// ─────────────────────────────────────────────
class MenuOverlay extends StatelessWidget {
  final StackTowerGame game;
  const MenuOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1a1a2e),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'STACK TOWER',
              style: TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                game.overlays.remove('mainMenu');
                game.restartGame();
              },
              child: const Text('START GAME'),
            ),
            IconButton(
              icon: const Icon(
                Icons.leaderboard,
                color: Colors.white,
                size: 40,
              ),
              onPressed: () => game.showLeaderboardUI(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// GAME OVER OVERLAY — Rewarded "Devam Et" butonu dahil
// ─────────────────────────────────────────────
class GameOverOverlay extends StatefulWidget {
  final StackTowerGame game;
  const GameOverOverlay({super.key, required this.game});

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay> {
  bool _adLoading = false; // Butona basıldıktan sonra yükleniyor göstergesi

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final isNewRecord = game.score >= game.highScore && game.score > 0;

    // Devam butonu gösterilsin mi?
    // Koşul: bu oyunda henüz kullanılmadıysa VE reklam hazırsa
    final bool showContinueButton =
        !game.continueUsed && game.isRewardedAdReady;

    // Reklam hazır değilse ama henüz kullanılmadıysa — "Yükleniyor" göster
    final bool showLoadingButton =
        !game.continueUsed && !game.isRewardedAdReady;

    return Center(
      child: Container(
        padding: const EdgeInsets.all(30),
        margin: const EdgeInsets.symmetric(horizontal: 32),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.redAccent, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── GAME OVER başlığı ──
            const Text(
              'GAME OVER',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            // ── Skor ──
            Text(
              'Score: ${game.score}',
              style: const TextStyle(color: Colors.white, fontSize: 28),
            ),

            const SizedBox(height: 6),

            // ── High Score / Yeni Rekoru ──
            if (isNewRecord)
              const Text(
                '🏆 NEW RECORD!',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              Text(
                'Best: ${game.highScore}',
                style: const TextStyle(color: Colors.white54, fontSize: 16),
              ),

            const SizedBox(height: 24),

            // ─────────────────────────────────────────────
            // DEVAM ET BUTONU — Rewarded Video izle
            // ─────────────────────────────────────────────
            if (showContinueButton)
              _ContinueButton(
                loading: _adLoading,
                onPressed: () {
                  setState(() => _adLoading = true);
                  game.showRewardedAdAndContinue();
                  // Reklam kapandıktan sonra overlay zaten kaldırılıyor;
                  // butonun tekrar aktif olmasına gerek yok.
                },
              )
            else if (showLoadingButton)
              // Reklam henüz yüklenmedi — soluk buton göster
              Opacity(
                opacity: 0.45,
                child: _ContinueButton(loading: true, onPressed: null),
              ),

            const SizedBox(height: 12),

            // ── RETRY (Sıfırdan Başla) ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  game.overlays.remove('gameOver');
                  game.restartGame();
                },
                child: const Text(
                  'RETRY',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── Liderlik tablosu ──
            TextButton.icon(
              icon: const Icon(Icons.emoji_events, color: Colors.amber),
              label: const Text(
                'WORLD RANKINGS',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () => game.showLeaderboardUI(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DEVAM ET BUTONU — Ayrı widget (temiz kod)
// ─────────────────────────────────────────────
class _ContinueButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onPressed;

  const _ContinueButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(
            0xFF1DB954,
          ), // Spotify yeşili — dikkat çekici
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.play_circle_filled, size: 22),
        label: Text(
          loading ? 'Yükleniyor...' : '▶  Videoyu İzle — Devam Et',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        onPressed: onPressed,
      ),
    );
  }
}
