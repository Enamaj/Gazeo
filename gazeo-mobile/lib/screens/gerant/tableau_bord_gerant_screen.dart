import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../services/location_service.dart';

class TableauBordGerantScreen extends StatefulWidget {
  const TableauBordGerantScreen({super.key});

  @override
  State<TableauBordGerantScreen> createState() =>
      _TableauBordGerantScreenState();
}

class _TableauBordGerantScreenState extends State<TableauBordGerantScreen> {
  static const _green = Color(0xFF155E75);
  static const _ink = Color(0xFF102A43);
  static const _canvas = Color(0xFFF4F7FA);

  final ApiService _apiService = ApiService();
  final Geocoding _geocoding = Geocoding();
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'fr_FR');
  final _price6Controller = TextEditingController();
  final _price12Controller = TextEditingController();
  final _stock6Controller = TextEditingController();
  final _stock12Controller = TextEditingController();
  final _depotNameController = TextEditingController();
  final _depotAddressController = TextEditingController();
  final _depotNeighborhoodController = TextEditingController();
  final Map<String, PlatformFile> _kycFiles = {};
  final Set<String> _selectedBrands = {};
  PlatformFile? _depotImageFile;
  double? _depotLatitude;
  double? _depotLongitude;

  Map<String, dynamic>? _depot;
  List<Map<String, dynamic>> _commandes = [];
  Map<String, dynamic>? _kyc;
  bool _isLoading = true;
  bool _isSavingPrices = false;
  bool _isSavingStock = false;
  bool _isSubmittingKyc = false;
  bool _isSavingDepotProfile = false;
  bool _isLocatingDepot = false;
  bool _isNotifyingRestock = false;
  int? _updatingOrderId;
  String? _errorMessage;

  final List<Map<String, dynamic>> _depotLivreurs = [
    {
      'id': 1,
      'nom': 'Yao Patrick',
      'telephone': '+237 6 56 78 90 12',
      'moto': 'Yamaha 125 • LT-452-CE',
      'actif': true,
      'courses_aujourdhui': 4,
    },
    {
      'id': 2,
      'nom': 'Mamadou Bello',
      'telephone': '+237 6 99 12 34 56',
      'moto': 'Bajaj Boxer • CE-891-AB',
      'actif': false,
      'courses_aujourdhui': 0,
    },
  ];

  static const _kycDocuments = <String, String>{
    'cni_recto': 'CNI — recto',
    'cni_verso': 'CNI — verso',
    'photo_depot': 'Photo du dépôt — façade',
    'photo_depot_interieur': 'Photo du dépôt — intérieur',
    'document_commercial': 'Registre de commerce ou attestation d’activité',
  };
  static const _depotBrands = <String, String>{
    'TRADEX': 'Tradex',
    'SCTM': 'SCTM',
    'TOTAL': 'TotalEnergies',
    'CAMGAZ': 'Camgaz',
    'AUTRE': 'Autre',
  };

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  @override
  void dispose() {
    _price6Controller.dispose();
    _price12Controller.dispose();
    _stock6Controller.dispose();
    _stock12Controller.dispose();
    _depotNameController.dispose();
    _depotAddressController.dispose();
    _depotNeighborhoodController.dispose();
    super.dispose();
  }

  Future<void> _chargerDonnees() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final depot = await _apiService.getGerantMonDepot();
      final commandes = await _apiService.getGerantCommandes();
      if (!mounted) return;
      setState(() {
        _depot = depot;
        _commandes = commandes;
        _kyc = null;
        _isLoading = false;
      });
      _remplirFormulaires(depot);
      _remplirProfilDepot(depot);
    } on DioException catch (error) {
      if (!mounted) return;
      if (error.response?.statusCode == 404) {
        try {
          final kyc = await _apiService.getGerantKycStatut();
          if (!mounted) return;
          setState(() {
            _depot = null;
            _kyc = kyc;
            _isLoading = false;
          });
        } on DioException catch (kycError) {
          if (!mounted) return;
          setState(() {
            _errorMessage = _messageErreur(kycError);
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = _messageErreur(error);
          _isLoading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Impossible de charger votre espace gérant. Vérifiez votre connexion.';
        _isLoading = false;
      });
    }
  }

  String _messageErreur(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode == 400) {
      final data = error.response?.data;
      if (data is Map) {
        final messages = data.values
            .expand((value) => value is List ? value : [value])
            .map((value) => value.toString())
            .where((value) => value.isNotEmpty)
            .toList();
        if (messages.isNotEmpty) return messages.join('\n');
      }
      return 'Vérifiez les informations et les documents saisis.';
    }
    if (statusCode == 409) {
      return 'Votre dossier est déjà en cours de vérification ou a été validé.';
    }
    if (statusCode == 403) {
      final detail = error.response?.data is Map
          ? (error.response!.data as Map)['detail']?.toString()
          : null;
      if (detail != null && detail.isNotEmpty) return detail;
    }
    if (statusCode == 401 || statusCode == 403) {
      return 'Votre session a expiré ou votre compte n’a pas le rôle gérant. '
          'Reconnectez-vous avec le bon compte.';
    }
    return 'Le service est momentanément indisponible. Réessayez dans quelques instants.';
  }

  void _remplirProfilDepot(Map<String, dynamic> depot) {
    _depotNameController.text = _valeur(depot['nom']);
    _depotAddressController.text = _valeur(depot['adresse']);
    _depotNeighborhoodController.text = _valeur(depot['quartier']);
    _depotLatitude = (depot['latitude'] as num?)?.toDouble();
    _depotLongitude = (depot['longitude'] as num?)?.toDouble();
    _selectedBrands
      ..clear()
      ..addAll(
        (depot['marques_disponibles'] as List<dynamic>?)
                ?.map((value) => value.toString())
                .where(_depotBrands.containsKey) ??
            [depot['marque']?.toString() ?? 'TRADEX'],
      );
  }

  Future<void> _choisirImageDepot() async {
    final files = await FilePicker.pickFiles(
      type: FileType.image,
      allowedExtensions: const ['jpg', 'jpeg', 'png'],
    );
    if (files.isEmpty || !mounted) return;
    final file = files.single;
    final length = await file.length();
    if (length == null || length == 0) {
      _notifier('Impossible de lire cette image.', isError: true);
      return;
    }
    if (length > 10 * 1024 * 1024) {
      _notifier('L’image du dépôt doit faire 10 Mo maximum.', isError: true);
      return;
    }
    setState(() => _depotImageFile = file);
  }

  Future<void> _utiliserPositionDepot() async {
    setState(() => _isLocatingDepot = true);
    try {
      final position = await LocationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _depotLatitude = position.latitude;
        _depotLongitude = position.longitude;
      });
      final placemarks = await _geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      if (placemarks.isEmpty) {
        throw StateError('Aucun quartier n’a pu être trouvé à cette position.');
      }
      final place = placemarks.first;
      final quartier =
          [
            place.subLocality,
            place.locality,
            place.subAdministrativeArea,
            place.administrativeArea,
          ].whereType<String>().firstWhere(
            (value) => value.trim().isNotEmpty,
            orElse: () => '',
          );
      setState(() {
        if (quartier.isNotEmpty) _depotNeighborhoodController.text = quartier;
        final address = [place.street, place.name]
            .whereType<String>()
            .where((value) => value.trim().isNotEmpty)
            .toSet()
            .join(', ');
        if (address.isNotEmpty) _depotAddressController.text = address;
        _isLocatingDepot = false;
      });
      _notifier(
        quartier.isEmpty
            ? 'Position enregistrée. Saisissez le quartier manuellement.'
            : 'Position enregistrée et quartier détecté : $quartier.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLocatingDepot = false);
      _notifier('Impossible de détecter le quartier : $error', isError: true);
    }
  }

  Future<void> _enregistrerProfilDepot() async {
    final creation = _depot == null;
    if (_depotNameController.text.trim().isEmpty ||
        _depotAddressController.text.trim().isEmpty ||
        _depotNeighborhoodController.text.trim().isEmpty ||
        (creation && _selectedBrands.isEmpty) ||
        _depotLatitude == null ||
        _depotLongitude == null ||
        (creation && _depotImageFile == null)) {
      _notifier(
        'Renseignez le nom, l’adresse, le quartier, la position, la photo et au moins une marque.',
        isError: true,
      );
      return;
    }

    setState(() => _isSavingDepotProfile = true);
    try {
      await _apiService.enregistrerProfilDepotGerant(
        creation: creation,
        imageDepot: _depotImageFile,
        profil: {
          'nom': _depotNameController.text.trim(),
          'adresse': _depotAddressController.text.trim(),
          'quartier': _depotNeighborhoodController.text.trim(),
          'marques_disponibles': _selectedBrands.toList(),
          'latitude': _depotLatitude,
          'longitude': _depotLongitude,
        },
      );
      if (!mounted) return;
      setState(() {
        _isSavingDepotProfile = false;
        _depotImageFile = null;
      });
      await _chargerDonnees();
      if (mounted) {
        _notifier(
          creation
              ? 'Votre dépôt est configuré et visible pour les clients.'
              : 'Les informations du dépôt ont été mises à jour.',
        );
      }
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() => _isSavingDepotProfile = false);
      _notifier(_messageErreur(error), isError: true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSavingDepotProfile = false);
      _notifier('Impossible d’enregistrer le dépôt : $error', isError: true);
    }
  }

  Future<void> _signalerRetourStock() async {
    setState(() => _isNotifyingRestock = true);
    try {
      final result = await _apiService.notifierRetourStockGerant();
      if (!mounted) return;
      setState(() => _isNotifyingRestock = false);
      final targets = result['clients_cibles'] as int? ?? 0;
      final sent = result['notifications_envoyees'] as int? ?? 0;
      _notifier(
        targets == 0
            ? 'Aucun ancien client de ce dépôt à prévenir pour le moment.'
            : sent == 0
            ? 'Le stock est visible, mais aucune notification n’a pu être distribuée. Vérifiez la configuration des notifications.'
            : 'Alerte de retour en stock envoyée à $sent client${sent > 1 ? 's' : ''}.',
        isError: targets > 0 && sent == 0,
      );
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() => _isNotifyingRestock = false);
      _notifier(_messageErreur(error), isError: true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isNotifyingRestock = false);
      _notifier('Impossible de prévenir les clients : $error', isError: true);
    }
  }

  Future<void> _choisirDocument(
    String field, {
    required List<String> extensions,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    if (result.isEmpty || !mounted) return;

    final file = result.single;
    final fileSize = await file.length();
    if (fileSize == null) {
      _notifier(
        'Impossible de lire ce fichier. Choisissez-en un autre.',
        isError: true,
      );
      return;
    }
    if (fileSize > 10 * 1024 * 1024) {
      _notifier('Chaque document doit faire 10 Mo maximum.', isError: true);
      return;
    }
    setState(() => _kycFiles[field] = file);
  }

  Future<void> _soumettreDossierKyc() async {
    if (_kycFiles.length != _kycDocuments.length) {
      _notifier('Veuillez ajouter tous les documents demandés.', isError: true);
      return;
    }

    setState(() => _isSubmittingKyc = true);
    try {
      await _apiService.soumettreDossierKycGerant(
        cniRecto: _kycFiles['cni_recto']!,
        cniVerso: _kycFiles['cni_verso']!,
        photoDepot: _kycFiles['photo_depot']!,
        photoDepotInterieur: _kycFiles['photo_depot_interieur']!,
        documentCommercial: _kycFiles['document_commercial']!,
      );
      if (!mounted) return;
      setState(() {
        _isSubmittingKyc = false;
        _kycFiles.clear();
      });
      await _chargerDonnees();
      if (mounted) _notifier('Dossier envoyé. La vérification est en cours.');
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() => _isSubmittingKyc = false);
      _notifier(_messageErreur(error), isError: true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmittingKyc = false);
      _notifier('Impossible d’envoyer votre dossier : $error', isError: true);
    }
  }

  void _remplirFormulaires(Map<String, dynamic> depot) {
    _price6Controller.text = _valeur(depot['prix_6kg']);
    _price12Controller.text = _valeur(depot['prix_12kg']);
    _stock6Controller.text = _valeur(depot['stock_6kg']);
    _stock12Controller.text = _valeur(depot['stock_12kg']);
  }

  String _valeur(dynamic value) => value?.toString() ?? '';

  Future<void> _enregistrerTarifs() async {
    final prix6 = double.tryParse(_price6Controller.text.trim());
    final prix12 = double.tryParse(_price12Controller.text.trim());
    if (prix6 == null || prix12 == null || prix6 <= 0 || prix12 <= 0) {
      _notifier(
        'Saisissez des prix valides et supérieurs à zéro.',
        isError: true,
      );
      return;
    }

    setState(() => _isSavingPrices = true);
    try {
      final depot = await _apiService.mettreAJourTarifsGerant(
        prix6kg: prix6,
        prix12kg: prix12,
      );
      if (!mounted) return;
      setState(() {
        _depot = depot;
        _isSavingPrices = false;
      });
      _remplirFormulaires(depot);
      _remplirProfilDepot(depot);
      _notifier('Tarifs mis à jour.');
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() => _isSavingPrices = false);
      _notifier(_messageErreur(error), isError: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSavingPrices = false);
      _notifier('La mise à jour des tarifs a échoué.', isError: true);
    }
  }

  Future<void> _enregistrerStock() async {
    final stock6 = int.tryParse(_stock6Controller.text.trim());
    final stock12 = int.tryParse(_stock12Controller.text.trim());
    if (stock6 == null || stock12 == null || stock6 < 0 || stock12 < 0) {
      _notifier(
        'Saisissez des quantités entières positives ou nulles.',
        isError: true,
      );
      return;
    }

    setState(() => _isSavingStock = true);
    try {
      await _apiService.mettreAJourStockGerant(
        stock6kg: stock6,
        stock12kg: stock12,
      );
      final depot = await _apiService.getGerantMonDepot();
      if (!mounted) return;
      setState(() {
        _depot = depot;
        _isSavingStock = false;
      });
      _remplirFormulaires(depot);
      _notifier('Stocks mis à jour.');
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() => _isSavingStock = false);
      _notifier(_messageErreur(error), isError: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSavingStock = false);
      _notifier('La mise à jour du stock a échoué.', isError: true);
    }
  }

  Future<void> _accepterCommande(int commandeId) async {
    setState(() => _updatingOrderId = commandeId);
    try {
      await _apiService.accepterCommandeGerant(commandeId);
      if (!mounted) return;
      setState(() => _updatingOrderId = null);
      await _chargerDonnees();
      if (mounted) _notifier('Commande #$commandeId acceptée.');
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() => _updatingOrderId = null);
      _notifier(_messageErreur(error), isError: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _updatingOrderId = null);
      _notifier(
        'Impossible d’accepter la commande #$commandeId.',
        isError: true,
      );
    }
  }

  void _notifier(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? const Color(0xFFB42318) : _ink,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
        title: const Text('Espace gérant'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _isLoading ? null : _chargerDonnees,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Carte des dépôts',
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.map_outlined),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErreur()
          : _depot == null
          ? _buildAucunDepot()
          : _buildTableauDeBord(),
    );
  }

  Widget _buildErreur() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 52, color: Colors.grey),
            const SizedBox(height: 14),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _chargerDonnees,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAucunDepot() {
    final status = _kyc?['statut']?.toString() ?? 'NON_SOUMIS';
    final message = switch (status) {
      'EN_ATTENTE' => 'Votre dossier est en cours de vérification.',
      'REJETE' =>
        'Votre dossier a été rejeté. Consultez le motif ci-dessous, corrigez '
            'les pièces concernées, puis soumettez-le à nouveau.',
      'VALIDE' =>
        'Votre dossier est validé, mais aucun dépôt n’est encore '
            'associé à votre compte. Notre équipe doit encore rattacher votre dépôt.',
      _ =>
        'Complétez votre dossier de vérification pour que GAZEO puisse étudier '
            'votre demande de gérant.',
    };

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 20),
        Icon(
          status == 'EN_ATTENTE'
              ? Icons.hourglass_top_rounded
              : status == 'VALIDE'
              ? Icons.verified_outlined
              : Icons.store_mall_directory_outlined,
          size: 58,
          color: _green,
        ),
        const SizedBox(height: 18),
        const Text(
          'Votre espace dépôt',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 18),
        Center(
          child: Chip(
            avatar: const Icon(Icons.verified_user_outlined, size: 18),
            label: Text('Dossier : ${_libelleStatut(status)}'),
            backgroundColor: Colors.white,
          ),
        ),
        if (_kyc?['date_soumission'] != null) ...[
          const SizedBox(height: 4),
          Text(
            'Dernier envoi : ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.parse(_kyc!['date_soumission'].toString()).toLocal())}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ],
        if (_kyc?['raison_rejet'] != null) ...[
          const SizedBox(height: 10),
          Card(
            color: const Color(0xFFFFF4F2),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFB42318)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _kyc!['raison_rejet'].toString(),
                      style: const TextStyle(color: Color(0xFF8F241B)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (status == 'EN_ATTENTE') ...[
          const SizedBox(height: 8),
          _buildKycInfoCard(
            Icons.schedule_outlined,
            'Délai indicatif : 24 à 48 heures ouvrables. '
            'Le statut de votre dossier sera actualisé ici.',
          ),
        ],
        if (status == 'VALIDE') ...[
          const SizedBox(height: 20),
          _buildDepotProfileForm(creation: true),
        ],
        if (status == 'NON_SOUMIS' || status == 'REJETE') ...[
          const SizedBox(height: 20),
          _buildKycUploadForm(),
        ],
      ],
    );
  }

  Widget _buildKycInfoCard(IconData icon, String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _green),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  Widget _buildDepotProfileForm({required bool creation}) {
    final imageUrl = _depot?['image_depot_url']?.toString();
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            creation ? 'Configurez votre dépôt' : 'Informations du dépôt',
            creation
                ? 'Renseignez les informations visibles par les clients.'
                : 'Maintenez votre fiche à jour pour vos clients.',
            Icons.storefront_outlined,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _depotNameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nom du dépôt',
              prefixIcon: Icon(Icons.store_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _depotAddressController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Adresse ou repère',
              prefixIcon: Icon(Icons.signpost_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _depotNeighborhoodController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Quartier',
              prefixIcon: Icon(Icons.location_city_outlined),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _isLocatingDepot ? null : _utiliserPositionDepot,
            icon: _isLocatingDepot
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_outlined),
            label: Text(
              _depotLatitude == null
                  ? 'Utiliser ma position GPS pour le quartier'
                  : 'Position du dépôt enregistrée — modifier',
            ),
          ),
          if (_depotLatitude != null && _depotLongitude != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'GPS : ${_depotLatitude!.toStringAsFixed(5)}, ${_depotLongitude!.toStringAsFixed(5)}',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'Marques de bouteilles disponibles',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _depotBrands.entries.map((entry) {
              final selected = _selectedBrands.contains(entry.key);
              return FilterChip(
                label: Text(entry.value),
                selected: selected,
                onSelected: _isSavingDepotProfile
                    ? null
                    : (value) => setState(() {
                        if (value) {
                          _selectedBrands.add(entry.key);
                        } else {
                          _selectedBrands.remove(entry.key);
                        }
                      }),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          if (_depotImageFile != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.image_outlined, color: _green),
              title: const Text('Nouvelle photo sélectionnée'),
              subtitle: Text(
                _depotImageFile!.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                imageUrl,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 90,
                  color: _canvas,
                  alignment: Alignment.center,
                  child: const Text('Photo du dépôt indisponible'),
                ),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isSavingDepotProfile ? null : _choisirImageDepot,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(
              _depotImageFile != null || imageUrl != null
                  ? 'Choisir une autre photo du dépôt'
                  : 'Ajouter une photo du dépôt',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isSavingDepotProfile ? null : _enregistrerProfilDepot,
            icon: _isSavingDepotProfile
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _isSavingDepotProfile
                  ? 'Enregistrement…'
                  : creation
                  ? 'Créer mon dépôt'
                  : 'Enregistrer les informations',
            ),
            style: FilledButton.styleFrom(backgroundColor: _green),
          ),
        ],
      ),
    );
  }

  Widget _buildKycUploadForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Documents à fournir',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ajoutez les deux photos du dépôt ainsi que des fichiers lisibles (JPG, PNG ou PDF pour le document commercial), 10 Mo maximum chacun.',
            ),
            const SizedBox(height: 12),
            ..._kycDocuments.entries.map((entry) {
              final file = _kycFiles[entry.key];
              final extensions = entry.key == 'document_commercial'
                  ? const ['pdf', 'jpg', 'jpeg', 'png']
                  : const ['jpg', 'jpeg', 'png'];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: OutlinedButton.icon(
                  onPressed: _isSubmittingKyc
                      ? null
                      : () =>
                            _choisirDocument(entry.key, extensions: extensions),
                  icon: Icon(
                    file == null
                        ? Icons.upload_file_outlined
                        : Icons.check_circle_outline,
                  ),
                  label: Text(
                    file == null ? entry.value : '${entry.value}\n${file.name}',
                    textAlign: TextAlign.left,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            _buildKycInfoCard(
              Icons.verified_user_outlined,
              'Votre numéro de téléphone a été vérifié par OTP. '
              'Les pièces sont transmises à GAZEO pour examen.',
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed:
                  _isSubmittingKyc || _kycFiles.length != _kycDocuments.length
                  ? null
                  : _soumettreDossierKyc,
              icon: _isSubmittingKyc
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(
                _isSubmittingKyc ? 'Envoi en cours…' : 'Soumettre le dossier',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableauDeBord() {
    final depot = _depot!;
    final pendingCount = _commandes
        .where((c) => c['statut'] == 'EN_ATTENTE')
        .length;
    final rating = (depot['note_moyenne'] as num?)?.toDouble() ?? 0;
    final reviewCount = (depot['total_avis'] as num?)?.toInt() ?? 0;
    final reviews = depot['derniers_avis'] as List<dynamic>? ?? [];

    return RefreshIndicator(
      onRefresh: _chargerDonnees,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildDepotHeader(depot),
          const SizedBox(height: 14),
          _buildDepotProfileForm(creation: false),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildStat(
                  icon: Icons.receipt_long_outlined,
                  title: 'Commandes',
                  value: '${_commandes.length}',
                  subtitle: '$pendingCount en attente',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStat(
                  icon: Icons.star_outline_rounded,
                  title: 'Avis clients',
                  value: rating.toStringAsFixed(1),
                  subtitle: '$reviewCount avis',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildStockSection(depot),
          const SizedBox(height: 14),
          _buildPricesSection(),
          const SizedBox(height: 14),
          _buildOrdersSection(),
          const SizedBox(height: 14),
          _buildLivreursSection(),
          const SizedBox(height: 14),
          _buildReviewsSection(reviews),
        ],
      ),
    );
  }

  Widget _buildDepotHeader(Map<String, dynamic> depot) {
    final name = depot['nom']?.toString() ?? 'Mon dépôt';
    final quartier = depot['quartier']?.toString() ?? '';
    final active = depot['est_actif'] == true;
    final kycStatus = depot['statut_kyc']?.toString() ?? 'EN_ATTENTE';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_green, Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _green.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    if (quartier.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        quartier,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _headerBadge(
                active ? 'Visible aux clients' : 'Non visible',
                active
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              _headerBadge(_libelleStatut(kycStatus), Icons.verified_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerBadge(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStat({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return _SectionCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: _green),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockSection(Map<String, dynamic> depot) {
    final total =
        ((depot['stock_6kg'] as num?)?.toInt() ?? 0) +
        ((depot['stock_12kg'] as num?)?.toInt() ?? 0);
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            'Disponibilité du stock',
            'Le stock réel est partagé avec les clients.',
            Icons.inventory_2_outlined,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _numberField(
                  controller: _stock6Controller,
                  label: 'Bouteilles 6 kg',
                  suffix: 'unités',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _numberField(
                  controller: _stock12Controller,
                  label: 'Bouteilles 12,5 kg',
                  suffix: 'unités',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$total bouteille${total > 1 ? 's' : ''} disponible${total > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _isSavingStock ? null : _enregistrerStock,
                icon: _isSavingStock
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: const Text('Enregistrer'),
                style: FilledButton.styleFrom(backgroundColor: _green),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isNotifyingRestock ? null : _signalerRetourStock,
                icon: _isNotifyingRestock
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.notifications_active_outlined),
                label: Text(
                  _isNotifyingRestock
                      ? 'Notification en cours…'
                      : 'Signaler le retour du stock aux clients',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPricesSection() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            'Tarifs du dépôt',
            'Prix affichés aux clients, en FCFA.',
            Icons.sell_outlined,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _numberField(
                  controller: _price6Controller,
                  label: 'Bouteille 6 kg',
                  suffix: 'FCFA',
                  allowDecimal: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _numberField(
                  controller: _price12Controller,
                  label: 'Bouteille 12,5 kg',
                  suffix: 'FCFA',
                  allowDecimal: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _isSavingPrices ? null : _enregistrerTarifs,
              icon: _isSavingPrices
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Enregistrer les tarifs'),
              style: FilledButton.styleFrom(backgroundColor: _green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    bool allowDecimal = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          allowDecimal ? RegExp(r'^\d*\.?\d{0,2}') : RegExp(r'\d*'),
        ),
      ],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        filled: true,
        fillColor: const Color(0xFFF4F7FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
      ),
    );
  }

  Widget _buildOrdersSection() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            'Commandes reçues',
            'Suivi des commandes associées à votre dépôt.',
            Icons.receipt_long_outlined,
          ),
          const SizedBox(height: 12),
          if (_commandes.isEmpty)
            const _EmptyNotice(
              icon: Icons.inbox_outlined,
              message: 'Aucune commande reçue pour le moment.',
            )
          else
            ..._commandes.map(_buildOrder),
        ],
      ),
    );
  }

  Widget _buildOrder(Map<String, dynamic> order) {
    final id = order['id']?.toString() ?? '—';
    final status = order['statut']?.toString() ?? 'INCONNU';
    final q6 = (order['quantite_6kg'] as num?)?.toInt() ?? 0;
    final q12 = (order['quantite_12kg'] as num?)?.toInt() ?? 0;
    final total =
        double.tryParse(order['montant_total']?.toString() ?? '') ?? 0;
    final phone = order['client_telephone']?.toString() ?? '';
    final clientName = order['client_nom']?.toString() ?? 'Client';
    final address = order['adresse_livraison']?.toString() ?? '';
    final canAccept = status == 'EN_ATTENTE';
    final isUpdating = _updatingOrderId == int.tryParse(id);
    final createdAt = DateTime.tryParse(order['created_at']?.toString() ?? '');
    final quantityLabel = [
      if (q6 > 0) '$q6× 6 kg',
      if (q12 > 0) '$q12× 12,5 kg',
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EEEB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Commande #$id',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              _statusBadge(status),
            ],
          ),
          const SizedBox(height: 8),
          Text(clientName, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              phone,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
          if (address.isNotEmpty) ...[
            const SizedBox(height: 8),
            _iconText(Icons.location_on_outlined, address),
          ],
          if (quantityLabel.isNotEmpty) ...[
            const SizedBox(height: 6),
            _iconText(Icons.shopping_bag_outlined, quantityLabel),
          ],
          const Divider(height: 18),
          Row(
            children: [
              if (createdAt != null)
                Expanded(
                  child: Text(
                    '${createdAt.toLocal().day.toString().padLeft(2, '0')}/'
                    '${createdAt.toLocal().month.toString().padLeft(2, '0')}/'
                    '${createdAt.toLocal().year}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                )
              else
                const Spacer(),
              Text(
                '${_currencyFormat.format(total)} FCFA',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ],
          ),
          if (canAccept) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isUpdating
                    ? null
                    : () => _accepterCommande(int.parse(id)),
                icon: isUpdating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Accepter cette commande'),
                style: FilledButton.styleFrom(backgroundColor: _green),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = switch (status) {
      'LIVREE' => const Color(0xFF16803C),
      'ANNULEE' => const Color(0xFFB42318),
      'EN_ATTENTE' => const Color(0xFFB54708),
      _ => const Color(0xFF475467),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _libelleStatut(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildLivreursSection() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _sectionHeading(
                  'Mes livreurs affiliés (${_depotLivreurs.length})',
                  'Comptes livreurs créés et rattachés à votre dépôt.',
                  Icons.two_wheeler_rounded,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAjouterLivreurDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Ajouter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_depotLivreurs.isEmpty)
            const _EmptyNotice(
              icon: Icons.two_wheeler_outlined,
              message: 'Aucun livreur associé à ce dépôt pour l’instant.',
            )
          else
            ..._depotLivreurs.map((l) {
              final bool estActif = l['actif'] as bool? ?? false;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: estActif ? Colors.white : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: estActif ? const Color(0xFFE8EEEB) : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: estActif ? const Color(0xFFEFF6FF) : Colors.grey.shade200,
                      radius: 20,
                      child: Icon(
                        Icons.two_wheeler,
                        color: estActif ? const Color(0xFF1D4ED8) : Colors.grey.shade500,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                l['nom'] as String,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: estActif ? const Color(0xFFECFDF5) : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  estActif ? 'Actif' : 'Désactivé',
                                  style: TextStyle(
                                    color: estActif ? const Color(0xFF065F46) : Colors.grey.shade600,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${l['telephone']} • ${l['moto']}',
                            style: const TextStyle(color: Colors.black54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: estActif,
                      activeTrackColor: const Color(0xFF1D4ED8),
                      onChanged: (val) {
                        setState(() {
                          l['actif'] = val;
                        });
                        _notifier(
                          val
                              ? 'Compte de ${l['nom']} réactivé.'
                              : 'Compte de ${l['nom']} suspendu.',
                          isError: !val,
                        );
                      },
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showAjouterLivreurDialog() {
    final nomController = TextEditingController();
    final telController = TextEditingController(text: '+237 6');
    final motoController = TextEditingController();
    final passController = TextEditingController(text: '123456');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.two_wheeler, color: Color(0xFF1D4ED8)),
            SizedBox(width: 8),
            Text('Nouveau livreur', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nom complet :'),
              const SizedBox(height: 4),
              TextField(
                controller: nomController,
                decoration: const InputDecoration(hintText: 'ex: Yao Patrick', isDense: true),
              ),
              const SizedBox(height: 12),
              const Text('Numéro de téléphone (+237) :'),
              const SizedBox(height: 4),
              TextField(
                controller: telController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: '+237 6XXXXXXXX', isDense: true),
              ),
              const SizedBox(height: 12),
              const Text('Moto & Immatriculation :'),
              const SizedBox(height: 4),
              TextField(
                controller: motoController,
                decoration: const InputDecoration(hintText: 'ex: Yamaha 125 • LT-452-CE', isDense: true),
              ),
              const SizedBox(height: 12),
              const Text('Mot de passe temporaire :'),
              const SizedBox(height: 4),
              TextField(
                controller: passController,
                decoration: const InputDecoration(hintText: 'Minimum 6 caractères', isDense: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final nom = nomController.text.trim();
              final tel = telController.text.trim();
              final moto = motoController.text.trim();
              if (nom.isEmpty || tel.length < 9) {
                return;
              }
              Navigator.pop(ctx);
              setState(() {
                _depotLivreurs.add({
                  'id': _depotLivreurs.length + 1,
                  'nom': nom,
                  'telephone': tel,
                  'moto': moto.isEmpty ? 'Moto de service' : moto,
                  'actif': true,
                  'courses_aujourdhui': 0,
                });
              });
              _notifier('Compte livreur créé avec succès pour $nom !');
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4ED8), foregroundColor: Colors.white),
            child: const Text('Créer le livreur'),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection(List<dynamic> reviews) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            'Avis clients',
            'Les avis récents publiés sur votre dépôt.',
            Icons.star_outline_rounded,
          ),
          const SizedBox(height: 12),
          if (reviews.isEmpty)
            const _EmptyNotice(
              icon: Icons.chat_bubble_outline,
              message: 'Aucun avis client pour le moment.',
            )
          else
            ...reviews.map((item) {
              final review = Map<String, dynamic>.from(item as Map);
              final rating = (review['note'] as num?)?.toDouble() ?? 0;
              final comment = review['commentaire']?.toString().trim() ?? '';
              final client =
                  review['client_telephone']?.toString() ?? 'Client GAZEO';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFFFF4D6),
                  child: Text(
                    rating.toStringAsFixed(rating % 1 == 0 ? 0 : 1),
                    style: const TextStyle(
                      color: Color(0xFF9A6700),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(
                  client,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(comment.isEmpty ? 'Sans commentaire' : comment),
                trailing: const Icon(
                  Icons.star,
                  size: 17,
                  color: Color(0xFFE3A008),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _sectionHeading(String title, String subtitle, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _green, size: 21),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _iconText(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.black54),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  String _libelleStatut(String status) => switch (status) {
    'EN_ATTENTE' => 'En attente',
    'ACCEPTEE' => 'Acceptée',
    'EN_LIVRAISON' => 'En livraison',
    'LIVREE' => 'Livrée',
    'ANNULEE' => 'Annulée',
    'VALIDE' => 'Validé',
    'REJETE' => 'Rejeté',
    'NON_SOUMIS' => 'Non soumis',
    _ => status.replaceAll('_', ' '),
  };
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: const BorderSide(color: Color(0xFFE8EEEB)),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _EmptyNotice extends StatelessWidget {
  const _EmptyNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.black38, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}
