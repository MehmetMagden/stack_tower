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

// --- GOOGLE PLAY SERVICES ID'LERI ---
const String ID_LEADERBOARD = 'CgkI0JfKtagIEAIQAw';
const String ID_PERFECT_KING = 'CgkI0JfKtagIEAIQAA';
const String ID_NIGHT_OWL = 'CgkI0JfKtagIEAIQAQ';
const String ID_CLOUD_BUILDER = 'CgkI0JfKtagIEAIQAg';

// --- AdMob ID'LERI (TEST) — Release'de gerçek ID'lerle değiştir ---
const String _kBannerAdId = 'ca-app-pub-3940256099942544/6300978111';
const String _kInterstitialAdId = 'ca-app-pub-3940256099942544/1033173712';
const String _kRewardedAdId = 'ca-app-pub-3940256099942544/5224354917';

// ─────────────────────────────────────────────────────────────────────────────
// OPT #1 — TextPaint'leri top-level sabit olarak tanımla.
//          Her TextComponent oluşturulduğunda yeni TextPaint/TextStyle yaratmak
//          Flutter'ın text layout hesaplamalarını yeniden tetikler.
//          Sabit referanslar bu maliyeti tamamen ortadan kaldırır.
// ─────────────────────────────────────────────────────────────────────────────
const _scoreStyle = TextStyle(
  color: Colors.white,
  fontSize: 60,
  fontWeight: FontWeight.bold,
);
const _comboStyle = TextStyle(
  color: Colors.orangeAccent,
  fontSize: 26,
  fontWeight: FontWeight.bold,
);
const _heightStyle = TextStyle(color: Colors.white70, fontSize: 18);
const _windStyle = TextStyle(
  color: Colors.redAccent,
  fontSize: 18,
  fontWeight: FontWeight.bold,
);

