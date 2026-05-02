import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:games_services/games_services.dart';

import '../constants/game_constants.dart';
import '../components/moving_block.dart';

class StackTowerGame extends FlameGame with TapCallbacks {
  final SharedPreferences prefs;
  StackTowerGame({required this.prefs});

  final math.Random _random = math.Random();

  late SpriteComponent bg1, bg2, bg3;
  late TextComponent scoreText, comboText, windText;
  List<Sprite> blockSprites = [];
  MovingBlock? currentBlock, previousBlock;
  
  int score = 0, comboCount = 0, _gameOverCount = 0, perfectHits = 0;
  bool windActive = false, isMusicOn = true, isSoundOn = true, canContinue = true;
  double windStrength = 0.0;
  GameState gameState = GameState.menu;
  
  RewardedAd? rewardedAd;
  InterstitialAd? _interstitialAd;

  AudioPool? _placePool;
  AudioPool? _perfectPool;

  double _pendingScroll = 0.0;
  static const double _kMaxPendingScroll = 300.0;
  final List<MovingBlock> _placedBlocks = [];
  final List<MovingBlock> _offscreenBlocks = [];

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2(0, 0);

    isMusicOn = prefs.getBool('isMusicOn') ?? true;
    isSoundOn = prefs.getBool('isSoundOn') ?? true;

    GamesServices.signIn().catchError((e) => debugPrint('❌ Play Games Failed: $e'));

    final loadedBgs = await Future.wait([
      loadSprite('bg_level1.png'),
      loadSprite('bg_level2.png'),
      loadSprite('bg_level3.png'),
    ]);
    
    blockSprites = await Future.wait(
      List.generate(7, (i) => loadSprite('blocks/Blocks_01_64x64_Alt_00_00${i + 1}.png'))
    );

    bg1 = SpriteComponent(sprite: loadedBgs[0], size: size, position: Vector2(0, 0), priority: -10);
    bg2 = SpriteComponent(sprite: loadedBgs[1], size: size, position: Vector2(0, 0), priority: -9)..opacity = 0;
    bg3 = SpriteComponent(sprite: loadedBgs[2], size: size, position: Vector2(0, 0), priority: -8)..opacity = 0;
    
    world.addAll([bg1, bg2, bg3]);
    
    _setupUI();
    _loadAdsDelayed();
    
    await FlameAudio.bgm.initialize();
    await FlameAudio.audioCache.loadAll(['bgm_1.mp3', 'bgm_2.mp3', 'game_over.mp3']);
    
    _placePool = await AudioPool.create(source: AssetSource('audio/place.mp3'), maxPlayers: 4);
    _perfectPool = await AudioPool.create(source: AssetSource('audio/perfect.mp3'), maxPlayers: 4);
    
