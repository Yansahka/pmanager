# Sésame

Gestionnaire de mots de passe **Flutter / Android**, local et chiffré, avec une interface française vert profond et citron.

L’architecture, les fonctionnalités, les règles et les limites de sécurité sont détaillées dans [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Démarrage

Prérequis : Flutter 3.47.7 / Dart 3.13.5 ou version compatible, SDK Android et JDK compatibles avec le projet Flutter.

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

## Compilation Android

```powershell
flutter build apk --debug
```

APK : `build/app/outputs/flutter-apk/app-debug.apk`.

Le debug est destiné aux essais. Pour distribuer, configurer une vraie signature release avec `android/key.properties` (voir l’exemple fourni) et choisir un identifiant applicatif définitif. La build release refuse une signature de débogage implicite.

```powershell
flutter build apk --release
```

## Utilisation

1. Créer une phrase secrète unique de 16 caractères minimum et la confirmer. Elle ne peut pas être récupérée.
2. Ajouter des identifiants, utiliser le générateur et consulter les alertes locales de sécurité.
3. Exporter régulièrement une sauvegarde chiffrée depuis Réglages. Une désinstallation supprime le coffre local.
4. Pour restaurer, utiliser le bouton de l’écran verrouillé et saisir la phrase de la sauvegarde. Le remplacement intervient après vérification.

Le coffre se verrouille au passage en arrière-plan ou après 2 minutes sans interaction tactile. Le presse-papiers est nettoyé après 30 secondes ou au verrouillage. Les anciennes sauvegardes conservent la phrase qui était active au moment de leur création.

## Vérification visuelle

```powershell
flutter test --update-goldens test/widget_test.dart
```

Aperçus : `test/goldens/welcome.png` et `test/goldens/vault.png`. Régénérer les goldens seulement après revue visuelle d’une modification attendue.

## Structure

- `lib/domain` : entrées, générateur, contrôles locaux.
- `lib/security` : Argon2id et AES-256-GCM.
- `lib/application` : session et opérations du coffre.
- `lib/data` : contrat de stockage et canal Android.
- `lib/ui` : interface Material 3.
- `android/app/src/main` : stockage atomique, sélection de documents et protections Android.
- `test` : scénarios de sécurité et d’interface.

Cette version cible Android. Les autres plateformes présentes dans le squelette initial ne disposent pas du pont de stockage Sésame. Aucun audit indépendant n’a été effectué ; ne pas présenter le code comme une solution certifiée.
