import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/gazeo_order_stepper.dart';

class _ChatMessage {
  final String text;
  final bool fromMe;
  final DateTime time;
  _ChatMessage(this.text, this.fromMe) : time = DateTime.now();
}

/// Messagerie intégrée client ↔ livreur (sans application externe).
///
/// NOTE : les échanges sont pour l'instant conservés localement et les
/// réponses du livreur sont simulées. Brancher [_envoyer] sur un endpoint
/// backend (ex : POST /commandes/{id}/messages/ + polling ou WebSocket)
/// pour une vraie conversation en temps réel.
class ChatLivreurScreen extends StatefulWidget {
  final int commandeId;
  final String nomLivreur;

  const ChatLivreurScreen({
    super.key,
    required this.commandeId,
    this.nomLivreur = 'Yao Patrick',
  });

  @override
  State<ChatLivreurScreen> createState() => _ChatLivreurScreenState();
}

class _ChatLivreurScreenState extends State<ChatLivreurScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _livreurEcrit = false;
  Timer? _replyTimer;

  static const _reponsesRapides = [
    'Je suis devant le portail',
    'Appelez-moi en arrivant',
    'Combien de temps encore ?',
    'Merci !',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMessage(
      'Bonjour ! Je suis ${widget.nomLivreur}, votre livreur GAZEO. '
      'Je suis en route avec votre bouteille.',
      false,
    ));
  }

  @override
  void dispose() {
    _replyTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _envoyer([String? texte]) {
    final text = (texte ?? _controller.text).trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(text, true));
      _controller.clear();
      _livreurEcrit = true;
    });
    _defilerEnBas();

    _replyTimer?.cancel();
    _replyTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _livreurEcrit = false;
        _messages.add(_ChatMessage(_reponseAuto(text), false));
      });
      _defilerEnBas();
    });
  }

  String _reponseAuto(String message) {
    final m = message.toLowerCase();
    if (m.contains('temps') || m.contains('combien')) return 'J\'arrive dans environ 10 minutes 👍';
    if (m.contains('portail') || m.contains('devant')) return 'Bien noté, je vous vois bientôt !';
    if (m.contains('appel')) return 'D\'accord, je vous appelle dès que j\'arrive.';
    if (m.contains('merci')) return 'Avec plaisir ! Bonne journée 🙂';
    return 'Bien reçu, merci pour l\'information.';
  }

  void _defilerEnBas() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.slate900),
          onPressed: () => gazeoBack(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            ClipOval(
              child: Image.asset(
                'assets/images/driver_avatar.png',
                width: 38,
                height: 38,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => const CircleAvatar(
                  radius: 19,
                  backgroundColor: AppColors.blue50,
                  child: Icon(Icons.person, color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.nomLivreur,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.slate900)),
                Text(
                  _livreurEcrit ? 'écrit...' : 'Livreur • Commande #${widget.commandeId}',
                  style: TextStyle(
                    fontSize: 11,
                    color: _livreurEcrit ? AppColors.success : AppColors.slate500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, i) => _buildBubble(_messages[i]),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _reponsesRapides.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, i) => ActionChip(
                label: Text(_reponsesRapides[i]),
                labelStyle: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                backgroundColor: AppColors.blue50,
                side: const BorderSide(color: AppColors.blue100),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onPressed: () => _envoyer(_reponsesRapides[i]),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: (_) => _envoyer(),
                      decoration: InputDecoration(
                        hintText: 'Écrire un message...',
                        filled: true,
                        fillColor: AppColors.slate100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed: _envoyer,
                    style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(_ChatMessage msg) {
    return Align(
      alignment: msg.fromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: msg.fromMe ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.fromMe ? 16 : 4),
            bottomRight: Radius.circular(msg.fromMe ? 4 : 16),
          ),
          border: msg.fromMe ? null : Border.all(color: AppColors.slate200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              msg.text,
              style: TextStyle(color: msg.fromMe ? Colors.white : AppColors.slate900, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(msg.time),
              style: TextStyle(
                color: msg.fromMe ? Colors.white70 : AppColors.slate400,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

