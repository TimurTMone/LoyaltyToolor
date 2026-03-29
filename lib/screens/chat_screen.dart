import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import 'product_detail_screen.dart';
import '../services/analytics_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messages = <_Msg>[];
  final _scrollCtrl = ScrollController();
  final _inputCtrl = TextEditingController();
  bool _typing = false;
  bool _started = false;
  String? _sessionId;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _startChat() async {
    if (_started) return;
    _started = true;

    // Create a chat session on the backend
    try {
      final res = await ApiService.dio.post('/api/v1/chat/sessions');
      _sessionId = res.data['id'];
    } catch (_) {
      // If session creation fails, we'll work without persistence
    }

    final auth = context.read<AuthProvider>();
    final name = auth.isLoggedIn ? auth.user!.name.split(' ').first : 'друг';
    final tier = auth.loyalty?.tierName ?? 'Bronze';
    final pts = auth.loyalty?.points ?? 0;

    _addLocalBot('Привет, $name! 👋 Я — AI-стилист TOOLOR. Помогу подобрать образ, расскажу про акции и бонусы.');

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _addLocalBot('У тебя $tier статус и $pts баллов. Спрашивай что угодно!');
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        _addChips(['🔥 Скидки сейчас', '👕 Подобрать образ', '⭐ Мои баллы', '📦 Мои заказы']);
      });
    });
  }

  void _trimMessages() {
    if (_messages.length > 100) {
      _messages.removeRange(0, _messages.length - 100);
    }
  }

  /// Add a local bot message with typing animation (for greeting only).
  void _addLocalBot(String text) {
    setState(() => _typing = true);
    Future.delayed(Duration(milliseconds: 400 + text.length * 8), () {
      if (!mounted) return;
      setState(() {
        _typing = false;
        _messages.add(_Msg(text: text, isUser: false));
        _trimMessages();
      });
      _scroll();
    });
  }

  void _addChips(List<String> options) {
    setState(() {
      _messages.add(_Msg(text: '', isUser: false, chips: options));
      _trimMessages();
    });
    _scroll();
  }

  void _addProductCards(List<Product> products) {
    setState(() {
      _messages.add(_Msg(text: '', isUser: false, products: products));
      _trimMessages();
    });
    _scroll();
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    _inputCtrl.clear();
    HapticFeedback.lightImpact();
    setState(() {
      _messages.add(_Msg(text: text, isUser: true));
      _trimMessages();
    });
    _scroll();
    Analytics.chatMessage();
    _sendToBackend(text.trim());
  }

  void _handleChip(String chip) {
    HapticFeedback.lightImpact();
    setState(() {
      _messages.add(_Msg(text: chip, isUser: true));
      _trimMessages();
    });
    _scroll();
    _sendToBackend(chip);
  }

  /// Send message to backend AI and display the response.
  Future<void> _sendToBackend(String text) async {
    setState(() => _typing = true);

    // If no session yet, create one
    if (_sessionId == null) {
      try {
        final res = await ApiService.dio.post('/api/v1/chat/sessions');
        _sessionId = res.data['id'];
      } catch (_) {
        if (!mounted) return;
        setState(() => _typing = false);
        _addLocalBot('Не удалось подключиться. Попробуйте позже.');
        return;
      }
    }

    try {
      final res = await ApiService.dio.post(
        '/api/v1/chat/sessions/$_sessionId/messages',
        data: {'content': text},
      );

      if (!mounted) return;
      setState(() => _typing = false);

      // Response is a list: [user_msg, assistant_msg]
      final messages = res.data as List;
      if (messages.length >= 2) {
        final assistantMsg = messages[1];
        final replyText = assistantMsg['content'] as String;
        final products = assistantMsg['products'] as List? ?? [];

        // Add the bot reply
        setState(() {
          _messages.add(_Msg(text: replyText, isUser: false));
          _trimMessages();
        });
        _scroll();

        // If the AI recommended products, show them as cards
        if (products.isNotEmpty) {
          final productCards = products.map((p) {
            final map = p as Map<String, dynamic>;
            return Product.fromJson(map);
          }).toList();

          Future.delayed(const Duration(milliseconds: 500), () {
            if (!mounted) return;
            _addProductCards(productCards);
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _typing = false);
      setState(() {
        _messages.add(_Msg(
          text: 'Упс, не удалось получить ответ. Попробуйте ещё раз! 🔄',
          isUser: false,
        ));
        _trimMessages();
      });
      _scroll();
    }
  }

  void _scroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent + 100, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isLoggedIn && !_started) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startChat());
    }
    final bot = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(S.x16, S.x12, S.x16, S.x8),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(R.sm)),
                  child: Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.accent),
                ),
                const SizedBox(width: S.x12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TOOLOR AI', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.textPrimary)),
                      Text('Персональный стилист', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                    ],
                  ),
                ),
                if (_typing)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('думает...', style: TextStyle(fontSize: 11, color: AppColors.accent)),
                  ]),
              ],
            ),
          ),
          Divider(color: AppColors.divider, height: 0.5),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(S.x16, S.x12, S.x16, S.x12),
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _buildMessage(_messages[i]),
            ),
          ),

          // Input
          Container(
            padding: EdgeInsets.fromLTRB(S.x16, S.x8, S.x8, S.x8 + bot),
            decoration: BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.divider))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Спросите что угодно...',
                      contentPadding: EdgeInsets.symmetric(horizontal: S.x12, vertical: S.x8),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: S.x4),
                GestureDetector(
                  onTap: () => _sendMessage(_inputCtrl.text),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.accent, Color(0xFF7AB8F5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(R.pill),
                    ),
                    child: const Icon(Icons.arrow_upward_rounded, size: 20, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(_Msg msg) {
    if (msg.chips != null) return _buildChipRow(msg.chips!);
    if (msg.products != null) return _buildProductRow(msg.products!);

    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: S.x8),
        padding: const EdgeInsets.symmetric(horizontal: S.x16, vertical: S.x12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: msg.isUser ? AppColors.textPrimary : AppColors.surfaceElevated,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(R.lg),
            topRight: const Radius.circular(R.lg),
            bottomLeft: Radius.circular(msg.isUser ? R.lg : R.xs),
            bottomRight: Radius.circular(msg.isUser ? R.xs : R.lg),
          ),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            fontSize: 14,
            color: msg.isUser ? AppColors.textInverse : AppColors.textPrimary,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  Widget _buildChipRow(List<String> chips) {
    return Padding(
      padding: const EdgeInsets.only(bottom: S.x8),
      child: Wrap(
        spacing: S.x8,
        runSpacing: S.x8,
        children: chips.map((c) => GestureDetector(
          onTap: () => _handleChip(c),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: S.x12, vertical: S.x8),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(R.pill),
              border: Border.all(color: AppColors.surfaceBright),
            ),
            child: Text(c, style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildProductRow(List<Product> products) {
    return Padding(
      padding: const EdgeInsets.only(bottom: S.x12),
      child: SizedBox(
        height: 180,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: products.length,
          separatorBuilder: (_, __) => const SizedBox(width: S.x8),
          itemBuilder: (_, i) {
            final p = products[i];
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p, heroTag: 'chat_${p.id}')));
              },
              child: Container(
                width: 140,
                decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(R.lg)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(p.displayImageUrl, fit: BoxFit.cover, width: double.infinity,
                            errorBuilder: (_, __, ___) => Container(color: AppColors.surfaceOverlay)),
                          if (p.isOnSale) Positioned(
                            top: 6, left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.sale, borderRadius: BorderRadius.circular(4)),
                              child: Text('-${p.discountPercent}%', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(S.x8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text(p.formattedPrice, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.isOnSale ? AppColors.sale : AppColors.textPrimary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Msg {
  final String text;
  final bool isUser;
  final List<String>? chips;
  final List<Product>? products;
  _Msg({required this.text, required this.isUser, this.chips, this.products});
}
