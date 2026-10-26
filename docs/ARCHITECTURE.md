# Sésame : architecture, fonctionnalités et sécurité

## Périmètre

Application **Flutter pour Android**, locale et sans compte. Les dossiers iOS, web et desktop restent issus du projet initial ; le stockage natif de cette version est implémenté et compilé pour Android uniquement. Aucun serveur, SDK analytique ou accès réseau n'est nécessaire au fonctionnement du coffre. Les permissions Internet des variantes Flutter de développement servent aux outils de debug ; la variante principale n'en déclare pas.

## Architecture

```text
Interface Material 3, en français
  GateScreen / VaultScreen / EntryEditor / GeneratorPanel
                       ↓
  VaultController : session, CRUD, verrouillage, rotation, restauration
                 ↓                         ↓
  VaultCrypto                         VaultStorage (interface)
  Argon2id + AES-GCM                   AndroidVaultStorage
                                              ↓ MethodChannel sesame/vault
                                      MainActivity Kotlin
                                      AtomicFile + noBackupFilesDir
                                      Sélecteur SAF / presse-papiers
```

| Couche | Fichiers | Responsabilité |
| --- | --- | --- |
| Domaine | `lib/domain/vault_entry.dart` | Modèle, validation de phrase, génération aléatoire et contrôle local |
| Sécurité | `lib/security/vault_crypto.dart` | Dérivation, format versionné, chiffrement authentifié |
| Données | `lib/data/vault_storage.dart` | Contrat injectable et pont Android |
| Application | `lib/application/vault_controller.dart` | Session, sauvegarde avant mise à jour UI, invalidation des opérations au verrouillage |
| Présentation | `lib/app.dart`, `lib/ui/` | Thème, navigation, formulaires, écrans et cycle de vie |
| Android | `MainActivity.kt`, manifeste et XML | Écritures atomiques, absence de backup automatique, protection écran, import/export |

Les titres, identifiants, catégories, favoris, URL et notes font partie de la charge chiffrée. Les données en clair sont chargées uniquement pendant une session ouverte. La liste affichée est une vue en mémoire du coffre déchiffré, jamais une base de données en clair.

## Fonctionnalités livrées

- Création du coffre avec phrase secrète confirmée, minimum 16 caractères, maximum 256 et rejet de motifs courants.
- Déverrouillage, masquage/révélation volontaire des secrets, verrouillage manuel.
- Création, consultation, modification et suppression confirmée des identifiants.
- Champs : nom, identifiant/e-mail, mot de passe, URL, notes, catégorie, favori, date de modification.
- Recherche locale par nom, identifiant et URL ; filtre par catégorie ; tri alphabétique ; écran favoris.
- Générateur de 12 à 64 caractères avec options chiffres et symboles. Au moins un caractère de chaque groupe activé, sélection uniforme et mélange Fisher–Yates avec `Random.secure()`.
- Contrôle local des mots de passe courts/prévisibles et des mots de passe strictement identiques. Ce contrôle ne mesure pas l'entropie et ne recherche pas les fuites de données.
- Copie sensible avec effacement à 30 secondes et au verrouillage. Une copie ultérieure d'une autre application n'est pas écrasée par le minuteur de Sésame.
- Export du fichier chiffré `.sesame` via le sélecteur de documents Android. L'export verrouille le coffre avant l'ouverture du sélecteur.
- Import depuis l'écran verrouillé : confirmation du remplacement, contrôle du format, déchiffrement avec la phrase du fichier et validation des entrées **avant** remplacement du coffre existant. Pas de fusion implicite.
- Changement de phrase après vérification de la phrase actuelle, avec nouveau sel et nouveau chiffrement.
- Présentation responsive, navigation inférieure, états vides, messages d'erreur et police Roboto embarquée sans téléchargement.

## Format cryptographique v1

1. Sel aléatoire de 16 octets.
2. **Argon2id**, 19 456 KiB (19 MiB), 2 itérations, parallélisme 1, résultat de 32 octets. Dérivation dans un isolate pour ne pas bloquer l'interface.
3. **AES-256-GCM**, nonce aléatoire de 12 octets renouvelé à chaque écriture, tag de 16 octets.
4. Données associées fixes : `sesame:v1:argon2id:19456:2:1`. Les paramètres et longueurs d'en-tête sont validés strictement ; les paramètres importés ne peuvent pas imposer un coût arbitraire.
5. JSON externe : format/version/paramètres KDF/sel/nonce/tag/texte chiffré en Base64. JSON interne : version et liste des entrées.
6. Fichier limité à 8 MiB à la lecture, à l'import et à l'écriture, avant déchiffrement.

