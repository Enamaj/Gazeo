# 🚀 Guide de Publication Google Play Store — GAZEO

Ce guide détaille la procédure officielle de compilation et de publication de l'application **GAZEO — Gaz domestique Yaoundé** sur la Google Play Console (Phase 9.2).

---

## 1. Informations de l'Application

| Paramètre | Valeur |
|---|---|
| **Nom de l'application** | `GAZEO — Gaz domestique Yaoundé` |
| **Package ID / Application ID** | `cm.gazeo.app` |
| **Version Code** | `1` |
| **Version Name** | `1.0.0` |
| **Min SDK** | `26` (Android 8.0 Oreo) |
| **Target SDK** | `34` (Android 14) |
| **Catégorie** | Shopping / Services du quotidien |
| **Classification du contenu** | PEGI 3 (Tout public) |
| **URL API Production** | `https://api.gazeo.cm` |

---

## 2. Génération et Gestion du Keystore de Signature

### Commande de génération
Exécuter le script dédié ou la commande keytool :
```bash
cd gazeo-mobile
./scripts/generate_release_keystore.sh
# OU directement :
keytool -genkey -v -keystore gazeo-release.jks -alias gazeo -keyalg RSA -keysize 2048 -validity 10000
```

> [!CAUTION]
> **RÈGLE CRITIQUE DE SÉCURITÉ** :
> - Ne **JAMAIS** commiter `gazeo-release.jks` ni `key.properties` dans Git.
> - Sauvegarder immédiatement une copie chiffrée du fichier `gazeo-release.jks` sur au moins 2 supports physiques hors ligne (clé USB sécurisée, coffre-fort de mots de passe).
> - La perte de ce fichier rend impossible la mise à jour de l'application sur le Play Store.

### Configuration locale (`android/key.properties`)
Copier le modèle :
```bash
cp android/key.properties.example android/key.properties
```
Renseigner vos identifiants réels :
```properties
keyAlias=gazeo
keyPassword=VOTRE_MOT_DE_PASSE_CLE
storeFile=/chemin/absolu/vers/gazeo-release.jks
storePassword=VOTRE_MOT_DE_PASSE_KEYSTORE
```

---

## 3. Compilation de l'Android App Bundle (AAB)

Pour compiler l'App Bundle optimisé et obfusqué pour le Play Store :
```bash
cd gazeo-mobile
./scripts/build_release_bundle.sh
# OU manuellement :
flutter build appbundle --release --obfuscate --split-debug-info=build/debug_info
```

### Artefacts produits :
- **App Bundle** : `build/app/outputs/bundle/release/app-release.aab` (à uploader sur la Play Console).
- **Symboles de débogage** : `build/debug_info` (à conserver pour désobfusquer les crash logs dans la Play Console).

---

## 4. Fiches de Présentation Google Play Console

### Titre de l'application (50 caractères max)
```
GAZEO — Gaz domestique Yaoundé
```

### Description courte (80 caractères max)
```
Trouvez et commandez votre gaz domestique livré à domicile à Yaoundé en 30 min.
```

### Description complète (4 000 caractères max)
```text
Plus jamais en panne de gaz à Yaoundé !

GAZEO est la première application mobile qui vous permet de localiser instantanément les dépôts de gaz proches de chez vous à Yaoundé et de vous faire livrer votre bouteille à domicile en moins de 30 minutes.

🔥 POURQUOI CHOISIR GAZEO ?
• Disponibilité en temps réel : visualisez les stocks réels de bouteilles 6kg et 12.5kg autour de vous.
• Toutes les marques disponibles : TotalEnergies, Tradex, Camgaz et bien d'autres.
• Suivi GPS en direct : suivez l'arrivée de votre coursier sur la carte en temps réel.
• Paiement simple et sécurisé : réglez instantanément via MTN Mobile Money ou Orange Money (propulsé par Notchpay).
• Sécurité garantie : confirmation de livraison par code OTP unique et vérification KYC de tous nos gérants partenaires.

📍 QUARTIERS COUVERTS À YAOUNDÉ (PHASE BETA) :
Bastos, Melen, Biyem-Assi, Omnisports, Nlongkak, Tsinga, Mokolo, Essos, Mendong et environs.

🚚 COMMENT ÇA MARCHE ?
1. Ouvrez l'application et repérez le dépôt le plus proche disposant de votre marque.
2. Choisissez votre bouteille (6kg ou 12.5kg) et indiquez votre adresse de livraison.
3. Réglez en toute sécurité via Mobile Money (MTN / Orange).
4. Suivez votre livreur en temps réel sur la carte.
5. Donnez votre code secret OTP au livreur à la réception et profitez de votre gaz en toute sérénité !

Rejoignez dès aujourd'hui la communauté GAZEO et facilitez votre quotidien à Yaoundé.

Support client & assistance WhatsApp : +237 6XX XX XX XX
Site officiel : https://gazeo.cm
```

---

## 5. Stratégie de Déploiement

1. **Test interne (2 semaines)** :
   - Uploader l'AAB dans la section **Test interne**.
   - Inviter Enama Eteme Dieudonné + 5 testeurs terrain à Yaoundé.
   - Valider les flux complets : localisation OSM, commande, paiement MoMo réel, confirmation OTP livreur.
2. **Déploiement progressif (Production)** :
   - Lancement initial à 10% des utilisateurs de Yaoundé.
   - Surveillance des métriques de crash (< 0.1%) et du monitoring UptimeRobot sur `https://api.gazeo.cm/health/`.
   - Montée à 50% après 7 jours, puis 100% de déploiement.

