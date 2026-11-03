import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gazeo_order_stepper.dart';

/// AppBar blanche commune aux sous-pages du profil.
PreferredSizeWidget _profilAppBar(BuildContext context, String titre) {
  return AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.slate900),
      onPressed: () => gazeoBack(context, fallback: '/compte'),
    ),
    title: Text(titre,
        style: const TextStyle(color: AppColors.slate900, fontSize: 18, fontWeight: FontWeight.w800)),
    centerTitle: true,
  );
}

Widget _carte({required List<Widget> children}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.slate200, width: 0.8),
    ),
    child: Column(children: children),
  );
}

Widget _iconeBleue(IconData icon) => Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: AppColors.blue50, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: AppColors.primary, size: 20),
    );

// ===========================================================================
// Mes adresses
// ===========================================================================
class MesAdressesScreen extends StatefulWidget {
  const MesAdressesScreen({super.key});

  @override
  State<MesAdressesScreen> createState() => _MesAdressesScreenState();
}

class _MesAdressesScreenState extends State<MesAdressesScreen> {
  final List<Map<String, String>> _adresses = [
    {'libelle': 'Maison', 'detail': 'Bastos, face Ambassade de Chine'},
    {'libelle': 'Bureau', 'detail': 'Centre-ville, Immeuble Hilton, 3e étage'},
  ];
  int _parDefaut = 0;

  Future<void> _ajouterAdresse() async {
    final libelle = TextEditingController();
    final detail = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Nouvelle adresse', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(controller: libelle, decoration: const InputDecoration(labelText: 'Nom (ex : Maison)')),
            const SizedBox(height: 12),
            TextField(controller: detail, decoration: const InputDecoration(labelText: 'Quartier et repère')),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
    if (ok == true && detail.text.trim().isNotEmpty) {
      setState(() => _adresses.add({
            'libelle': libelle.text.trim().isEmpty ? 'Adresse' : libelle.text.trim(),
            'detail': detail.text.trim(),
          }));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _profilAppBar(context, 'Mes adresses'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ajouterAdresse,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Ajouter'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _adresses.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final a = _adresses[i];
          final defaut = i == _parDefaut;
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: defaut ? AppColors.primary : AppColors.slate200, width: defaut ? 1.5 : 0.8),
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                onTap: () => setState(() => _parDefaut = i),
                leading: _iconeBleue(i == 0 ? Icons.home_outlined : Icons.location_on_outlined),
                title: Text(a['libelle']!, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(a['detail']!, style: const TextStyle(fontSize: 12)),
                trailing: defaut
                    ? const Chip(
                        label: Text('Par défaut', style: TextStyle(color: AppColors.primary, fontSize: 10)),
                        backgroundColor: AppColors.blue50,
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                      )
                    : IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.error),
                        onPressed: () => setState(() {
                          _adresses.removeAt(i);
                          if (_parDefaut > i) _parDefaut--;
                        }),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ===========================================================================
// Notifications
// ===========================================================================
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<Map<String, dynamic>> _notifs = [
    {'icon': Icons.two_wheeler, 'titre': 'Votre livreur est en route', 'texte': 'Yao Patrick arrive dans 15 min avec votre bouteille 12.5 kg.', 'heure': 'Il y a 5 min', 'lu': false},
    {'icon': Icons.check_circle_outline, 'titre': 'Commande confirmée', 'texte': 'Depot Shell Mvog-Ada a accepté votre commande #GAZ-2026-1048.', 'heure': 'Il y a 20 min', 'lu': false},
    {'icon': Icons.stars_rounded, 'titre': '+25 points fidélité', 'texte': 'Merci pour votre commande ! Votre solde est de 125 points.', 'heure': 'Hier', 'lu': true},
    {'icon': Icons.inventory_2_outlined, 'titre': 'Stock disponible', 'texte': 'Gaz Plus Bastos a de nouveau des bouteilles de 22 kg.', 'heure': 'Il y a 2 jours', 'lu': true},
  ];

  @override
  Widget build(BuildContext context) {
    final nonLues = _notifs.where((n) => n['lu'] == false).length;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _profilAppBar(context, 'Notifications'),
      body: _notifs.isEmpty
          ? const Center(child: Text('Aucune notification', style: TextStyle(color: AppColors.slate500)))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$nonLues non lue${nonLues > 1 ? 's' : ''}',
                        style: const TextStyle(color: AppColors.slate600, fontWeight: FontWeight.w600)),
                    TextButton(
                      onPressed: nonLues == 0
                          ? null
                          : () => setState(() {
                                for (final n in _notifs) {
                                  n['lu'] = true;
                                }
                              }),
                      child: const Text('Tout marquer comme lu'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final n in _notifs) ...[
                  Dismissible(
                    key: ValueKey(n['titre']),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => setState(() => _notifs.remove(n)),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.delete_outline, color: Colors.white),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: n['lu'] == true ? Colors.white : AppColors.blue50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.slate200, width: 0.8),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          onTap: () => setState(() => n['lu'] = true),
                          leading: _iconeBleue(n['icon'] as IconData),
                          title: Text(n['titre'] as String,
                              style: TextStyle(
                                  fontWeight: n['lu'] == true ? FontWeight.w600 : FontWeight.w800, fontSize: 14)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(n['texte'] as String, style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(n['heure'] as String,
                                  style: const TextStyle(fontSize: 11, color: AppColors.slate400)),
                            ],
                          ),
                          trailing: n['lu'] == true
                              ? null
                              : Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

// ===========================================================================
// Aide & Support
// ===========================================================================
class AideSupportScreen extends StatelessWidget {
  const AideSupportScreen({super.key});

  static const _faq = [
    ['Comment passer une commande ?', 'Choisissez un dépôt sur la carte, sélectionnez la taille de bouteille, indiquez votre adresse puis payez par Orange Money, MTN MoMo ou à la livraison.'],
    ['Quels sont les frais de livraison ?', 'La livraison à domicile coûte 1 000 FCFA dans Yaoundé. Le retrait au dépôt est gratuit.'],
    ['À quoi sert le code de confirmation ?', 'Donnez ce code au livreur uniquement quand vous avez reçu votre bouteille. Il garantit que la livraison a bien été effectuée.'],
    ['Puis-je annuler ma commande ?', 'Oui, tant que le vendeur ne l\'a pas encore acceptée, depuis l\'écran d\'attente de validation.'],
    ['Comment gagner des points fidélité ?', 'Chaque commande livrée vous rapporte des points, échangeables contre des réductions.'],
  ];

  Future<void> _ouvrir(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(const SnackBar(content: Text('Impossible d\'ouvrir ce lien.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _profilAppBar(context, 'Aide & Support'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Nous contacter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _carte(children: [
            ListTile(
              leading: _iconeBleue(Icons.phone_outlined),
              title: const Text('Appeler le service client', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('7j/7 • 7h - 22h'),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.slate400),
              onTap: () => _ouvrir(context, Uri.parse('tel:+237690000000')),
            ),
            const Divider(height: 1, indent: 70, color: AppColors.slate100),
            ListTile(
              leading: _iconeBleue(Icons.chat_outlined),
              title: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Réponse en moins de 10 min'),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.slate400),
              onTap: () => _ouvrir(context, Uri.parse('https://wa.me/237690000000')),
            ),
            const Divider(height: 1, indent: 70, color: AppColors.slate100),
            ListTile(
              leading: _iconeBleue(Icons.mail_outline),
              title: const Text('E-mail', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('support@gazeo.cm'),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.slate400),
              onTap: () => _ouvrir(context, Uri.parse('mailto:support@gazeo.cm?subject=Aide GAZEO')),
            ),
          ]),
          const SizedBox(height: 24),
          const Text('Questions fréquentes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _carte(children: [
            for (var i = 0; i < _faq.length; i++) ...[
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  iconColor: AppColors.primary,
                  title: Text(_faq[i][0], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(_faq[i][1], style: const TextStyle(color: AppColors.slate600, height: 1.4))],
                ),
              ),
              if (i < _faq.length - 1) const Divider(height: 1, color: AppColors.slate100),
            ],
          ]),
        ],
      ),
    );
  }
}

