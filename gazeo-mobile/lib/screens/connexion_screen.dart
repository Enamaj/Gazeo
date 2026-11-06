import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/phone_auth_service.dart';
import '../theme/app_theme.dart';

class ConnexionScreen extends StatefulWidget {
  const ConnexionScreen({super.key});

  @override
  State<ConnexionScreen> createState() => _ConnexionScreenState();
}

class _ConnexionScreenState extends State<ConnexionScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  late TabController _tabController;

  // Formulaire Connexion
  final _loginPhoneController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _loginObscure = true;
  bool _isLoggingIn = false;

  // Formulaire Inscription
  final _registerNomController = TextEditingController();
  final _registerDepotController = TextEditingController();
  final _registerPhoneController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  String _selectedRole = 'CLIENT';
  bool _registerObscure = true;
  bool _isRegistering = false;
  bool _otpSent = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginPhoneController.dispose();
    _loginPasswordController.dispose();
    _registerNomController.dispose();
    _registerDepotController.dispose();
    _registerPhoneController.dispose();
    _registerPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isRegistering = true);
    // Simulation / Authentification Google
    await Future.delayed(const Duration(milliseconds: 900));
    await AuthService().saveTokens(
      access: 'google_token_sample_${DateTime.now().millisecondsSinceEpoch}',
      refresh: 'google_refresh_token_sample',
      role: 'CLIENT',
      phone: '+237 6 90 00 00 00',
    );
    if (!mounted) return;
    setState(() => _isRegistering = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.primary,
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Connecté via Google (Client) avec succès !'),
          ],
        ),
      ),
    );
    context.go('/');
  }

  Future<void> _handleLogin() async {
    final phone = _loginPhoneController.text.trim();
    final password = _loginPasswordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez renseigner le téléphone et le mot de passe.'),
        ),
      );
      return;
    }

    setState(() => _isLoggingIn = true);

    try {
      final res = await _apiService.connexion(
        telephone: phone,
        password: password,
      );
      if (mounted) {
        setState(() => _isLoggingIn = false);
        final user = res['user'] as Map<String, dynamic>?;
        final role = (user?['role'] ?? 'CLIENT').toString().toUpperCase();

        await AuthService().saveRole(role);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1D4ED8),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Connecté avec succès en tant que $role ($phone)',
                  ),
                ),
              ],
            ),
          ),
        );

        if (role == 'LIVREUR') {
          context.go('/livreur/missions');
        } else if (role == 'GERANT') {
          context.go('/gerant/tableau-de-bord');
        } else {
          context.go('/');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoggingIn = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur de connexion : $e')));
      }
    }
  }

  Future<void> _handleRegisterSendOtp() async {
    final phone = _registerPhoneController.text.trim();
    final password = _registerPasswordController.text.trim();

    if (phone.length < 9 || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Numéro camerounais (+237 6XX) et mot de passe de 6 caractères minimum requis.',
          ),
        ),
      );
      return;
    }

    setState(() => _isRegistering = true);

    try {
      final result = await _apiService.inscription(
        telephone: phone,
        password: password,
        role: _selectedRole,
      );

      // Envoi du SMS OTP via Firebase Phone Auth
      try {
        PhoneAuthService().sendOtp(
          phoneNumber: phone,
          onCodeSent: (verId) {
            debugPrint('[Firebase PhoneAuth] SMS transmis avec succès, verificationId: $verId');
          },
          onError: (errMsg) {
            debugPrint('[Firebase PhoneAuth] Note envoi : $errMsg');
          },
        );
      } catch (fbErr) {
        debugPrint('[Firebase PhoneAuth] Fallback : $fbErr');
      }

      final smsSent = result['sms_sent'] as bool? ?? true;
      final debugCode = result['otp_code_debug'] as String? ?? '123456';

      if (mounted) {
        setState(() {
          _isRegistering = false;
          _otpSent = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              smsSent
                  ? 'Code OTP envoyé par SMS à $phone'
                  : 'Mode développement — aucun SMS envoyé. Code de test : $debugCode',
            ),
            backgroundColor: smsSent
                ? const Color(0xFF1D4ED8)
                : const Color(0xFFB54708),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRegistering = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'envoi OTP : $e')),
        );
      }
    }
  }

  Future<void> _handleVerifyOtp() async {
    final phone = _registerPhoneController.text.trim();
    final otp = _otpController.text.trim();

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le code OTP doit comporter 6 chiffres.')),
      );
      return;
    }

    setState(() => _isRegistering = true);

    try {
      await _apiService.verifierOTP(telephone: phone, otpCode: otp);
      if (mounted) {
        setState(() => _isRegistering = false);
        if (_selectedRole == 'GERANT') {
          await AuthService().saveRole('GERANT');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.primary,
              content: Text('Compte gérant créé ! Passez à la vérification de vos documents KYC.'),
            ),
          );
          context.go('/gerant/tableau-de-bord');
        } else {
          await AuthService().saveRole('CLIENT');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.primary,
              content: Text('Compte client créé avec succès !'),
            ),
          );
          context.go('/');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRegistering = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur validation OTP : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF102A43),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset('assets/images/gazeo_logo.png', width: 24, height: 24),
            ),
            const SizedBox(width: 8),
            const Text(
              'GAZEO Cameroun',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF1D4ED8),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.login), text: 'Se connecter'),
            Tab(icon: Icon(Icons.person_add_alt_1), text: 'Nouveau compte'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildLoginForm(), _buildRegisterForm()],
      ),
    );
  }

  Widget _buildLoginForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          // En-tête informatif
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF102A43), Color(0xFF243B53)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9735B).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.swap_horiz,
                    color: Color(0xFFF9735B),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Changer ou ouvrir un compte',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Basculez facilement entre compte Client, Livreur ou Gérant de dépôt.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Champs de saisie
          const Text(
            'Numéro de téléphone camerounais',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _loginPhoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🇨🇲', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 6),
                    Text('+237', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              hintText: '690 123 456',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'Mot de passe',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _loginPasswordController,
            obscureText: _loginObscure,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _loginObscure ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _loginObscure = !_loginObscure),
              ),
              hintText: 'Votre mot de passe',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Bouton Connexion
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoggingIn ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isLoggingIn
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Se connecter',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 20),

          // Continuer en mode invité
          Center(
            child: TextButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.explore_outlined, size: 18),
              label: const Text('Continuer sans compte (Mode Invité)'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Créer un compte GAZEO',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Choisissez votre profil pour commencer sur GAZEO.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 20),

          const Text(
            'Vous souhaitez créer un compte :',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 10),

          // Choix de rôle : Client ou Gérant (les livreurs sont créés par les dépôts)
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  avatar: Icon(
                    Icons.person_rounded,
                    color: _selectedRole == 'CLIENT' ? Colors.white : AppColors.primary,
                    size: 18,
                  ),
                  label: const Text('Client'),
                  selected: _selectedRole == 'CLIENT',
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: _selectedRole == 'CLIENT' ? Colors.white : AppColors.slate800,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedRole = 'CLIENT');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  avatar: Icon(
                    Icons.storefront_rounded,
                    color: _selectedRole == 'GERANT' ? Colors.white : AppColors.primary,
                    size: 18,
                  ),
                  label: const Text('Gérant dépôt'),
                  selected: _selectedRole == 'GERANT',
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: _selectedRole == 'GERANT' ? Colors.white : AppColors.slate800,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedRole = 'GERANT');
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Option A : Client -> Choix Inscription Google Rapide ou Numéro
          if (_selectedRole == 'CLIENT') ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _isRegistering ? null : _handleGoogleSignIn,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.slate300, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/google_logo.png', width: 22, height: 22),
                    const SizedBox(width: 12),
                    const Text(
                      'Continuer avec Google',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.slate900,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'OU AVEC VOTRE NUMÉRO',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ],
            ),

            const SizedBox(height: 14),

            const Text(
              'Nom complet',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _registerNomController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person_outline),
                hintText: 'ex: Junior Enama',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),

            const SizedBox(height: 14),
          ],

          // Option B : Gérant -> Informations du Dépôt
          if (_selectedRole == 'GERANT') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.blue50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.blue100),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Inscription Gérant : après validation SMS, vous pourrez soumettre vos pièces KYC (CNI, attestation, photos du dépôt).',
                      style: TextStyle(fontSize: 12, color: AppColors.slate700),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            const Text(
              'Nom du gérant',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _registerNomController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.badge_outlined),
                hintText: 'ex: Junior Enama',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),

            const SizedBox(height: 14),

            const Text(
              'Nom de votre point de vente / dépôt',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _registerDepotController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.storefront_outlined),
                hintText: 'ex: Dépôt Shell Mvog-Ada',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),

            const SizedBox(height: 14),
          ],

          const Text(
            'Numéro de téléphone (+237)',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _registerPhoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.phone),
              hintText: '+237 6XXXXXXXX',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'Mot de passe',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _registerPasswordController,
            obscureText: _registerObscure,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _registerObscure ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () =>
                    setState(() => _registerObscure = !_registerObscure),
              ),
              hintText: 'Minimum 6 caractères',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),

          const SizedBox(height: 20),

          if (!_otpSent)
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isRegistering ? null : _handleRegisterSendOtp,
                icon: const Icon(Icons.sms_outlined),
                label: _isRegistering
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Recevoir le code SMS (OTP)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

          if (_otpSent) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1D4ED8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.mark_email_read, color: Color(0xFF1D4ED8)),
                      SizedBox(width: 8),
                      Text(
                        'Code OTP envoyé',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Saisissez le code à 6 chiffres reçu :'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(
                      letterSpacing: 8,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isRegistering ? null : _handleVerifyOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        _selectedRole == 'GERANT'
                            ? 'Activer et envoyer mes pièces KYC'
                            : 'Activer mon compte & Commencer',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Bannière d'information pour les Livreurs
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.slate200),
            ),
            child: const Row(
              children: [
                Icon(Icons.two_wheeler, color: AppColors.orange, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Vous êtes livreur ? Votre compte est directement créé et configuré par votre dépôt de gaz partenaire.',
                    style: TextStyle(color: AppColors.slate600, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
