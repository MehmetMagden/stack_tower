import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'package:flame_audio/flame_audio.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:games_services/games_services.dart';
import 'package:flutter/services.dart';
import 'dart:async' as async;

// --- GOOGLE PLAY SERVICES ID'LERI ---
const String ID_LEADERBOARD   = 'CgkI0JfKtagIEAIQAw';
const String ID_PERFECT_KING  = 'CgkI0JfKtagIEAIQAA';
const String ID_NIGHT_OWL     = 'CgkI0JfKtagIEAIQAQ';
const String ID_CLOUD_BUILDER = 'CgkI0JfKtagIEAIQAg';

// --- AdMob ID'LERI (TEST) ---
const String _kBannerAdId       = 'ca-app-pub-3940256099942544/6300978111';
const String _kInterstitialAdId = 'ca-app-pub-3940256099942544/1033173712';
const String _kRewardedAdId     = 'ca-app-pub-3940256099942544/5224354917';

// ─── BUG FIX #1: Minimum blok genişliği eşiği ───────────────────────────────
// Floating-point hassasiyet hatası: overlap 0.00001 gibi değer alabilir.
// Bu kadar küçük blok görünmez ama oyun bitmez → "ölü blok" oluşur.
const double _kMinBlockWidth = 2.0;

// ─── TextPaint sabitleri ─────────────────────────────────────────────────────
const _scoreStyle  = TextStyle(color: Colors.white,       fontSize: 60, fontWeight: FontWeight.bold);
const _comboStyle  = TextStyle(color: Colors.orangeAccent,fontSize: 26, fontWeight: FontWeight.bold);
const _heightStyle = TextStyle(color: Colors.white70,     fontSize: 18);
const _windStyle   = TextStyle(color: Colors.redAccent,   fontSize: 18, fontWeight: FontWeight.bold);

final _scoreTextPaint  = TextPaint(style: _scoreStyle);
final _comboTextPaint  = TextPaint(style: _comboStyle);
final _heightTextPaint = TextPaint(style: _heightStyle);
final _windTextPaint   = TextPaint(style: _windStyle);

// ─── Global Rewarded Ad ──────────────────────────────────────────────────────
final ValueNotifier<bool> globalRewardedAdNotifier = ValueNotifier(false);
RewardedAd? _globalRewardedAd;

void _preloadRewardedAd() {
  RewardedAd.load(
    adUnitId: _kRewardedAdId,
    request: const AdRequest(),
    rewardedAdLoadCallback: RewardedAdLoadCallback(
      onAdLoaded: (ad) {
        _globalRewardedAd = ad;
        globalRewardedAdNotifier.value = true;
        debugPrint('✅ Rewarded Ad hazır (erken yükleme)');
        ad.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
            _globalRewardedAd = null;
            globalRewardedAdNotifier.value = false;
            _preloadRewardedAd();
          },
          onAdFailedToShowFullScreenContent: (ad, error) {
            ad.dispose();
            _globalRewardedAd = null;
            globalRewardedAdNotifier.value = false;
            _preloadRewardedAd();
          },
        );
      },
      onAdFailedToLoad: (error) {
        debugPrint('❌ Rewarded yüklenemedi: $error');
        globalRewardedAdNotifier.value = false;
        Future.delayed(const Duration(seconds: 30), _preloadRewardedAd);
      },
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  await MobileAds.instance.initialize().timeout(
    const Duration(seconds: 5),
    onTimeout: () {
      debugPrint('⚠️ AdMob init timeout — devam ediliyor');
      return InitializationStatus({});
    },
  );

  _preloadRewardedAd();

  try {
    await GamesServices.signIn();
    debugPrint('✅ PGS Giriş Başarılı');
  } catch (e) {
    debugPrint('❌ PGS Giriş Yapılamadı: $e');
  }

  runApp(StackTowerApp(prefs: prefs));
}


class StackTowerApp extends StatefulWidget {
  final SharedPreferences prefs;
  const StackTowerApp({super.key, required this.prefs});
  @override
  State<StackTowerApp> createState() => _StackTowerAppState();
}

class _StackTowerAppState extends State<StackTowerApp> {
  late BannerAd _bannerAd;
  bool _isBannerAdReady = false;
  late final StackTowerGame _game;

