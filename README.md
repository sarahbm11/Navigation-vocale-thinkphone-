# Navigation Vocale — SDK Flutter pour Thinkphone

Naviguez sur votre Thinkphone entièrement à la voix, sans jamais toucher l'écran.  
**Aucune donnée n'est enregistrée ni transmise.** Tout le traitement se fait localement sur l'appareil.

---

## Fonctionnalités

| Catégorie | Commandes vocales |
|-----------|-------------------|
| Navigation système | Accueil, Retour, Applications récentes, Notifications |
| Lancer une appli | "Ouvrir [nom]", "Lancer [nom]" |
| Fermer | "Fermer", "Close" |
| Défilement | Haut, Bas, Gauche, Droite |
| Toucher | "Appuyer sur [élément]", "Appui long" |
| Vie privée | "Micro off / on", bouton rouge rapide |
| Arrêt complet | "Arrêter", "Stop" |

> Toutes les commandes fonctionnent en **français** et en **anglais**.

---

## Installation

### 1. Ajouter le SDK à `pubspec.yaml`

```yaml
dependencies:
  navigation_vocale:
    path: ../navigation_vocale   # ou git/pub quand publié
```

### 2. Permissions Android (`AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />
```

Déclarez aussi le service d'accessibilité dans votre manifest :

```xml
<service
    android:name="ca.thinkphone.navigation_vocale.VoiceNavigationAccessibilityService"
    android:exported="true"
    android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE">
    <intent-filter>
        <action android:name="android.accessibilityservice.AccessibilityService" />
    </intent-filter>
    <meta-data
        android:name="android.accessibilityservice"
        android:resource="@xml/accessibility_service_config" />
</service>
```

### 3. Activer le service d'accessibilité (une seule fois)

Au premier lancement, allez dans :  
**Paramètres → Accessibilité → Navigation Vocale Thinkphone** → Activé

Le SDK vous y amène automatiquement si le service n'est pas encore activé.

---

## Usage rapide

```dart
import 'package:navigation_vocale/navigation_vocale.dart';

final sdk = NavigationVocaleSDK();

// Initialisation (demande le micro si besoin)
await sdk.initialize();

// Démarrer l'écoute
await sdk.start();

// Écouter les commandes reconnues
sdk.onCommand.listen((cmd) {
  print('Commande : ${cmd.type}  Texte : "${cmd.rawText}"');
});

// Couper le micro (vie privée) — un appui suffit sur le bouton rouge
sdk.muteMic();

// Réactiver
sdk.unmuteMic();

// Arrêt propre
sdk.dispose();
```

### Intégration de l'overlay

```dart
@override
Widget build(BuildContext context) {
  return Stack(
    children: [
      // Votre app normale ici
      MonEcran(),

      // Overlay micro draggable, toujours visible
      VoiceNavOverlay(sdk: sdk),
    ],
  );
}
```

---

## Architecture

```
navigation_vocale/
├── lib/
│   ├── navigation_vocale.dart          ← export public
│   └── src/
│       ├── navigation_vocale_sdk.dart  ← point d'entrée SDK
│       ├── models/
│       │   ├── voice_command.dart      ← commande analysée
│       │   └── navigation_action.dart ← résultat d'action
│       ├── services/
│       │   ├── voice_recognition_service.dart   ← STT local
│       │   └── system_navigation_service.dart   ← canal Android
│       ├── utils/
│       │   └── command_parser.dart    ← FR + EN → CommandType
│       └── widgets/
│           ├── voice_nav_button.dart  ← bouton micro animé
│           └── voice_nav_overlay.dart ← overlay draggable
├── android/
│   └── src/main/kotlin/ca/thinkphone/navigation_vocale/
│       ├── NavigationVocalePlugin.kt                  ← bridge Flutter↔Android
│       └── VoiceNavigationAccessibilityService.kt     ← gestes système
└── example/                           ← app de démonstration
```

### Flux de données

```
Voix → SpeechToText (sur appareil) → CommandParser → NavigationVocaleSDK
     → SystemNavigationService → MethodChannel → AccessibilityService → Geste
```

---

## Vie privée

- La reconnaissance vocale utilise le moteur **on-device** d'Android (`SpeechToText` en mode local).
- **Rien n'est envoyé à un serveur externe.**
- Le micro se coupe immédiatement avec la commande `"Micro off"` ou un appui sur le bouton rouge.
- Aucun historique n'est conservé entre les sessions.

---

## Exigences

| Élément | Version minimale |
|---------|-----------------|
| Android | 8.0 (API 26) |
| Flutter | 3.10 |
| Dart    | 3.0 |
| Thinkphone (Motorola) | Android 12+ recommandé |