final _scoreTextPaint = TextPaint(style: _scoreStyle);
final _comboTextPaint = TextPaint(style: _comboStyle);
final _heightTextPaint = TextPaint(style: _heightStyle);
final _windTextPaint = TextPaint(style: _windStyle);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // OPT #2 — SharedPreferences instance'ını main'de bir kez al, sakla.
  //          Her seferinde getInstance() çağırmak micro-delay'e neden olur.
  final prefs = await SharedPreferences.getInstance();

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
    _bannerAd.dispose(); // OPT #3 — Banner ad kaynağını serbest bırak
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
                'mainMenu': (_, game) =>
                    MenuOverlay(game: game as StackTowerGame),
                'gameOver': (_, game) =>
                    GameOverOverlay(game: game as StackTowerGame),
              },
            ),
            // OPT #4 — RepaintBoundary: Banner reklam güncellendiğinde oyun
            //          sahnesinin yeniden render edilmesini önler.
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
  // OPT #2 — SharedPreferences dışarıdan enjekte edildi, tekrar getInstance() çağrılmıyor
  final SharedPreferences prefs;
  StackTowerGame({required this.prefs});

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

  // OPT #5 — _placedBlocks büyüdükçe hem memory hem update maliyeti artar.
  //          Ekran dışına çıkan blokları takip edip silebilmek için ayrı liste.
  final List<MovingBlock> _placedBlocks = [];
  final List<MovingBlock> _offscreenBlocks = []; // temizlenecek bekleyenler

  double _pendingScroll = 0.0;
  double windStrength = 0.0;
  bool windActive = false;

  // OPT #6 — AudioPool: place.mp3 ve perfect.mp3 sık tetiklenir.
  //          FlameAudio.play() her çağrıda yeni AudioPlayer açabilir → latency.
  //          AudioPool önceden yüklenmiş player havuzu yönetir.
  AudioPool? _placePool;
  AudioPool? _perfectPool;

  // Rewarded
  RewardedAd? _rewardedAd;
  bool _isRewardedAdReady = false;
  bool _continueUsed = false;

  InterstitialAd? _interstitialAd;
  int _gameOverCount = 0;

  // OPT #7 — blockColors const listesi: her erişimde yeni Color nesnesi yaratılmaz.
  static const List<Color> blockColors = [
    Colors.tealAccent,
    Colors.pinkAccent,
    Colors.amberAccent,
    Colors.lightBlueAccent,
    Colors.purpleAccent,
  ];

  // OPT #8 — String önbelleği: her blokta '${score * 3}m' string interpolation
  //          yeni String nesnesi yaratır. Küçük etki ama ücretsiz kazanım.
  String _lastHeightText = '0m';
  String _lastScoreText = '0';

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.center;

    // Arka plan sprite'larını paralel yükle (seri yerine paralel → daha hızlı)
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

    // OPT #2 — prefs artık constructor'dan geliyor, getInstance() yok
    highScore = prefs.getInt('highScore') ?? 0;

    _loadInterstitialAd();
    _loadRewardedAd();
    _setupBaseBlock();
    _spawnBlock();

    overlays.add('mainMenu');
    pauseEngine();

    // OPT #6 — Sık sesler AudioPool ile yükle, nadir sesler normal cache ile
    // Flame ses dosyaları assets/audio/ klasöründe, AssetSource'a tam alt yolu ver
    await FlameAudio.audioCache.loadAll([
      'game_over.mp3',
      'backGroundMusic.mp3',
    ]);
    _placePool = await AudioPool.create(
      source: AssetSource('audio/place.mp3'),
      maxPlayers: 4,
    );
    _perfectPool = await AudioPool.create(
      source: AssetSource('audio/perfect.mp3'),
      maxPlayers: 4,
    );
  }

  // OPT #1 — TextPaint'ler top-level final olarak tanımlandı, buraya taşındı
  void _setupUI() {
    scoreText = TextComponent(
      text: '0',
      position: Vector2(size.x / 2, 80),
      anchor: Anchor.center,
      textRenderer: _scoreTextPaint, // ← sabit referans
    );
    comboText = TextComponent(
      text: '',
      position: Vector2(size.x / 2, 140),
      anchor: Anchor.center,
      textRenderer: _comboTextPaint, // ← sabit referans
    );
    heightText = TextComponent(
      text: '0m',
      position: Vector2(20, 40),
      textRenderer: _heightTextPaint, // ← sabit referans
    );
    windText = TextComponent(
      text: '',
      position: Vector2(size.x - 20, 40),
      anchor: Anchor.topRight,
      textRenderer: _windTextPaint, // ← sabit referans
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
    final speed = (150 + score * 5).clamp(150, 500).toDouble();
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
      final step = (_pendingScroll < 400 * dt) ? _pendingScroll : 400 * dt;
      _pendingScroll -= step;

      // OPT #9 — Sadece yerleştirilmiş blokları kaydır.
      //          Ekran dışına çıkan blokları _offscreenBlocks'a al, sonra sil.
      for (int i = _placedBlocks.length - 1; i >= 0; i--) {
        final b = _placedBlocks[i];
        b.position.y += step;
        // Ekranın 1.5 katı aşağıya inerse artık görünmez → kaldır
        if (b.position.y > size.y * 1.5) {
          _offscreenBlocks.add(b);
          _placedBlocks.removeAt(i);
        }
      }
      currentBlock.position.y += step;
    }

    // OPT #9 — Ekran dışı blokları toplu temizle (update sonunda, safe)
    if (_offscreenBlocks.isNotEmpty) {
      removeAll(_offscreenBlocks);
      _offscreenBlocks.clear();
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (gameState != GameState.playing || !currentBlock.moving) return;
    currentBlock.moving = false;
    _checkOverlap(); // OPT #10 — artık async değil, senkron
  }

  // OPT #10 — _checkOverlap async DEĞİL.
  //           async/await oyun döngüsü içinde race condition ve frame skip'e yol açar.
  //           GamesServices.unlock() çağrısı unawaited bırakıldı (fire-and-forget).
  void _checkOverlap() {
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

    final isPerfect =
        (currentBlock.position.x - previousBlock!.position.x).abs() < 7;

    if (isPerfect) {
      currentBlock.position.x = previousBlock!.position.x;
      currentBlock.size.x = previousBlock!.size.x;
      comboCount++;
      score += (1 + comboCount);

      // OPT #6 — AudioPool ile düşük latency ses çalma
      _perfectPool?.start();
      comboText.text = 'PERFECT X$comboCount';
      HapticFeedback.mediumImpact();

      if (comboCount >= 10) {
        // fire-and-forget: oyun akışını bloklamaz
        GamesServices.unlock(
          achievement: Achievement(androidID: ID_PERFECT_KING),
        ).catchError((_) {});
      }
    } else {
      currentBlock.position.x = overlapLeft;
      currentBlock.size.x = overlapWidth;
      comboCount = 0;
      score++;
      comboText.text = '';
      // OPT #6
      _placePool?.start();
      HapticFeedback.lightImpact();
    }

    // OPT #8 — String önbelleği: değişmediyse text güncelleme
    final newScore = '$score';
    final newHeight = '${score * 3}m';
    if (newScore != _lastScoreText) {
      scoreText.text = newScore;
      _lastScoreText = newScore;
    }
    if (newHeight != _lastHeightText) {
      heightText.text = newHeight;
      _lastHeightText = newHeight;
    }

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

  // OPT #10 — _gameOver da artık async değil.
  //           PGS çağrıları fire-and-forget yapıldı.
  void _gameOver() {
    gameState = GameState.gameOver;

    try {
      FlameAudio.bgm.stop();
    } catch (_) {}
    FlameAudio.play('game_over.mp3');
    HapticFeedback.vibrate();

    // fire-and-forget PGS çağrıları
    GamesServices.submitScore(
      score: Score(androidLeaderboardID: ID_LEADERBOARD, value: score),
    ).catchError((_) {});

    GamesServices.increment(
      achievement: Achievement(androidID: ID_CLOUD_BUILDER, steps: score),
    ).catchError((_) {});

    final hour = DateTime.now().hour;
    if (hour >= 0 && hour <= 5) {
      GamesServices.unlock(
        achievement: Achievement(androidID: ID_NIGHT_OWL),
      ).catchError((_) {});
    }

    if (score > highScore) {
      highScore = score;
      // OPT #2 — prefs instance hazır, await gerekmez (fire-and-forget)
      prefs.setInt('highScore', highScore);
    }

    _showInterstitialIfReady();
    overlays.add('gameOver');
    pauseEngine();
  }

  void restartGame() {
    _continueUsed = false;
    score = 0;
    comboCount = 0;
    _pendingScroll = 0;
    _bgLevel = 0;
    windActive = false;
    windStrength = 0.0;
    _lastScoreText = '0';
    _lastHeightText = '0m';

    scoreText.text = '0';
    heightText.text = '0m';
    comboText.text = '';
    windText.text = '';

    for (final bg in [_bgLevel1, _bgLevel2, _bgLevel3]) {
      bg.children.whereType<Effect>().toList().forEach(
        (e) => e.removeFromParent(),
      );
    }
    _bgLevel1.opacity = 1.0;
    _bgLevel2.opacity = 0.0;
    _bgLevel3.opacity = 0.0;

    // OPT #9 — _offscreenBlocks da temizlenmeli
    removeAll(_placedBlocks);
    _placedBlocks.clear();
    removeAll(_offscreenBlocks);
    _offscreenBlocks.clear();

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

  // ── Rewarded Ad ──────────────────────────────────────────────────────────
  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _kRewardedAdId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdReady = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              _isRewardedAdReady = false;
              _loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _rewardedAd = null;
              _isRewardedAdReady = false;
              _loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (_) {
          _isRewardedAdReady = false;
          Future.delayed(const Duration(seconds: 30), _loadRewardedAd);
        },
      ),
    );
  }

  void showRewardedAdAndContinue() {
    if (!_isRewardedAdReady || _rewardedAd == null) return;
    _rewardedAd!.show(onUserEarnedReward: (ad, reward) => _continueGame());
  }

  void _continueGame() {
    _continueUsed = true;
    overlays.remove('gameOver');
    currentBlock.removeFromParent();
    _spawnBlock();
    gameState = GameState.playing;
    resumeEngine();
    try {
      FlameAudio.bgm.play('backGroundMusic.mp3', volume: 0.3);
    } catch (_) {}
  }

  // ── Interstitial Ad ───────────────────────────────────────────────────────
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

  bool get isRewardedAdReady => _isRewardedAdReady;
  bool get continueUsed => _continueUsed;
}