    _spawnBaseBlock();
    overlays.add('mainMenu');
  }

  void _playRandomBgm() {
    if (!isMusicOn) return;
    final tracks = ['bgm_1.mp3', 'bgm_2.mp3'];
    final selectedTrack = tracks[_random.nextInt(tracks.length)];
    FlameAudio.bgm.play(selectedTrack, volume: 0.3);
  }

  @override
  void onRemove() {
    _placePool?.dispose();
    _perfectPool?.dispose();
    super.onRemove();
  }

  void _setupUI() {
    scoreText = TextComponent(
      text: '0', 
      position: Vector2(size.x / 2, 80), 
      anchor: Anchor.center,
      textRenderer: TextPaint(style: const TextStyle(color: GameConfig.scoreTextColor, fontSize: 60, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 5, color: Colors.black)]))
    );
    
    comboText = TextComponent(
      text: '', 
      position: Vector2(size.x / 2, 160), 
      anchor: Anchor.center, 
      textRenderer: TextPaint(style: const TextStyle(color: GameConfig.perfectTextColor, fontSize: 35, fontWeight: FontWeight.w900, shadows: [Shadow(blurRadius: 10, color: Colors.black)]))
    );
    
    windText = TextComponent(
      text: '', 
      position: Vector2(size.x - 20, 50), 
      anchor: Anchor.topRight, 
      textRenderer: TextPaint(style: const TextStyle(color: GameConfig.windTextColor, fontSize: 20, fontWeight: FontWeight.bold))
    );
    
    camera.viewport.addAll([scoreText, comboText, windText]);
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    if (_pendingScroll > 0) {
      double step = (_pendingScroll < 400 * dt) ? _pendingScroll : 400 * dt;
      _pendingScroll -= step;

      for (int i = _placedBlocks.length - 1; i >= 0; i--) {
        final b = _placedBlocks[i];
        b.position.y += step;
        if (b.position.y > size.y * 1.5) {
          _offscreenBlocks.add(b);
          _placedBlocks.removeAt(i);
        }
      }
      if (currentBlock != null) {
        currentBlock!.position.y += step;
      }
    }

    if (_offscreenBlocks.isNotEmpty) {
      removeAll(_offscreenBlocks);
      _offscreenBlocks.clear();
    }
  }

  void loadAds() {
    InterstitialAd.load(adUnitId: PRODUCTION_INTERSTITIAL, request: const AdRequest(), adLoadCallback: InterstitialAdLoadCallback(onAdLoaded: (ad) => _interstitialAd = ad, onAdFailedToLoad: (_) {}));
    RewardedAd.load(adUnitId: PRODUCTION_REWARDED, request: const AdRequest(), rewardedAdLoadCallback: RewardedAdLoadCallback(onAdLoaded: (ad) => rewardedAd = ad, onAdFailedToLoad: (_) {}));
  }

  void _loadAdsDelayed() => Future.delayed(const Duration(seconds: 5), () => loadAds());

  Future<void> showLeaderboardUI() async {
    try { await GamesServices.showLeaderboards(androidLeaderboardID: ID_LEADERBOARD); } catch (e) { debugPrint('❌ Leaderboard error: $e'); }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (gameState != GameState.playing || currentBlock == null || !currentBlock!.moving) return;
    currentBlock!.moving = false;
    _checkCollision();
  }

  void _checkCollision() {
    final pX = previousBlock!.position.x; 
    final pW = previousBlock!.size.x;
    final cX = currentBlock!.position.x;
    final overlapLeft = math.max(pX, cX);
    final overlapRight = math.min(pX + pW, cX + currentBlock!.size.x);
    final overlapWidth = overlapRight - overlapLeft;

    if (overlapWidth > GameConfig.gameOverThreshold) {
      if ((cX - pX).abs() < GameConfig.perfectTolerance) {
        perfectHits++; comboCount++; score += (comboCount * 2); 
        comboText.text = 'PERFECT X$comboCount';
        currentBlock!.size.x = pW; currentBlock!.position.x = pX;
        
        if (isSoundOn) _perfectPool?.start();
        HapticFeedback.mediumImpact();
      } else {
        currentBlock!.size.x = overlapWidth; currentBlock!.position.x = overlapLeft;
        comboCount = 0; score++; comboText.text = '';
        
        if (isSoundOn) _placePool?.start();
        HapticFeedback.lightImpact();
      }
      
      scoreText.text = '$score';
      _updateBackgroundOpacity();
      
      _placedBlocks.add(currentBlock!);
      previousBlock = currentBlock;

      if (currentBlock!.position.y < size.y * 0.5) {
        _pendingScroll = (_pendingScroll + 30).clamp(0.0, _kMaxPendingScroll);
      }

      _spawnNextBlock();
    } else { 
      _gameOver(); 
    }
  }

  void _updateBackgroundOpacity() {
    if (score == 30) {
      bg1.add(OpacityEffect.to(0.2, EffectController(duration: 2)));
      bg2.add(OpacityEffect.to(1.0, EffectController(duration: 2)));
    } else if (score == 70) {
      bg2.add(OpacityEffect.to(0.1, EffectController(duration: 2)));
      bg3.add(OpacityEffect.to(1.0, EffectController(duration: 2)));
    }
  }

  void _spawnBaseBlock() {
    previousBlock = MovingBlock(
      sprite: blockSprites.first, 
      y: size.y - 150, 
      w: GameConfig.baseBlockWidth, 
      h: GameConfig.blockHeight, 
      x: size.x / 2 - (GameConfig.baseBlockWidth / 2), 
      speed: 0
    );
    previousBlock!.moving = false;
    _placedBlocks.add(previousBlock!);
    world.add(previousBlock!);
  }

  void _spawnNextBlock() {
    double currentSpeed = (GameConfig.initialSpeed + score * GameConfig.speedIncrement)
        .clamp(GameConfig.initialSpeed, GameConfig.maxSpeed);

    bool startsFromLeft = _random.nextBool();
    double startX = startsFromLeft ? 0 : size.x - previousBlock!.size.x;

    currentBlock = MovingBlock(
      sprite: blockSprites[_random.nextInt(blockSprites.length)], 
      y: previousBlock!.position.y - 30, 
      w: previousBlock!.size.x, 
      h: GameConfig.blockHeight, 
      x: startX, 
      speed: currentSpeed
    );
    
    if (!startsFromLeft) {
      currentBlock!.speed *= -1;
    }
    
    world.add(currentBlock!);
    
    if (score > 25) {
      windActive = true; 
      windStrength = ((_random.nextDouble() - 0.5) * (score * GameConfig.windStrengthFactor))
          .clamp(-GameConfig.maxWindStrength, GameConfig.maxWindStrength);
      windText.text = windStrength > 0 ? 'WIND >>' : '<< WIND';
    }
  }

  void _gameOver() {
    if (gameState == GameState.gameOver) return;
    gameState = GameState.gameOver; 
    _gameOverCount++;
    pauseEngine(); FlameAudio.bgm.stop();
    
    if (isSoundOn) FlameAudio.play('game_over.mp3');
    HapticFeedback.vibrate();
    
    if (_gameOverCount % 5 == 0 && _interstitialAd != null) { 
      _interstitialAd!.show(); 
      loadAds(); 
    }
    
    overlays.add('gameOver');
    GamesServices.submitScore(score: Score(androidLeaderboardID: ID_LEADERBOARD, value: score));
    GamesServices.increment(achievement: Achievement(androidID: ID_CLOUD_BUILDER, steps: score));
  }

  void restartGame() {
    score = 0; comboCount = 0; perfectHits = 0; windActive = false; canContinue = true;
    _pendingScroll = 0;
    scoreText.text = '0'; comboText.text = ''; windText.text = '';
    bg1.opacity = 1; bg2.opacity = 0; bg3.opacity = 0;
    
    gameState = GameState.playing; 
    resumeEngine();
    
    world.children.whereType<MovingBlock>().forEach((b) => b.removeFromParent());
    _placedBlocks.clear();
    _offscreenBlocks.clear();
    
    _spawnBaseBlock(); 
    _spawnNextBlock();
    _playRandomBgm();
  }

  void continueGame() {
    canContinue = false; gameState = GameState.playing;
    overlays.remove('gameOver');
    if (currentBlock != null) currentBlock!.removeFromParent();
    resumeEngine(); _spawnNextBlock();
    _playRandomBgm();
  }
}
