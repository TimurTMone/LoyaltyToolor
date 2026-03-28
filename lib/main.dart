import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/catalog_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/chat_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await ApiService.init();
  runApp(const ToolorApp());
}

class ToolorApp extends StatelessWidget {
  const ToolorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProv, _) => MaterialApp(
          title: 'TOOLOR',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeProv.themeMode,
          builder: (context, child) {
            final bright = Theme.of(context).brightness;
            AppColors.applyBrightness(bright);
            SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: bright == Brightness.dark ? Brightness.light : Brightness.dark,
              systemNavigationBarColor: AppColors.surface,
              systemNavigationBarIconBrightness: bright == Brightness.dark ? Brightness.light : Brightness.dark,
            ));
            return child!;
          },
          home: const MainShell(),
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;
  bool _notificationsStarted = false;

  static const _screens = [HomeScreen(), CatalogScreen(), CartScreen(), ChatScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) {
    // Start notification polling once the user logs in
    final auth = context.watch<AuthProvider>();
    if (auth.isLoggedIn && !_notificationsStarted) {
      _notificationsStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<NotificationProvider>().startPolling();
      });
    } else if (!auth.isLoggedIn && _notificationsStarted) {
      _notificationsStarted = false;
      context.read<NotificationProvider>().stopPolling();
    }

    return Scaffold(
      body: IndexedStack(index: _tab, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider, width: 0.5))),
        child: Consumer<CartProvider>(
          builder: (context, cart, _) => BottomNavigationBar(
            currentIndex: _tab,
            onTap: (i) { HapticFeedback.selectionClick(); setState(() => _tab = i); },
            items: [
              const BottomNavigationBarItem(icon: Icon(Icons.home_outlined, size: 22), activeIcon: Icon(Icons.home_rounded, size: 22), label: 'Главная'),
              const BottomNavigationBarItem(icon: Icon(Icons.grid_view_outlined, size: 22), activeIcon: Icon(Icons.grid_view_rounded, size: 22), label: 'Каталог'),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: cart.itemCount > 0,
                  backgroundColor: AppColors.accent,
                  label: Text('${cart.itemCount}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
                  child: const Icon(Icons.shopping_bag_outlined, size: 22),
                ),
                activeIcon: Badge(
                  isLabelVisible: cart.itemCount > 0,
                  backgroundColor: AppColors.accent,
                  label: Text('${cart.itemCount}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
                  child: const Icon(Icons.shopping_bag_rounded, size: 22),
                ),
                label: 'Корзина',
              ),
              const BottomNavigationBarItem(icon: Icon(Icons.auto_awesome_outlined, size: 22), activeIcon: Icon(Icons.auto_awesome_rounded, size: 22), label: 'AI'),
              const BottomNavigationBarItem(icon: Icon(Icons.person_outline, size: 22), activeIcon: Icon(Icons.person_rounded, size: 22), label: 'Профиль'),
            ],
          ),
        ),
      ),
    );
  }
}