// ─────────────────────────────────────────────────────────────────────────────
// MovingBlock
// OPT #11 — Paint nesnesi constructor'da final olarak yaratılıyor.
//            HasPaint mixin bunu component düzeyinde cache'ler.
//            RectangleComponent bunu zaten doğru yapıyor — dokunmaya gerek yok.
// ─────────────────────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// MENU OVERLAY
// OPT #4 — const constructor kullanımı: widget tree'de immutable node
// ─────────────────────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// GAME OVER OVERLAY
// ─────────────────────────────────────────────────────────────────────────────
class GameOverOverlay extends StatefulWidget {
  final StackTowerGame game;
  const GameOverOverlay({super.key, required this.game});

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay> {
  bool _adLoading = false;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final isNewRecord = game.score >= game.highScore && game.score > 0;
    final showContinueButton = !game.continueUsed && game.isRewardedAdReady;
    final showLoadingButton = !game.continueUsed && !game.isRewardedAdReady;

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
            const Text(
              'GAME OVER',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Score: ${game.score}',
              style: const TextStyle(color: Colors.white, fontSize: 28),
            ),
            const SizedBox(height: 6),
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

            // ── Devam Et butonu ──
            if (showContinueButton)
              _ContinueButton(
                loading: _adLoading,
                onPressed: () {
                  setState(() => _adLoading = true);
                  game.showRewardedAdAndContinue();
                },
              )
            else if (showLoadingButton)
              Opacity(
                opacity: 0.45,
                child: _ContinueButton(loading: true, onPressed: null),
              ),

            const SizedBox(height: 12),

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
