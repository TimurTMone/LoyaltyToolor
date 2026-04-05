export const ORDER_STATUSES = [
  { value: "pending", label: "Ожидает" },
  { value: "payment_confirmed", label: "Оплачен" },
  { value: "processing", label: "В обработке" },
  { value: "shipped", label: "Отправлен" },
  { value: "delivered", label: "Доставлен" },
  { value: "cancelled", label: "Отменён" },
] as const;

export const LOYALTY_TIERS = [
  { name: "bronze", minSpent: 0, cashback: 3 },
  { name: "silver", minSpent: 50_000, cashback: 5 },
  { name: "gold", minSpent: 150_000, cashback: 8 },
  { name: "platinum", minSpent: 300_000, cashback: 12 },
] as const;

export const NAV_ITEMS = [
  { href: "/", label: "Панель", icon: "LayoutDashboard" },
  { href: "/scan", label: "Сканер QR", icon: "ScanLine" },
  { href: "/products", label: "Товары", icon: "Package" },
  { href: "/import", label: "Импорт Excel", icon: "FileSpreadsheet" },
  { href: "/orders", label: "Заказы", icon: "ShoppingCart" },
  { href: "/users", label: "Пользователи", icon: "Users" },
  { href: "/categories", label: "Категории", icon: "FolderTree" },
  { href: "/promo-codes", label: "Промокоды", icon: "Ticket" },
  { href: "/inventory", label: "Склад", icon: "Warehouse" },
  { href: "/locations", label: "Точки", icon: "MapPin" },
  { href: "/notifications", label: "Уведомления", icon: "Bell" },
] as const;