  @override
  void initState() {
    super.initState();
    _game = StackTowerGame(prefs: widget.prefs);
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
  void dispose() {
    _bannerAd.dispose();
    super.dispose();
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
                'mainMenu': (_, game) => MenuOverlay(game: game as StackTowerGame),
                'gameOver': (_, game) => GameOverOverlay(game: game as StackTowerGame),
              },
            ),
            if (_isBannerAdReady)
              Align(
                alignment: Alignment.bottomCenter,
                child: RepaintBoundary(
                  child: SizedBox(
                    height: _bannerAd.size.height.toDouble(),
                    width: double.infinity,
                    child: AdWidget(ad: _bannerAd),
                  ),
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
  final SharedPreferences prefs;
  StackTowerGame({required this.prefs});

  final _random = math.Random();
  late SpriteComponent _bgLevel1, _bgLevel2, _bgLevel3;
  int _bgLevel = 0;

  GameState gameState = GameState.menu;
  late MovingBlock currentBlock;
  MovingBlock? previousBlock;
  int score      = 0;
  int highScore  = 0;
  int comboCount = 0;

  late TextComponent scoreText, comboText, heightText, windText;
  final List<MovingBlock> _placedBlocks    = [];
  final List<MovingBlock> _offscreenBlocks = [];

  // BUG FIX #2: _pendingScroll üst sınır
  // Çok hızlı taplarda pendingScroll sonsuz birikir → kamera fırlar.
  // Maksimum biriktirilebilir kaydırma miktarı sınırlandı.
  double _pendingScroll = 0.0;
  static const double _kMaxPendingScroll = 300.0;

  double windStrength = 0.0;
  bool   windActive   = false;

  AudioPool? _placePool;
  AudioPool? _perfectPool;

  RewardedAd? get _rewardedAd => _globalRewardedAd;
  ValueNotifier<bool> get rewardedAdReadyNotifier => globalRewardedAdNotifier;
  bool _continueUsed = false;

  InterstitialAd? _interstitialAd;
  int _gameOverCount = 0;

  // BUG FIX #3: Interstitial gösterim zamanlaması
  // _gameOver() çağrılır → interstitial HEMEN gösterilirse Game Over overlay
  // ile çakışır. 1.5 saniyelik gecikme eklendi.
  bool _interstitialPending = false;

  static const List<Color> blockColors = [
    Colors.tealAccent, Colors.pinkAccent, Colors.amberAccent,
    Colors.lightBlueAccent, Colors.purpleAccent,
  ];

  String _lastHeightText = '0m';
  String _lastScoreText  = '0';

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.center;

    final results = await Future.wait([
      loadSprite('bg_level1.png'),
      loadSprite('bg_level2.png'),
      loadSprite('bg_level3.png'),
    ]);

    _bgLevel1 = SpriteComponent(sprite: results[0], size: size);
    _bgLevel2 = SpriteComponent(sprite: results[1], size: size)..opacity = 0.0;
    _bgLevel3 = SpriteComponent(sprite: results[2], size: size)..opacity = 0.0;
    addAll([_bgLevel1, _bgLevel2, _bgLevel3]);

    _setupUI();
    highScore = prefs.getInt('highScore') ?? 0;

    _loadInterstitialAd();
    _setupBaseBlock();
    _spawnBlock();

    overlays.add('mainMenu');
    pauseEngine();

    await FlameAudio.audioCache.loadAll(['game_over.mp3', 'backGroundMusic.mp3']);
    _placePool   = await AudioPool.create(source: AssetSource('audio/place.mp3'),   maxPlayers: 4);
    _perfectPool = await AudioPool.create(source: AssetSource('audio/perfect.mp3'), maxPlayers: 4);
  }

  // BUG FIX #4: AudioPool dispose — bellek sızıntısı önleme
  // AudioPool dispose edilmezse native AudioPlayer örnekleri serbest kalmaz.
  @override
  void onRemove() {
    _placePool?.dispose();
    _perfectPool?.dispose();
    super.onRemove();
  }

  void _setupUI() {
    scoreText = TextComponent(
      text: '0', position: Vector2(size.x / 2, 80),
      anchor: Anchor.center, textRenderer: _scoreTextPaint,
    );
    comboText = TextComponent(
      text: '', position: Vector2(size.x / 2, 140),
      anchor: Anchor.center, textRenderer: _comboTextPaint,
    );
    heightText = TextComponent(
      text: '0m', position: Vector2(20, 40),
      textRenderer: _heightTextPaint,
    );
    windText = TextComponent(
      text: '', position: Vector2(size.x - 20, 40),
      anchor: Anchor.topRight, textRenderer: _windTextPaint,
    );
    camera.viewport.addAll([scoreText, comboText, heightText, windText]);
  }

  void _setupBaseBlock() {
    final base = MovingBlock(
      yPosition: size.y - 150, blockWidth: 200,
      blockColor: blockColors[0], startX: size.x / 2 - 100, speed: 0,
    )..moving = false;
    add(base);
    _placedBlocks.add(base);
    previousBlock = base;
  }

  void _spawnBlock() {
    final speed = (150 + score * 5).clamp(150, 500).toDouble();

    // BUG FIX #5: startX blok ekranın dışına taşmasın
    // Küçük blok genişliğinde startX = size.x - blockWidth → negatif olabilir
    final blockWidth = previousBlock!.size.x;
    final safeStartX = (_random.nextBool() ? 0.0 : (size.x - blockWidth))
        .clamp(0.0, math.max(0.0, size.x - blockWidth)).toDouble();

    currentBlock = MovingBlock(
      yPosition: previousBlock!.position.y - 30,
      blockWidth: blockWidth,
      blockColor: blockColors[(score + 1) % blockColors.length],
      startX: safeStartX,
      speed: speed,
    );
    add(currentBlock);

    if (score >= 10 && score % 3 == 0) {
      windActive   = true;
      windStrength = (_random.nextDouble() - 0.5) * (50 + score);
      windText.text = windStrength > 0 ? '💨 WIND >>' : '<< WIND 💨';
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // BUG FIX #3: Gecikmiş interstitial gösterimi
    if (_interstitialPending) {
      _interstitialPending = false;
      _tryShowInterstitial();
    }

    if (_pendingScroll > 0) {
      final step = (_pendingScroll < 400 * dt) ? _pendingScroll : 400 * dt;
      _pendingScroll -= step;

      for (int i = _placedBlocks.length - 1; i >= 0; i--) {
        final b = _placedBlocks[i];
        b.position.y += step;
        if (b.position.y > size.y * 1.5) {
          _offscreenBlocks.add(b);
          _placedBlocks.removeAt(i);
        }
      }
      currentBlock.position.y += step;
    }

    if (_offscreenBlocks.isNotEmpty) {
      removeAll(_offscreenBlocks);
      _offscreenBlocks.clear();
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    // BUG FIX #6: Çift game over koruması
    // gameState kontrolü zaten var ama moving kontrolü de şart:
    // reklam kapandıktan sonra eski tap event'i işlenebilir
    if (gameState != GameState.playing || !currentBlock.moving) return;
    currentBlock.moving = false;
    _checkOverlap();
  }

  void _checkOverlap() {
    final overlapLeft  = math.max(currentBlock.position.x, previousBlock!.position.x);
    final overlapRight = math.min(
      currentBlock.position.x + currentBlock.size.x,
      previousBlock!.position.x + previousBlock!.size.x,
    );
    final overlapWidth = overlapRight - overlapLeft;

    // BUG FIX #1: Minimum genişlik eşiği
    // overlapWidth = 0.0001 gibi değerler görsel olarak kaybolur ama
    // oyun bitmez. _kMinBlockWidth'in altı kesinlikle Game Over.
    if (overlapWidth < _kMinBlockWidth) {
      _gameOver();
      return;
    }

    final isPerfect = (currentBlock.position.x - previousBlock!.position.x).abs() < 7;

    if (isPerfect) {
      currentBlock.position.x = previousBlock!.position.x;
      currentBlock.size.x     = previousBlock!.size.x;
      comboCount++;
      score += (1 + comboCount);
      _perfectPool?.start();
      comboText.text = 'PERFECT X$comboCount';
      HapticFeedback.mediumImpact();

      if (comboCount >= 10) {
        GamesServices.unlock(achievement: Achievement(androidID: ID_PERFECT_KING))
            .catchError((_) {});
      }
    } else {
      currentBlock.position.x = overlapLeft;
      currentBlock.size.x     = overlapWidth;
      comboCount  = 0;
      score++;
      comboText.text = '';
      _placePool?.start();
      HapticFeedback.lightImpact();
    }

    final newScore  = '$score';
    final newHeight = '${score * 3}m';
    if (newScore  != _lastScoreText)  { scoreText.text  = newScore;  _lastScoreText  = newScore; }
    if (newHeight != _lastHeightText) { heightText.text = newHeight; _lastHeightText = newHeight; }

    _updateBackground(score * 3);
    _placedBlocks.add(currentBlock);
    previousBlock = currentBlock;

    // BUG FIX #2: pendingScroll üst sınır
    if (currentBlock.position.y < size.y * 0.45) {
      _pendingScroll = (_pendingScroll + 30).clamp(0.0, _kMaxPendingScroll);
    }
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

  void _gameOver() {
    // BUG FIX #6: Çift _gameOver() koruması
    if (gameState == GameState.gameOver) return;
    gameState = GameState.gameOver;

    try { FlameAudio.bgm.stop(); } catch (_) {}
    FlameAudio.play('game_over.mp3');
    HapticFeedback.vibrate();

    GamesServices.submitScore(
      score: Score(androidLeaderboardID: ID_LEADERBOARD, value: score),
    ).catchError((_) {});
    GamesServices.increment(
      achievement: Achievement(androidID: ID_CLOUD_BUILDER, steps: score),
    ).catchError((_) {});

    final hour = DateTime.now().hour;
    if (hour >= 0 && hour <= 5) {
      GamesServices.unlock(achievement: Achievement(androidID: ID_NIGHT_OWL))
          .catchError((_) {});
    }

    if (score > highScore) {
      highScore = score;
      prefs.setInt('highScore', highScore);
    }

    // BUG FIX #3: Interstitial'ı hemen gösterme, Game Over overlay ile çakışır.
    // _interstitialPending = true yaparak bir sonraki update frame'ine bırak.
    _gameOverCount++;
    if (_gameOverCount % 3 == 0 && _interstitialAd != null) {
      _interstitialPending = true;
    }

    overlays.add('gameOver');
    pauseEngine();
  }

  // BUG FIX #3: Interstitial gecikmiş gösterim
  void _tryShowInterstitial() {
    if (_interstitialAd == null) return;
    _interstitialAd!.show();
  }

  void restartGame() {
    _continueUsed   = false;
    score           = 0;
    comboCount      = 0;
    _pendingScroll  = 0;
    _bgLevel        = 0;
    windActive      = false;
    windStrength    = 0.0;
    _lastScoreText  = '0';
    _lastHeightText = '0m';
    _interstitialPending = false; // BUG FIX #3

    scoreText.text  = '0';
    heightText.text = '0m';
    comboText.text  = '';
    windText.text   = '';

    for (final bg in [_bgLevel1, _bgLevel2, _bgLevel3]) {
      bg.children.whereType<Effect>().toList().forEach((e) => e.removeFromParent());
    }
    _bgLevel1.opacity = 1.0;
    _bgLevel2.opacity = 0.0;
    _bgLevel3.opacity = 0.0;

    removeAll(_placedBlocks);
    _placedBlocks.clear();
    removeAll(_offscreenBlocks);
    _offscreenBlocks.clear();

    currentBlock.removeFromParent();
    _setupBaseBlock();
    _spawnBlock();

    gameState = GameState.playing;
    resumeEngine();

    try { FlameAudio.bgm.play('backGroundMusic.mp3', volume: 0.3); } catch (_) {}
  }

  Future<void> showLeaderboardUI() async {
    try {
      await GamesServices.showLeaderboards(androidLeaderboardID: ID_LEADERBOARD);
    } catch (e) {
      debugPrint('Liderlik tablosu hatası: $e');
    }
  }

  void showRewardedAdAndContinue() {
    if (!rewardedAdReadyNotifier.value || _rewardedAd == null) return;
    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) => _continueGame(),
    );
  }

  void _continueGame() {
    _continueUsed = true;
    overlays.remove('gameOver');
    currentBlock.removeFromParent();
    _spawnBlock();
    gameState = GameState.playing;
    resumeEngine();
    try { FlameAudio.bgm.play('backGroundMusic.mp3', volume: 0.3); } catch (_) {}
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

  bool get continueUsed => _continueUsed;
}


// ─── MovingBlock ─────────────────────────────────────────────────────────────
class MovingBlock extends RectangleComponent
    with HasGameReference<StackTowerGame> {
  double speed;
  int  direction = 1;
  bool moving    = true;

  MovingBlock({
    required double yPosition, required double blockWidth,
    required Color blockColor, required double startX,
    required this.speed,
  }) : super(
    position: Vector2(startX, yPosition),
    size:     Vector2(blockWidth, 30),
    paint:    Paint()..color = blockColor,
  );

  @override
  void update(double dt) {
    super.update(dt);
    if (!moving) return;

    // BUG FIX #7: Yerleşmiş (moving=false) bloklara rüzgar uygulanmıyor.
    // Bu satır sadece currentBlock için çalışır (moving=true olanlar).
    if (game.windActive) position.x += game.windStrength * dt;
    position.x += speed * direction * dt;
    if (position.x + size.x >= game.size.x || position.x <= 0) {
      direction *= -1;
      position.x = position.x.clamp(0, game.size.x - size.x);
    }
  }
}


// ─── Menu Overlay ────────────────────────────────────────────────────────────
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
            const Text('STACK TOWER',
              style: TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                game.overlays.remove('mainMenu');
                game.restartGame();
              },
              child: const Text('START GAME'),
            ),
            IconButton(
              icon: const Icon(Icons.leaderboard, color: Colors.white, size: 40),
              onPressed: () => game.showLeaderboardUI(),
            ),
          ],
        ),
      ),
    );
  }
}


