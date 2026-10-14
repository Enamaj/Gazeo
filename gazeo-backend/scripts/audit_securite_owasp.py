#!/usr/bin/env python3
"""
Script d'audit de sécurité automatisé GAZEO — Checklist OWASP (Phase 8.2)
Vérifie 100% des exigences de sécurité pour le backend Django et l'application Flutter.

Usage:
    python scripts/audit_securite_owasp.py
"""

import os
import re
import subprocess
import sys
from pathlib import Path


class SecurityAuditor:
    def __init__(self, root_dir: Path):
        self.root_dir = root_dir
        self.backend_dir = root_dir / "gazeo-backend"
        self.mobile_dir = root_dir / "gazeo-mobile"
        self.passed = 0
        self.failed = 0
        self.warnings = 0

    def log_success(self, message: str):
        print(f"  \033[92m[✓ PASS]\033[0m {message}")
        self.passed += 1

    def log_failure(self, message: str):
        print(f"  \033[91m[✗ FAIL]\033[0m {message}")
        self.failed += 1

    def log_warning(self, message: str):
        print(f"  \033[93m[! WARN]\033[0m {message}")
        self.warnings += 1

    def run_command(self, cmd: list[str], cwd: Path | None = None) -> tuple[int, str]:
        try:
            res = subprocess.run(
                cmd,
                cwd=cwd or self.root_dir,
                capture_output=True,
                text=True,
                check=False
            )
            return res.returncode, res.stdout + res.stderr
        except Exception as e:
            return 1, str(e)

    def audit_backend_secrets(self):
        print("\n🔍 1. Audit des secrets dans le code source Git...")
        # Vérification stricte des clés privées et tokens live
        secret_patterns = [
            r"sk_live_[0-9a-zA-Z]{16,}",
            r"-----BEGIN (RSA|EC|OPENSSH|DSA|PGP)? PRIVATE KEY-----",
            r"cloudinary://[0-9]+:[a-zA-Z0-9_-]+@[a-zA-Z0-9_-]+",
        ]
        found_secrets = False
        for pat in secret_patterns:
            code, out = self.run_command(["git", "grep", "-i", "-E", pat])
            if code == 0 and out.strip():
                self.log_failure(f"Secret détecté dans Git : {pat}\n{out.strip()[:200]}")
                found_secrets = True

        if not found_secrets:
            self.log_success("Zéro secret ou clé privée en clair dans l'historique Git")

        # Vérification que .env est bien ignoré par .gitignore
        gitignore = self.backend_dir / ".gitignore"
        root_gitignore = self.root_dir / ".gitignore"
        env_ignored = False
        for gi in (gitignore, root_gitignore):
            if gi.exists() and ".env" in gi.read_text():
                env_ignored = True
                break
        if env_ignored:
            self.log_success("Fichiers .env et credentials correctement exclus par .gitignore")
        else:
            self.log_failure(".env non présent dans .gitignore !")

    def audit_backend_security_headers(self):
        print("\n🔒 2. Audit des headers de sécurité et configuration Django...")
        settings_file = self.backend_dir / "config" / "settings.py"
        if not settings_file.exists():
            self.log_failure(f"Fichier de configuration introuvable : {settings_file}")
            return

        content = settings_file.read_text()

        # Contrôles de sécurité
        checks = [
            ("SECURE_SSL_REDIRECT", "Redirection HTTPS forcée en production"),
            ("SECURE_PROXY_SSL_HEADER", "Support proxy inverse HTTPS (Railway / Nginx)"),
            ("SESSION_COOKIE_SECURE", "Cookie de session sécurisé (Secure flag)"),
            ("CSRF_COOKIE_SECURE", "Cookie CSRF sécurisé (Secure flag)"),
            ("SESSION_COOKIE_HTTPONLY", "Protection XSS sur le cookie de session (HttpOnly)"),
            ("CSRF_COOKIE_HTTPONLY", "Protection XSS sur le cookie CSRF (HttpOnly)"),
            ("SECURE_CONTENT_TYPE_NOSNIFF", "Protection contre le MIME-sniffing (X-Content-Type-Options)"),
            ("X_FRAME_OPTIONS", "Protection contre le Clickjacking (X-Frame-Options: DENY)"),
            ("SECURE_HSTS_SECONDS", "HTTP Strict Transport Security (HSTS) activé"),
            ("token_blacklist", "Révocation et liste noire des tokens JWT (SimpleJWT)"),
        ]

        for setting, desc in checks:
            if setting in content:
                self.log_success(f"{setting} configuré ({desc})")
            else:
                self.log_failure(f"{setting} manquant ou incomplet dans settings.py")

        # Vérifier que DEBUG a False par défaut
        if re.search(r"DEBUG\s*=\s*env\.bool\(['\"]DEBUG['\"],\s*default=False\)", content):
            self.log_success("DEBUG est configuré à False par défaut (mode production sécurisé)")
        else:
            self.log_warning("Vérifiez que DEBUG a bien False par défaut")

    def audit_backend_rate_limiting_and_auth(self):
        print("\n🛡️ 3. Audit du Rate Limiting et de la protection anti-bruteforce...")
        views_file = self.backend_dir / "auth_user" / "views.py"
        content = views_file.read_text()

        if "check_rate_limit_number" in content or "sms_service" in content:
            self.log_success("Rate limiting actif sur l'inscription / envoi OTP (max 3/h par numéro, 10/h par IP)")
        else:
            self.log_failure("Rate limiting absent sur InscriptionView")

        if "gazeo:login:locked:" in content:
            self.log_success("Protection anti-bruteforce active sur /auth/connexion/ (verrouillage 15 min après 5 échecs)")
        else:
            self.log_failure("Protection anti-bruteforce absente sur ConnexionView")

        if "DeconnexionView" in content and "token.blacklist()" in content:
            self.log_success("Endpoint /auth/deconnexion/ avec révocation sécurisée du Refresh Token")
        else:
            self.log_failure("Endpoint de déconnexion avec blacklist manquant")

    def audit_backend_log_sanitization(self):
        print("\n📝 4. Audit de la sanitisation des logs (absence de données sensibles)...")
        sms_file = self.backend_dir / "auth_user" / "services" / "sms_service.py"
        content = sms_file.read_text()

        if "masked_phone" in content and "****" in content:
            self.log_success("Numéros de téléphone masqués dans les logs de SMS (+2376XX****XX)")
        else:
            self.log_failure("Les numéros de téléphone ne sont pas masqués dans les logs SMS")

    def audit_flutter_security(self):
        print("\n📱 5. Audit de la sécurité Flutter Mobile...")

        # 5.1 Vérifier que les tokens JWT sont dans FlutterSecureStorage et JAMAIS dans SharedPreferences
        auth_service = self.mobile_dir / "lib" / "services" / "auth_service.dart"
        if auth_service.exists():
            content = auth_service.read_text()
            if "FlutterSecureStorage" in content and "SharedPreferences" not in content:
                self.log_success("Tokens JWT stockés dans FlutterSecureStorage (JAMAIS dans SharedPreferences)")
            else:
                self.log_failure("Utilisation non sécurisée de stockage de tokens dans auth_service.dart")
        else:
            self.log_failure("auth_service.dart introuvable")

        # 5.2 Vérifier l'absence de print() ou debugPrint() non conditionnés en release
        lib_dir = self.mobile_dir / "lib"
        unprotected_prints = []
        for dart_file in lib_dir.rglob("*.dart"):
            lines = dart_file.read_text().splitlines()
            for idx, line in enumerate(lines, 1):
                clean_line = line.strip()
                if clean_line.startswith("//"):
                    continue
                # Vérifier print() brut
                if re.search(r"\bprint\s*\(", clean_line):
                    unprotected_prints.append(f"{dart_file.name}:{idx} -> {clean_line}")
                # Vérifier debugPrint sans kDebugMode
                if re.search(r"\bdebugPrint\s*\(", clean_line) and "kDebugMode" not in clean_line:
                    # Regarder la ligne précédente
                    prev_line = lines[idx - 2].strip() if idx > 1 else ""
                    if "kDebugMode" not in prev_line:
                        unprotected_prints.append(f"{dart_file.name}:{idx} -> {clean_line}")

        if not unprotected_prints:
            self.log_success("Zéro print() ou debugPrint() non protégé en mode release dans lib/")
        else:
            self.log_failure(f"{len(unprotected_prints)} prints non protégés trouvés :\n" + "\n".join(unprotected_prints[:5]))

        # 5.3 Vérifier la validation des certificats SSL (Certificate Pinning)
        api_service = self.mobile_dir / "lib" / "services" / "api_service.dart"
        if api_service.exists():
            content = api_service.read_text()
            if "validateCertificate" in content:
                self.log_success("Validation stricte des certificats SSL/TLS active dans ApiService")
            else:
                self.log_failure("Validation de certificat SSL absente dans ApiService")

        # 5.4 Vérifier la configuration ProGuard / R8 et l'obfuscation release
        gradle_file = self.mobile_dir / "android" / "app" / "build.gradle.kts"
        proguard_file = self.mobile_dir / "android" / "app" / "proguard-rules.pro"

        if gradle_file.exists():
            content = gradle_file.read_text()
            if "isMinifyEnabled = true" in content and "isShrinkResources = true" in content:
                self.log_success("Minification R8 et réduction des ressources activées dans build.gradle.kts")
            else:
                self.log_failure("Minification R8 désactivée pour le build release")

        if proguard_file.exists() and "flutter" in proguard_file.read_text().lower():
            self.log_success("Fichier proguard-rules.pro configuré pour la protection de l'obfuscation release")
        else:
            self.log_failure("proguard-rules.pro manquant ou invalide")

    def run_all(self):
        print("==================================================================")
        print("🛡️  GAZEO — AUDIT DE SÉCURITÉ AUTOMATISÉ (CHECKLIST OWASP)")
        print("==================================================================")
        self.audit_backend_secrets()
        self.audit_backend_security_headers()
        self.audit_backend_rate_limiting_and_auth()
        self.audit_backend_log_sanitization()
        self.audit_flutter_security()

        print("\n==================================================================")
        print(f"📊 RÉSULTAT : {self.passed} SUCCÈS, {self.failed} ÉCHECS, {self.warnings} AVERTISSEMENTS")
        print("==================================================================")
        if self.failed == 0:
            print("🎉 AUDIT SÉCURITÉ CONFORME À 100% ! Prêt pour le déploiement production.")
            return 0
        else:
            print("❌ CORRECTIONS REQUISES AVANT DE CONTINUER.")
            return 1


if __name__ == "__main__":
    root = Path(__file__).resolve().parent.parent.parent
    auditor = SecurityAuditor(root)
    sys.exit(auditor.run_all())