// ===========================================================================
// Paramètres
// ===========================================================================
class ParametresScreen extends StatefulWidget {
  const ParametresScreen({super.key});

  @override
  State<ParametresScreen> createState() => _ParametresScreenState();
}

class _ParametresScreenState extends State<ParametresScreen> {
  bool _pushCommandes = true;
  bool _promos = false;
  bool _sms = true;
  bool _localisation = true;
  String _langue = 'Français';

  Widget _switch(String titre, String sous, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      secondary: _iconeBleue(icon),
      title: Text(titre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(sous, style: const TextStyle(fontSize: 12)),
      value: value,
      activeThumbColor: Colors.white,
      activeTrackColor: AppColors.primary,
      onChanged: onChanged,
    );
  }

  Future<void> _deconnexion() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text('Vous devrez vous reconnecter pour passer commande.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Déconnexion', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService().deconnexion();
    } catch (_) {}
    if (mounted) context.go('/choix-compte');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _profilAppBar(context, 'Paramètres'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _carte(children: [
            _switch('Suivi des commandes', 'Statut, livreur, arrivée', Icons.notifications_active_outlined,
                _pushCommandes, (v) => setState(() => _pushCommandes = v)),
            const Divider(height: 1, indent: 70, color: AppColors.slate100),
            _switch('Offres et promotions', 'Réductions des dépôts', Icons.local_offer_outlined, _promos,
                (v) => setState(() => _promos = v)),
            const Divider(height: 1, indent: 70, color: AppColors.slate100),
            _switch('SMS', 'Code de confirmation par SMS', Icons.sms_outlined, _sms,
                (v) => setState(() => _sms = v)),
          ]),
          const SizedBox(height: 24),
          const Text('Préférences', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _carte(children: [
            _switch('Localisation', 'Trouver les dépôts proches', Icons.my_location_outlined, _localisation,
                (v) => setState(() => _localisation = v)),
            const Divider(height: 1, indent: 70, color: AppColors.slate100),
            ListTile(
              leading: _iconeBleue(Icons.language_outlined),
              title: const Text('Langue', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              trailing: DropdownButton<String>(
                value: _langue,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'Français', child: Text('Français')),
                  DropdownMenuItem(value: 'English', child: Text('English')),
                ],
                onChanged: (v) => setState(() => _langue = v ?? _langue),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          const Text('Compte', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _carte(children: [
            ListTile(
              leading: _iconeBleue(Icons.swap_horiz),
              title: const Text('Changer de profil', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text('Client, gérant ou livreur', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.slate400),
              onTap: () => context.push('/choix-compte'),
            ),
            const Divider(height: 1, indent: 70, color: AppColors.slate100),
            ListTile(
              leading: _iconeBleue(Icons.info_outline),
              title: const Text('À propos de GAZEO', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              trailing: const Text('v1.0.0', style: TextStyle(color: AppColors.slate400)),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'GAZEO',
                applicationVersion: '1.0.0',
                applicationLegalese: 'Livraison de gaz domestique à Yaoundé.',
              ),
            ),
            const Divider(height: 1, indent: 70, color: AppColors.slate100),
            ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.logout, color: AppColors.error, size: 20),
              ),
              title: const Text('Se déconnecter',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.error)),
              onTap: _deconnexion,
            ),
          ]),
        ],
      ),
    );
  }
}