Ces paramètres Argon2id correspondent au minimum proposé par [OWASP Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html). L'implémentation utilise les primitives de [cryptography 2.9.0](https://pub.dev/packages/cryptography), sans algorithme de chiffrement maison. Il faut mesurer le coût sur les appareils cibles et prévoir une migration versionnée si les paramètres évoluent.

## Règles de sécurité appliquées

- La phrase maître et la clé dérivée ne sont jamais écrites dans les préférences, fichiers ou journaux.
- Le fichier réside dans `noBackupFilesDir`, privé à l'application. `AtomicFile` assure la récupération après une écriture interrompue ; une erreur de lecture ne déclenche jamais la création d'un nouveau coffre par-dessus le fichier existant.
- Une mutation n'est publiée à l'interface qu'après succès de la persistance. En cas d'échec d'écriture, l'état précédent reste disponible.
- Verrouillage dès tout état Flutter différent de `resumed`, après 2 minutes sans interaction tactile, ou sur demande.
- À la fermeture de session, retrait des entrées de l'état et remise à zéro du tampon de clé détenu par le contrôleur. Les dialogues sensibles sont fermés, les contrôleurs de saisie supprimés et le presse-papiers nettoyé.
- Un compteur de session invalide les déverrouillages en cours quand l'application passe en arrière-plan. Une opération asynchrone ne peut pas rouvrir silencieusement la session.
- Temporisation locale après trois échecs : 15 à 60 secondes. Ce mécanisme n'est pas persistant et ne protège pas un fichier volé contre une attaque hors ligne ; la KDF et la qualité de la phrase assurent cette protection.
- Android `FLAG_SECURE` bloque les captures et protège les aperçus récents selon le comportement du système. Voir [Android : activités sensibles](https://developer.android.com/security/fraud-prevention/activities).
- Sauvegarde Android automatique et transfert exclus : `allowBackup=false`, règles cloud/device-transfer et fichier hors backup. Voir [Android : sauvegardes](https://developer.android.com/privacy-and-security/risks/backup-best-practices).
- Secrets masqués par défaut, suggestions/autocorrection/apprentissage IME désactivés dans les champs sensibles, indicateur de presse-papiers sensible pour Android compatible.
- Aucun export CSV/en clair et aucune ouverture automatique des URL saisies.

## Menaces et limites

Le chiffrement vise notamment le vol du fichier au repos et les modifications non authentifiées. Il ne protège pas d'un appareil compromis, d'un clavier malveillant, d'un service d'accessibilité abusif ou de la lecture des secrets pendant une session ouverte. Le presse-papiers reste une surface partagée : l'effacement ultérieur n'annule pas les lectures précédentes.

Dart et la JVM sont des environnements à mémoire gérée : les chaînes et les copies temporaires en mémoire ne peuvent pas être effacées de manière garantie. La suppression d'une entrée ne garantit pas l'effacement physique de ses anciennes représentations sur flash ou dans les sauvegardes exportées. Un fichier ancien valide peut être restauré : le format n'offre pas de protection anti-retour arrière.

Il n'y a ni récupération de phrase, ni synchronisation cloud, ni biométrie, ni autofill système, ni partage de coffre ni TOTP dans cette version. Ces fonctions demanderaient des décisions de sécurité supplémentaires, notamment Android Keystore pour un déverrouillage biométrique et un service Autofill qui vérifie les domaines/applications destinataires.

Avant une distribution : choisir l'identifiant applicatif définitif, signer avec une clé de production gardée hors Git, effectuer un audit indépendant et des tests Android sur plusieurs versions, notamment pause/reprise, presse-papiers, import/export, panne de stockage et interruption d'écriture. L'APK de développement ne constitue pas une certification de sécurité.

## Validation automatisée

Les tests couvrent : générateur et groupes activés, renouvellement des nonces, altération nonce/tag/ciphertext, rejet des paramètres KDF inconnus, absence des champs en clair dans le fichier, mauvais mot de passe, persistance après redémarrage du contrôleur, échec d'écriture, rotation de phrase, restauration valide/invalide, annulation d'un déverrouillage par verrouillage, échec de lecture, écran d'accueil et fermeture d'une fiche au passage en arrière-plan. Les images golden permettent d'inspecter l'accueil et le coffre à une largeur mobile de 412 px.

Les tests injectent un stockage mémoire. Ils ne remplacent pas la validation du pont Kotlin et du système Android sur un appareil réel.
