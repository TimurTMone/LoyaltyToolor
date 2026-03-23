import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

enum LocationType { store, storeSoon, vending, bus }

class ToolorLocation {
  final String name;
  final String address;
  final LocationType type;
  final String? hours;
  final String? note;

  const ToolorLocation({
    required this.name,
    required this.address,
    required this.type,
    this.hours,
    this.note,
  });
}

const toolorLocations = [
  ToolorLocation(
    name: 'TOOLOR AsiaMall',
    address: 'AsiaMall, 2 этаж, бутик 19(1)',
    type: LocationType.store,
    hours: '10:00–22:00',
  ),
  ToolorLocation(
    name: 'TOOLOR Dordoi Plaza',
    address: 'Dordoi Plaza, 1 этаж',
    type: LocationType.storeSoon,
    note: 'Открытие скоро',
  ),
  ToolorLocation(
    name: 'TOOLOR Bishkek Park',
    address: 'ТРЦ Bishkek Park, 2 этаж',
    type: LocationType.storeSoon,
    note: 'Открытие скоро',
  ),
  ToolorLocation(
    name: 'Вендинг AsiaMall',
    address: 'AsiaMall, 1 этаж, у эскалатора',
    type: LocationType.vending,
    note: 'Аксессуары, шарфы, кепки',
  ),
  ToolorLocation(
    name: 'Вендинг Beta Stores',
    address: 'Beta Stores, центральный вход',
    type: LocationType.vending,
    note: 'Аксессуары, сумки',
  ),
  ToolorLocation(
    name: 'Вендинг Mega Silk Way',
    address: 'Mega Silk Way, 1 этаж',
    type: LocationType.vending,
    note: 'Аксессуары, чехлы',
  ),
  ToolorLocation(
    name: 'TOOLOR Bus',
    address: 'Мобильный шоурум',
    type: LocationType.bus,
    note: 'Маршрут: Бишкек → Иссык-Куль',
    hours: 'По расписанию',
  ),
];

void showLocationsSheet(BuildContext context) {
  HapticFeedback.lightImpact();
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.xl)),
      ),
      child: Column(
        children: [
          const SizedBox(height: S.x12),
          Container(width: 32, height: 3, decoration: BoxDecoration(color: AppColors.surfaceBright, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: S.x16),
          Text('ГДЕ ПРИМЕРИТЬ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 2, color: AppColors.textSecondary)),
          const SizedBox(height: S.x4),
          Text('Магазины, вендинг и мобильный шоурум', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
          const SizedBox(height: S.x16),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(S.x16, 0, S.x16, S.x24),
              physics: const BouncingScrollPhysics(),
              itemCount: toolorLocations.length,
              separatorBuilder: (_, _) => const SizedBox(height: S.x8),
              itemBuilder: (_, i) => _LocationTile(location: toolorLocations[i]),
            ),
          ),
        ],
      ),
    ),
  );
}

class _LocationTile extends StatelessWidget {
  final ToolorLocation location;
  const _LocationTile({required this.location});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String badge) = switch (location.type) {
      LocationType.store => (Icons.storefront_rounded, AppColors.accent, 'МАГАЗИН'),
      LocationType.storeSoon => (Icons.storefront_outlined, AppColors.gold, 'СКОРО'),
      LocationType.vending => (Icons.sell_outlined, const Color(0xFF9C7CF4), 'ВЕНДИНГ'),
      LocationType.bus => (Icons.directions_bus_rounded, const Color(0xFFFF8A65), 'BUS'),
    };

    return Container(
      padding: const EdgeInsets.all(S.x16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(R.sm)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: S.x12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(location.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: S.x6, vertical: 2),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                      child: Text(badge, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: S.x2),
                Text(location.address, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                if (location.note != null) ...[
                  const SizedBox(height: S.x2),
                  Text(location.note!, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7))),
                ],
                if (location.hours != null) ...[
                  const SizedBox(height: S.x2),
                  Text(location.hours!, style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
