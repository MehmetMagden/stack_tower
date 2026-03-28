import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'package:flame_audio/flame_audio.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// PRODUCTION IDs - uncomment before release
const String _bannerAdUnitId = 'ca-app-pub-3944855115101715/6952688320';
const String _interstitialAdUnitId = 'ca-app-pub-3944855115101715/2814132766';

// TEST IDs - development only
// const String _bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
// const String _interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';






void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //await MobileAds.instance.initialize();
  runApp(const StackTowerApp());  // ← yeni StatefulWidget
}

class StackTowerApp extends StatefulWidget {
  const StackTowerApp({super.key});
  @override
  State<StackTowerApp> createState() => _StackTowerAppState();
}

class _StackTowerAppState extends State<StackTowerApp> {
  late BannerAd _bannerAd;
  bool _isBannerAdReady = false;
  bool _isLoading = true; // ← YENİ
  final StackTowerGame _game = StackTowerGame();

  @override
  void initState() {
    super.initState();
    _initAdMob(); // ← arka planda başlat
    _loadBannerAd();
    // Warmup: AdMob yüklensin, sonra oyunu göster
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  // AdMob'u başlatan yardımcı fonksiyon
  Future<void> _initAdMob() async {
    await MobileAds.instance.initialize();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerAdReady = true),
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    );
    _bannerAd.load();
  }

  @override
  void dispose() {
    _bannerAd.dispose();
    super.dispose();
  }

  Widget _buildSplashScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'STACK\nTOWER',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 56,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 16),
            Container(width: 60, height: 3, color: Colors.tealAccent),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: Colors.tealAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildGame() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: GameWidget(
              game: _game,
              overlayBuilderMap: {
                'mainMenu': (context, game) {
                  final g = game as StackTowerGame;
                  return GestureDetector(
                    onTap: () {
                      g.overlays.remove('mainMenu');
                      g.resumeEngine();
                      g.gameState = GameState.playing;
                    },
                    child: Container(
                      color: const Color(0xFF1a1a2e),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'STACK\nTOWER',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 56,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 8,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(width: 60, height: 3, color: Colors.tealAccent),
                            const SizedBox(height: 32),
                            Text(
                              'Best: ${g.highScore}',
                              style: const TextStyle(color: Colors.white70, fontSize: 22),
                            ),
                            const SizedBox(height: 60),
                            const Text(
                              'Tap anywhere to play!',
                              style: TextStyle(
                                color: Colors.tealAccent,
                                fontSize: 18,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                'gameOver': (context, game) {
                  final g = game as StackTowerGame;
                  return GestureDetector(
                    onTap: () {
                      g.overlays.remove('gameOver');
                      g.resumeEngine();
                      g.restartGame();
                    },
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        color: Colors.black87,
                        child: Text(
                          'GAME OVER\nScore: ${g.score}\nBest: ${g.highScore}\nTap to restart!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              },
            ),
          ),
          // Banner ad at bottom
          if (_isBannerAdReady)
            SizedBox(
              height: _bannerAd.size.height.toDouble(),
              width: double.infinity,
              child: AdWidget(ad: _bannerAd),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _isLoading ? _buildSplashScreen() : _buildGame(),
    );
  }
}


// Background color transition
Color _currentBgColor = const Color(0xFF1a1a2e);
Color _targetBgColor = const Color(0xFF1a1a2e);
double _bgHue = 220.0;
late RectangleComponent background;

// Game states for potential future expansion (e.g. menu, pause)
enum GameState { menu, playing, gameOver }


class StackTowerGame extends FlameGame with TapCallbacks {

  //final _zeroVector = Vector2.zero();
  final _random = math.Random();
  bool _isShaking = false;

  // Ads
  InterstitialAd? _interstitialAd;
  int _gameOverCount = 0;
    
  GameState gameState = GameState.menu;
  double _shakeTimer = 0;
  double _shakeIntensity = 0;


  
  late MovingBlock currentBlock;
  MovingBlock? previousBlock;
  bool isGameOver = false;
  int score = 0;
  int highScore = 0;
  late TextComponent highScoreText;

  late TextComponent scoreText;

  // Smooth scroll — instead of moving camera, move all blocks down
  double _pendingScroll = 0.0;
  static const double _scrollSpeed = 400.0;
  static const double _targetBlockY = 0.65; // keep placed block at 65% of screen

  final List<Color> blockColors = [
    Colors.tealAccent,
    Colors.pinkAccent,
    Colors.amberAccent,
    Colors.lightBlueAccent,
    Colors.lightGreenAccent,
    Colors.orangeAccent,
    Colors.purpleAccent,
  ];
  int colorIndex = 0;

  @override
  Future<void> onLoad() async {
    
    // Background — must be added first so it renders behind blocks
    background = RectangleComponent(
      position: Vector2.zero(),
      size: size,
      paint: Paint()..color = _currentBgColor,
    );
    add(background);




    scoreText = TextComponent(
      text: 'Score: 0',
      position: Vector2(20, 40),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    // Load saved high score
    final prefs = await SharedPreferences.getInstance();
    highScore = prefs.getInt('highScore') ?? 0;

    // High score display on HUD
    highScoreText = TextComponent(
      text: 'Best: $highScore',
      position: Vector2(20, 75),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
    camera.viewport.add(highScoreText); 

    camera.viewport.add(scoreText);

    final baseBlock = MovingBlock(
      yPosition: size.y - 60,
      blockWidth: 200,
      blockColor: blockColors[colorIndex],
      startX: size.x / 2 - 100,
      speed: 200,
    );
    baseBlock.stop();
    add(baseBlock);
    previousBlock = baseBlock;

    // Start at main menu
    pauseEngine();
    overlays.add('mainMenu');

    _loadInterstitialAd();

    _spawnBlock();
    await FlameAudio.audioCache.load('blip.wav');
  }

  // Screen shake state
  Vector2 _currentShakeOffset = Vector2.zero();

  @override
  void update(double dt) {
    super.update(dt);

    // Smoothly shift all blocks down (simulates camera scrolling up)
    if (!isGameOver && _pendingScroll > 0) {
      final scrollAmount = (_scrollSpeed * dt).clamp(0.0, _pendingScroll);
      _pendingScroll -= scrollAmount;
      for (final block in children.whereType<MovingBlock>()) {
        block.position.y += scrollAmount;
      }
    }
    // Smooth background color transition
    _currentBgColor = Color.lerp(_currentBgColor, _targetBgColor, dt * 2)!;
    background.paint.color = _currentBgColor;
    
    
    
    // Screen shake effect
    // Compute shake offset each frame+
    
    if (_shakeTimer > 0) {
      _shakeTimer -= dt;
      _isShaking = true;
      _currentShakeOffset = Vector2(
        (_random.nextDouble() - 0.5) * _shakeIntensity,
        (_random.nextDouble() - 0.5) * _shakeIntensity,
      );
    } else {
      _isShaking = false;
      _currentShakeOffset.setZero();
      background.position.setZero();
    }


  }


  @override
  void render(Canvas canvas) {
    if (_isShaking) {
      canvas.save();
      canvas.translate(_currentShakeOffset.x, _currentShakeOffset.y);
      super.render(canvas);
      canvas.restore();
    } else {
      super.render(canvas);
    }
  }

  

  void _spawnBlock() {
    colorIndex = (colorIndex + 1) % blockColors.length;
    final prevWidth = previousBlock!.size.x;

    // Speed increases with score, max 400
    final speed = (120 + score * 5).clamp(120, 400).toDouble();

    currentBlock = MovingBlock(
      yPosition: previousBlock!.position.y - 40,
      blockWidth: prevWidth,
      blockColor: blockColors[colorIndex],
      startX: 0,
      speed: speed,
    );
    add(currentBlock);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (gameState == GameState.menu) {
      overlays.remove('mainMenu');
      resumeEngine();
      gameState = GameState.playing;
      return;
    }

    if (gameState == GameState.gameOver) {
      overlays.remove('gameOver');
      resumeEngine();
      restartGame();
      return;
    }

    if (!currentBlock.moving) return;
    currentBlock.stop();
    _checkOverlap();
  }

void _checkOverlap() {
  final curr = currentBlock;
  final prev = previousBlock!;

  final currLeft = curr.position.x;
  final currRight = currLeft + curr.size.x;
  final prevLeft = prev.position.x;
  final prevRight = prevLeft + prev.size.x;

  final overlapLeft = currLeft < prevLeft ? prevLeft : currLeft;
  final overlapRight = currRight > prevRight ? prevRight : currRight;
  final overlapWidth = overlapRight - overlapLeft;

  if (overlapWidth <= 0) {
    _gameOver();
    return;
  }

  // Perfect placement detection (within 8px tolerance)
  final leftDiff = (currLeft - prevLeft).abs();
  final rightDiff = (currRight - prevRight).abs();
  final isPerfect = leftDiff < 8 && rightDiff < 8;

  if (isPerfect) {
    // Snap to previous block — no cut
    _playSound(isPerfect: true);
    curr.position.x = prev.position.x;
    curr.size.x = prev.size.x;
    score += 2; // bonus point for perfect
    scoreText.text = 'Score: $score';

    // Show PERFECT! text
    add(FloatingText(
      spawnPosition: Vector2(size.x / 2 - 70, curr.position.y - 15),
      text: '✦ PERFECT! ✦',
    ));
  } else {
    // Normal — trim the block
    curr.position.x = overlapLeft;
    curr.size.x = overlapWidth;
    score++;
    scoreText.text = 'Score: $score';
    _playSound();
    // Trigger screen shake on cut
    _shakeTimer = 0.25;

    // Spawn particles at cut position
    _spawnParticles(
      curr.position.x + curr.size.x / 2,
      curr.position.y,
      curr.paint.color,
    );


    _shakeIntensity = 14.0;
    


  }

  // Advance background hue
  _bgHue = (_bgHue + 18) % 360;
  _targetBgColor = HSVColor.fromAHSV(1.0, _bgHue, 0.7, 0.25).toColor();

  previousBlock = curr;
  _spawnBlock();

  // Queue scroll
  final idealY = size.y * _targetBlockY;
  if (previousBlock!.position.y < idealY) {
    _pendingScroll += idealY - previousBlock!.position.y;
  }
  
}


// Game over logic
void _gameOver() async {
  gameState = GameState.gameOver;
  isGameOver = true;

  if (score > highScore) {
    highScore = score;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('highScore', highScore);
    highScoreText.text = 'Best: $highScore';
  }

  // Show interstitial ad every 3 game overs
  _showInterstitialIfReady();



  pauseEngine();
  overlays.add('gameOver');
}

void _playSound({bool isPerfect = false}) async {
  try {
    final rate = isPerfect
        ? 2.2
        : (1.0 + score * 0.05).clamp(1.0, 2.2);
    final player = await FlameAudio.play('blip.wav', volume: 0.8);
    await player.setPlaybackRate(rate);
  } catch (_) {
    // Ignore audio errors silently
  }
}


void _loadInterstitialAd() {
  InterstitialAd.load(
    adUnitId: _interstitialAdUnitId,
    request: const AdRequest(),
    adLoadCallback: InterstitialAdLoadCallback(
      onAdLoaded: (ad) => _interstitialAd = ad,
      onAdFailedToLoad: (_) => _interstitialAd = null,
    ),
  );
}

void _showInterstitialIfReady() {
  _gameOverCount++;
  // Show interstitial every 3 game overs
  if (_gameOverCount % 3 == 0 && _interstitialAd != null) {
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitialAd();
      },
    );
    _interstitialAd!.show();
  }
}









void _spawnParticles(double x, double y, Color color) {
  for (int i = 0; i < 12; i++) {
    final angle = _random.nextDouble() * 2 * math.pi;  // ✅
    final speed = 80 + _random.nextDouble() * 220;      // ✅
    final velocity = Vector2(
      math.cos(angle) * speed,
      math.sin(angle) * speed - 80,
    );
    add(BlockParticle(
      spawnPosition: Vector2(x, y),
      velocity: velocity,
      color: color,
      size: 3 + _random.nextDouble() * 5,              // ✅
    ));
  }
}





  void restartGame() {
    gameState = GameState.playing;
    isGameOver = false;
    score = 0;
    highScoreText.text = 'Best: $highScore';
    scoreText.text = 'Score: 0';
    _pendingScroll = 0;

    removeAll(children.whereType<MovingBlock>().toList());
    // Reset background
    _bgHue = 220.0;
    _currentBgColor = const Color(0xFF1a1a2e);
    _targetBgColor = const Color(0xFF1a1a2e);
    background.paint.color = _currentBgColor;
    colorIndex = 0;

    final baseBlock = MovingBlock(
      yPosition: size.y - 60,
      blockWidth: 200,
      blockColor: blockColors[colorIndex],
      startX: size.x / 2 - 100,
      speed: 200,
    );
    baseBlock.stop();
    add(baseBlock);
    previousBlock = baseBlock;

    _spawnBlock();
  }
}

class MovingBlock extends RectangleComponent
    with HasGameReference<StackTowerGame> {
  double speed;
  double direction = 1;
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

  void stop() {
    moving = false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!moving) return;

    position.x += speed * direction * dt;

    if (position.x + size.x >= game.size.x) {
      direction = -1;
    }
    if (position.x <= 0) {
      direction = 1;
    }
  }
}


class FloatingText extends PositionComponent {
  final String text;
  final Color color;
  double _lifetime = 0;
  static const double _maxLifetime = 1.2;
  late TextPaint _textPaint;
  final Paint _alphaPaint = Paint(); // ← bir kez oluştur

  FloatingText({
    required Vector2 spawnPosition,
    required this.text,
    this.color = const Color(0xFFFFD700),
  }) : super(position: spawnPosition);

  @override
  Future<void> onLoad() async {
    _textPaint = TextPaint(
      style: TextStyle(
        color: color,
        fontSize: 38,
        fontWeight: FontWeight.bold,
        shadows: [Shadow(color: Colors.orange, blurRadius: 12)],
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    final alpha = (1.0 - _lifetime / _maxLifetime).clamp(0.0, 1.0);
    _alphaPaint.color = Colors.white.withValues(alpha: alpha); // sadece alpha güncelle
    canvas.saveLayer(null, _alphaPaint);
    _textPaint.render(canvas, text, Vector2.zero());
    canvas.restore();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _lifetime += dt;
    position.y -= 90 * dt;
    if (_lifetime >= _maxLifetime) removeFromParent();
  }
}




class BlockParticle extends PositionComponent {
  final Vector2 velocity;
  final Color color;
  double _lifetime = 0;
  static const double _maxLifetime = 0.6;
  final double _size;
  final Paint _paint = Paint();  // ← bir kez oluştur

  BlockParticle({
    required Vector2 spawnPosition,
    required this.velocity,
    required this.color,
    required double size,
  })  : _size = size,
        super(position: spawnPosition);

  @override
  void render(Canvas canvas) {
    final alpha = (1.0 - _lifetime / _maxLifetime).clamp(0.0, 1.0);
    _paint.color = color.withValues(alpha: alpha);  // ← sadece rengi güncelle
    canvas.drawRect(Rect.fromLTWH(0, 0, _size, _size), _paint);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _lifetime += dt;
    position.x += velocity.x * dt;
    position.y += velocity.y * dt;
    velocity.y += 400 * dt;
    if (_lifetime >= _maxLifetime) removeFromParent();
  }

  
}




