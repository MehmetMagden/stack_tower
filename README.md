# 🏗️ Stack Tower

A minimalist hyper-casual mobile game built with Flutter & Flame engine. Tap to stop each moving block and stack them as perfectly as possible. How high can you go?

![Get it on Google Play](https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png)

---

## 🎮 Gameplay

-   **One tap mechanic** — tap the screen to stop the moving block
-   **Perfect placement** — align within 8px for a bonus and no cut
-   **Increasing speed** — the higher your tower, the faster the blocks move
-   **Game over** — miss the overlap completely and it's over!

---

## ✨ Features

| Feature | Description |
| --- | --- |
| 🎯 Perfect Bonus | Snap & +2 score for near-perfect placements |
| 🌈 Color Transition | Background hue shifts smoothly with each block |
| 💥 Particle Effects | Block cuts trigger satisfying particle explosions |
| 📳 Screen Shake | Camera shake on every cut for impact feedback |
| 🔊 Sound Effects | Pitch-scaling blip sounds that rise with your score |
| 🏆 High Score | Persistent best score saved locally |
| 📱 AdMob Ads | Banner + interstitial ads via Google AdMob |
| 💫 PERFECT! Text | Floating animated text on perfect placements |

---

## 🛠️ Tech Stack

-   **Framework:** Flutter 3.41+
-   **Game Engine:** Flame 1.36+
-   **Audio:** flame\_audio
-   **Ads:** google\_mobile\_ads
-   **Storage:** shared\_preferences
-   **Language:** Dart 3.11+

---

## 🚀 Getting Started

### Prerequisites

-   Flutter SDK 3.41+
-   Android Studio / VS Code
-   Android emulator or physical device (Android 5.0+)

### Setup

```bash
# Clone the repository
git clone https://github.com/MehmetMagden/stack_tower.git
cd stack_tower

# Install dependencies
flutter pub get

# Run in debug mode
flutter run

# Build release APK
flutter build apk --release

# Build release AAB (recommended for Play Store)
flutter build appbundle --release

```

### AdMob Configuration

The app uses Google AdMob for monetization. To run with your own ad units:

1.  Replace the ad unit IDs in `lib/main.dart`:

```dart
const String _bannerAdUnitId = 'your-banner-ad-unit-id';
const String _interstitialAdUnitId = 'your-interstitial-ad-unit-id';

```

2.  Update `android/app/src/main/AndroidManifest.xml` with your AdMob App ID:

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="your-admob-app-id"/>

```

> ⚠️ For development, use [Google's test ad unit IDs](https://developers.google.com/admob/android/test-ads) to avoid invalid traffic.

---

## 📁 Project Structure

```
stack_tower/
├── lib/
│   └── main.dart          # All game logic (single file)
├── assets/
│   ├── audio/
│   │   └── blip.wav       # Sound effect
│   └── icon/
│       └── icon.png       # App icon
├── android/
│   └── app/src/main/
│       └── AndroidManifest.xml
├── pubspec.yaml
└── README.md

```

---

## 🎯 Game Architecture

```
StackTowerApp (StatefulWidget)
├── Splash Screen          # Shows during AdMob init
└── GameWidget
    ├── StackTowerGame     # Main Flame game
    │   ├── MovingBlock    # Horizontally moving blocks
    │   ├── FloatingText   # "PERFECT!" animation
    │   └── BlockParticle  # Cut particle effects
    ├── Main Menu Overlay
    └── Game Over Overlay

```

---

## 🗺️ Roadmap

### v1.0 ✅ (Current)

-   [x]  Core stack mechanic
-   [x]  Perfect placement bonus
-   [x]  Particle effects & screen shake
-   [x]  Background color transitions
-   [x]  Sound effects with pitch scaling
-   [x]  High score persistence
-   [x]  AdMob integration
-   [x]  Main menu & game over screens

### v1.1 (Planned)

-   [ ]  Online leaderboard (Supabase)
-   [ ]  Multiple block themes / skins
-   [ ]  Haptic feedback
-   [ ]  Combo multiplier system
-   [ ]  Share score feature

---

## 📊 Performance Notes

-   Optimized for 60fps on real devices
-   Single `Random` instance to minimize GC pressure
-   Pre-allocated `Paint` objects (no per-frame allocations)
-   World-shift scroll technique instead of camera movement
-   Canvas-level shake via `canvas.translate`

---

## 📄 Privacy Policy

[https://privacypolicy.aimaden.com](https://privacypolicy.aimaden.com)

This app uses Google AdMob which may collect device identifiers for advertising purposes.

---

## 👤 Developer

**Mehmet Magden**  
QA Automation Engineer & Indie Game Developer  
[aimaden.com](https://aimaden.com)

---

## 📜 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

Made with ❤️ using Flutter & Flame