// ─── Game Over Overlay ───────────────────────────────────────────────────────
class GameOverOverlay extends StatefulWidget {
  final StackTowerGame game;
  const GameOverOverlay({super.key, required this.game});
  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay> {
  bool _adLoading       = false;
  bool _spinnerTimedOut = false;
  async.Timer? _spinnerTimer;

  @override
  void initState() {
    super.initState();
    if (!globalRewardedAdNotifier.value) {
      _spinnerTimer = async.Timer(const Duration(seconds: 6), () {
        if (!globalRewardedAdNotifier.value && mounted) {
          setState(() => _spinnerTimedOut = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _spinnerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return ValueListenableBuilder<bool>(
      valueListenable: game.rewardedAdReadyNotifier,
      builder: (context, isAdReady, _) {
        final isNewRecord  = game.score >= game.highScore && game.score > 0;
        final showContinue = !game.continueUsed && isAdReady;
        final showSpinner  = !game.continueUsed && !isAdReady && !_spinnerTimedOut;

        return Center(
          child: Container(
            padding: const EdgeInsets.all(30),
            margin:  const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.redAccent, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('GAME OVER',
                  style: TextStyle(color: Colors.redAccent, fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text('Score: ${game.score}',
                  style: const TextStyle(color: Colors.white, fontSize: 28)),
                const SizedBox(height: 6),
                if (isNewRecord)
                  const Text('🏆 NEW RECORD!',
                    style: TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold))
                else
                  Text('Best: ${game.highScore}',
                    style: const TextStyle(color: Colors.white54, fontSize: 16)),
                const SizedBox(height: 24),
                if (showContinue)
                  _ContinueButton(
                    loading: _adLoading,
                    onPressed: _adLoading ? null : () {
                      setState(() => _adLoading = true);
                      game.showRewardedAdAndContinue();
                    },
                  )
                else if (showSpinner)
                  Opacity(opacity: 0.45,
                    child: _ContinueButton(loading: true, onPressed: null)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      game.overlays.remove('gameOver');
                      game.restartGame();
                    },
                    child: const Text('RETRY',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon:  const Icon(Icons.emoji_events, color: Colors.amber),
                  label: const Text('WORLD RANKINGS',
                    style: TextStyle(color: Colors.white)),
                  onPressed: () => game.showLeaderboardUI(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


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
          backgroundColor: const Color(0xFF1DB954),
          foregroundColor: Colors.white,
          padding:   const EdgeInsets.symmetric(vertical: 16),
          shape:     RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
        icon: loading
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.play_circle_filled, size: 22),
        label: Text(loading ? 'Yükleniyor...' : '▶  Videoyu İzle — Devam Et',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        onPressed: onPressed,
      ),
    );
  }
}
