import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../models/product.dart';
import '../models/loyalty.dart';
import '../services/api_service.dart';
import 'product_detail_screen.dart';

// TODO: Connect chat to real AI/chat API endpoint (e.g. POST /api/v1/chat)
// Currently uses local scripted responses with product data fetched from API.

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

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  void _startChat() {
    if (_started) return;
    _started = true;
    final auth = context.read<AuthProvider>();
    final name = auth.isLoggedIn ? auth.user!.name.split(' ').first : 'друг';
    final tier = auth.loyalty?.tierName ?? 'Bronze';
    final pts = auth.loyalty?.points ?? 0;

    _addBot('Привет, $name! 👋 Я — стилист TOOLOR. Помогу подобрать образ, расскажу про акции и бонусы.');

    Future.delayed(const Duration(milliseconds: 1200), () {
      _addBot('У тебя $tier статус и $pts баллов. Вот что могу предложить:');
      Future.delayed(const Duration(milliseconds: 800), () {
        _addChips(['🔥 Скидки сейчас', '👕 Подобрать образ', '⭐ Мои баллы', '📦 Box подписка']);
      });
    });
  }

  void _trimMessages() {
    if (_messages.length > 100) {
      _messages.removeRange(0, _messages.length - 100);
    }
  }

  void _addBot(String text) {
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
    _handleInput(text.trim().toLowerCase());
  }

  void _handleChip(String chip) {
    HapticFeedback.lightImpact();
    setState(() {
      _messages.add(_Msg(text: chip, isUser: true));
      _trimMessages();
    });
    _scroll();
    _handleInput(chip.toLowerCase());
  }

  /// Fetch products from API with an optional search query, then filter locally.
  Future<List<Product>> _fetchChatProducts({String? search, bool Function(Product)? filter}) async {
    try {
      final Map<String, dynamic> params = {'per_page': 10};
      if (search != null) params['search'] = search;
      final response = await ApiService.dio.get('/api/v1/products', queryParameters: params);
      var items = (response.data['items'] as List)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .where((p) => p.price > 0)
          .toList();
      if (filter != null) items = items.where(filter).toList();
      return items.take(4).toList();
    } catch (_) {
      return [];
    }
  }

  void _handleInput(String input) {
    if (input.contains('скидк') || input.contains('sale') || input.contains('акци')) {
      _addBot('Ищу товары со скидками...');
      _fetchChatProducts(filter: (p) => p.originalPrice != null).then((sale) {
        if (!mounted) return;
        if (sale.isNotEmpty) {
          _addBot('Сейчас ${sale.length} товаров со скидкой до 40%! Вот лучшие:');
          Future.delayed(const Duration(milliseconds: 900), () => _addProductCards(sale));
        } else {
          _addBot('К сожалению, не удалось загрузить товары. Попробуйте позже.');
        }
      });
    } else if (input.contains('образ') || input.contains('подобр') || input.contains('стиль') || input.contains('outfit')) {
      _addBot('Какой стиль тебе ближе?');
      Future.delayed(const Duration(milliseconds: 700), () {
        _addChips(['🏙️ Городской', '🏔️ Outdoor', '💼 Деловой', '🎒 Casual']);
      });
    } else if (input.contains('городск') || input.contains('urban')) {
      _addBot('Для города рекомендую — куртка + брюки + свитшот. Ищу варианты...');
      _fetchChatProducts(filter: (p) {
        return p.subcategory.contains('Куртк') || p.subcategory.contains('Брюк') || p.subcategory.contains('Свитш');
      }).then((urban) {
        if (!mounted) return;
        if (urban.isNotEmpty) {
          _addProductCards(urban);
        }
      });
    } else if (input.contains('outdoor') || input.contains('горн')) {
      _addBot('Для outdoor — пуховик или ветровка + флис. Ищу...');
      _fetchChatProducts(filter: (p) {
        return p.subcategory.contains('Пуховик') || p.subcategory.contains('Флис') || p.subcategory.contains('Ветровк');
      }).then((out) {
        if (!mounted) return;
        if (out.isNotEmpty) {
          _addProductCards(out);
        }
      });
    } else if (input.contains('балл') || input.contains('лояльн') || input.contains('кэшбэк') || input.contains('cashback') || input.contains('point')) {
      final auth = context.read<AuthProvider>();
      final l = auth.loyalty;
      if (l != null) {
        final left = l.nextTierThreshold - l.totalSpent;
        _addBot('У тебя ${l.points} баллов (${l.cashbackPercent}% кэшбэк).\n\nДо ${l.tier != LoyaltyTier.platinum ? "следующего уровня осталось ${left.toStringAsFixed(0)} сом" : "максимального уровня — ты уже там! 🎉"}');
        Future.delayed(const Duration(milliseconds: 800), () {
          _addBot('Баллы можно списать при следующей покупке на кассе или онлайн.');
        });
      }
    } else if (input.contains('box') || input.contains('подписк')) {
      _addBot('TOOLOR Box — ежемесячная подписка. Наши стилисты подберут 3–5 вещей по твоему стилю.\n\n• Basic — 4 990 сом (3 вещи)\n• Premium — 8 990 сом (5 вещей)\n\nСкоро запуск! Хочешь, запишу тебя?');
      Future.delayed(const Duration(milliseconds: 800), () {
        _addChips(['✅ Да, запиши!', '🤔 Расскажи подробнее']);
      });
    } else if (input.contains('да') || input.contains('запиш')) {
      _addBot('Записала! Мы напишем тебе, как только Box будет доступен. 📬');
    } else if (input.contains('размер') || input.contains('size')) {
      _addBot('Подскажу размер! Какой у тебя рост и вес? Например: "175 см, 70 кг"');
    } else if (RegExp(r'\d{2,3}\s*(см)?,?\s*\d{2,3}\s*(кг)?').hasMatch(input)) {
      _addBot('Для роста ~175 и веса ~70 рекомендую размер M в верхней одежде и M-L в брюках.\n\nНо лучше всего — примерка в нашем бутике! AsiaMall, 2 этаж, бутик 19(1) 📍');
    } else if (input.contains('деловой') || input.contains('бизнес') || input.contains('💼')) {
      _addBot('Деловой стиль — рубашка + брюки. Ищу подборку...');
      _fetchChatProducts(filter: (p) {
        return p.subcategory.contains('Рубашк') || p.subcategory.contains('Брюк');
      }).then((biz) {
        if (!mounted) return;
        if (biz.isNotEmpty) {
          _addProductCards(biz);
        }
      });
    } else if (input.contains('casual') || input.contains('🎒')) {
      _addBot('Casual vibes — худи + футболка + шорты:');
      _fetchChatProducts(filter: (p) {
        return p.subcategory.contains('Худи') || p.subcategory.contains('Футболк') || p.subcategory.contains('Шорты');
      }).then((cas) {
        if (!mounted) return;
        if (cas.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 900), () => _addProductCards(cas));
        }
      });
    } else if (input.contains('привет') || input.contains('здравствуй') || input.contains('hello') || input.contains('hi')) {
      _addBot('Привет! Чем могу помочь? 😊');
      Future.delayed(const Duration(milliseconds: 700), () {
        _addChips(['🔥 Скидки сейчас', '👕 Подобрать образ', '⭐ Мои баллы']);
      });
    } else if (input.contains('спасиб') || input.contains('thank')) {
      _addBot('Всегда рада помочь! Если что — пиши. 💚');
    } else if (input.contains('подробн') || input.contains('расскаж')) {
      _addBot('Каждый месяц мы собираем персональный набор вещей на основе твоих предпочтений.\n\nТы получаешь коробку, примеряешь дома и оставляешь только то, что нравится. Остальное возвращаешь бесплатно!');
    } else {
      _addBot('Хороший вопрос! Могу помочь с подбором одежды, акциями, баллами или размерами. Что интересует?');
      Future.delayed(const Duration(milliseconds: 700), () {
        _addChips(['🔥 Скидки', '👕 Стиль', '⭐ Баллы', '📏 Размер']);
      });
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
                    Text('печатает...', style: TextStyle(fontSize: 11, color: AppColors.accent)),
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
                      hintText: 'Напишите сообщение...',
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
          separatorBuilder: (_, _) => const SizedBox(width: S.x8),
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
                            errorBuilder: (_, _, _) => Container(color: AppColors.surfaceOverlay)),
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
