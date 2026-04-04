"""Seed script for TOOLOR — populates categories, subcategories, products, and locations."""
import asyncio
import uuid
from decimal import Decimal

import asyncpg

DATABASE_URL = "postgresql://neondb_owner:npg_3NKgvsFrW5io@ep-blue-boat-amiwae15-pooler.c-5.us-east-1.aws.neon.tech/neondb?sslmode=require"

# ── Categories ──────────────────────────────────────────────────
CATEGORIES = [
    {"name": "Куртки", "slug": "jackets", "sort_order": 1},
    {"name": "Жилеты", "slug": "vests", "sort_order": 2},
    {"name": "Аксессуары", "slug": "accessories", "sort_order": 3},
    {"name": "Новинки", "slug": "new-arrivals", "sort_order": 4},
]

# ── Subcategories (slug → category_slug) ────────────────────────
SUBCATEGORIES = [
    {"name": "Зимние куртки", "slug": "winter-jackets", "cat": "jackets", "sort_order": 1},
    {"name": "Демисезонные куртки", "slug": "demi-jackets", "cat": "jackets", "sort_order": 2},
    {"name": "Пуховики", "slug": "puffer-jackets", "cat": "jackets", "sort_order": 3},
    {"name": "Парки", "slug": "parkas", "cat": "jackets", "sort_order": 4},
    {"name": "Утеплённые жилеты", "slug": "insulated-vests", "cat": "vests", "sort_order": 1},
    {"name": "Лёгкие жилеты", "slug": "light-vests", "cat": "vests", "sort_order": 2},
    {"name": "Шапки", "slug": "hats", "cat": "accessories", "sort_order": 1},
    {"name": "Перчатки", "slug": "gloves", "cat": "accessories", "sort_order": 2},
    {"name": "Шарфы", "slug": "scarves", "cat": "accessories", "sort_order": 3},
    {"name": "Сумки", "slug": "bags", "cat": "accessories", "sort_order": 4},
    {"name": "Сезонные новинки", "slug": "seasonal-new", "cat": "new-arrivals", "sort_order": 1},
]

# ── Products ────────────────────────────────────────────────────
PRODUCTS = [
    # Jackets
    {"name": "TOOLOR Arctic Pro", "slug": "toolor-arctic-pro", "desc": "Зимняя куртка с утеплением Thinsulate 300г. Выдерживает до -35°C.", "price": 12900, "original_price": 15900, "subcat": "winter-jackets", "sizes": ["S","M","L","XL","XXL"], "colors": ["Чёрный","Тёмно-синий","Хаки"], "stock": 45, "featured": True, "image": "https://images.unsplash.com/photo-1544923246-77307dd270b1?w=800"},
    {"name": "TOOLOR Storm Shield", "slug": "toolor-storm-shield", "desc": "Водонепроницаемая штормовая куртка. Мембрана 10000мм.", "price": 9900, "subcat": "winter-jackets", "sizes": ["S","M","L","XL"], "colors": ["Чёрный","Серый"], "stock": 30, "image": "https://images.unsplash.com/photo-1551028719-00167b16eac5?w=800"},
    {"name": "TOOLOR City Walker", "slug": "toolor-city-walker", "desc": "Стильная демисезонная куртка для города. Лёгкий утеплитель.", "price": 7500, "subcat": "demi-jackets", "sizes": ["S","M","L","XL"], "colors": ["Бежевый","Чёрный","Оливковый"], "stock": 60, "featured": True, "image": "https://images.unsplash.com/photo-1591047139829-d91aecb6caea?w=800"},
    {"name": "TOOLOR Wind Runner", "slug": "toolor-wind-runner", "desc": "Ветровка с капюшоном. Складывается в карман.", "price": 4900, "subcat": "demi-jackets", "sizes": ["M","L","XL"], "colors": ["Синий","Красный","Чёрный"], "stock": 80, "image": "https://images.unsplash.com/photo-1556821840-3a63f95609a7?w=800"},
    {"name": "TOOLOR Puffer Max", "slug": "toolor-puffer-max", "desc": "Объёмный пуховик с натуральным гусиным пухом 90/10.", "price": 16500, "original_price": 19900, "subcat": "puffer-jackets", "sizes": ["S","M","L","XL","XXL"], "colors": ["Чёрный","Белый","Бордовый"], "stock": 25, "featured": True, "image": "https://images.unsplash.com/photo-1608063615781-e2ef8c73d114?w=800"},
    {"name": "TOOLOR Puffer Lite", "slug": "toolor-puffer-lite", "desc": "Лёгкий пуховик для активного отдыха. Упаковывается в мешок.", "price": 8900, "subcat": "puffer-jackets", "sizes": ["S","M","L","XL"], "colors": ["Синий","Зелёный","Оранжевый"], "stock": 40, "image": "https://images.unsplash.com/photo-1611312449408-fcece27cdbb7?w=800"},
    {"name": "TOOLOR Explorer Parka", "slug": "toolor-explorer-parka", "desc": "Удлинённая парка с мехом. Идеальна для суровых зим Бишкека.", "price": 14500, "original_price": 17000, "subcat": "parkas", "sizes": ["S","M","L","XL"], "colors": ["Хаки","Чёрный","Тёмно-зелёный"], "stock": 20, "featured": True, "image": "https://images.unsplash.com/photo-1547624643-3bf761b09502?w=800"},
    # Vests
    {"name": "TOOLOR Thermal Vest", "slug": "toolor-thermal-vest", "desc": "Утеплённый жилет с подогревом. USB-порт для powerbank.", "price": 6900, "subcat": "insulated-vests", "sizes": ["S","M","L","XL","XXL"], "colors": ["Чёрный","Серый"], "stock": 35, "image": "https://images.unsplash.com/photo-1594938298603-c8148c4dae35?w=800"},
    {"name": "TOOLOR Down Vest", "slug": "toolor-down-vest", "desc": "Пуховый жилет для многослойности. Лёгкий и тёплый.", "price": 5500, "subcat": "insulated-vests", "sizes": ["M","L","XL"], "colors": ["Тёмно-синий","Красный","Чёрный"], "stock": 50, "image": "https://images.unsplash.com/photo-1591047139829-d91aecb6caea?w=800"},
    {"name": "TOOLOR Breeze Vest", "slug": "toolor-breeze-vest", "desc": "Лёгкий летний жилет с множеством карманов.", "price": 3500, "subcat": "light-vests", "sizes": ["S","M","L","XL"], "colors": ["Бежевый","Оливковый"], "stock": 70, "image": "https://images.unsplash.com/photo-1617127365659-c47fa864d8bc?w=800"},
    # Accessories
    {"name": "TOOLOR Merino Beanie", "slug": "toolor-merino-beanie", "desc": "Шапка из 100% мериносовой шерсти. Мягкая и тёплая.", "price": 1900, "subcat": "hats", "sizes": ["One Size"], "colors": ["Чёрный","Серый","Бордовый","Бежевый"], "stock": 120, "image": "https://images.unsplash.com/photo-1576871337632-b9aef4c17ab9?w=800"},
    {"name": "TOOLOR Tech Gloves", "slug": "toolor-tech-gloves", "desc": "Перчатки с сенсорными пальцами. Подходят для смартфонов.", "price": 2400, "subcat": "gloves", "sizes": ["S","M","L","XL"], "colors": ["Чёрный","Серый"], "stock": 90, "image": "https://images.unsplash.com/photo-1545170619-5c6d45baa376?w=800"},
    {"name": "TOOLOR Wool Scarf", "slug": "toolor-wool-scarf", "desc": "Шерстяной шарф ручной работы. Производство Кыргызстан.", "price": 2900, "subcat": "scarves", "sizes": ["One Size"], "colors": ["Серый","Бежевый","Клетка"], "stock": 65, "image": "https://images.unsplash.com/photo-1520903920243-00d872a2d1c9?w=800"},
    {"name": "TOOLOR Utility Bag", "slug": "toolor-utility-bag", "desc": "Поясная сумка из водоотталкивающей ткани.", "price": 3200, "subcat": "bags", "sizes": ["One Size"], "colors": ["Чёрный","Хаки"], "stock": 55, "image": "https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=800"},
    # New arrivals
    {"name": "TOOLOR Nomad 2026", "slug": "toolor-nomad-2026", "desc": "Новая коллекция весна 2026. Вдохновлено кочевой культурой.", "price": 11900, "original_price": 13900, "subcat": "seasonal-new", "sizes": ["S","M","L","XL"], "colors": ["Песочный","Индиго","Терракот"], "stock": 30, "featured": True, "image": "https://images.unsplash.com/photo-1559582798-678dfc68cba5?w=800"},
    {"name": "TOOLOR Summit Tech", "slug": "toolor-summit-tech", "desc": "Техническая куртка для горного туризма. Gore-Tex Pro.", "price": 18900, "subcat": "seasonal-new", "sizes": ["S","M","L","XL"], "colors": ["Оранжевый","Чёрный"], "stock": 15, "featured": True, "image": "https://images.unsplash.com/photo-1495105787522-5334e3ffa0ef?w=800"},
]

# ── Locations ───────────────────────────────────────────────────
LOCATIONS = [
    {"name": "TOOLOR Flagship — Бишкек", "address": "ул. Киевская 96, Бишкек", "type": "store", "hours": "10:00–21:00", "lat": 42.8746, "lon": 74.5698},
    {"name": "TOOLOR — ТЦ Дордой Плаза", "address": "пр. Чуй 155, Бишкек", "type": "store", "hours": "10:00–22:00", "lat": 42.8700, "lon": 74.5900},
    {"name": "TOOLOR — ТЦ Asia Mall", "address": "пр. Мира 46, Бишкек", "type": "store", "hours": "10:00–21:00", "lat": 42.8670, "lon": 74.5840},
    {"name": "TOOLOR — Ош Базар", "address": "ул. Бейшеналиевой 2, Бишкек", "type": "store", "hours": "09:00–18:00", "lat": 42.8770, "lon": 74.5820},
    {"name": "TOOLOR Ателье", "address": "ул. Токтогула 125, Бишкек", "type": "atelier", "hours": "10:00–19:00", "lat": 42.8730, "lon": 74.6000},
    {"name": "TOOLOR Склад", "address": "ул. Алматинская 508, Бишкек", "type": "warehouse", "hours": "09:00–18:00", "lat": 42.8600, "lon": 74.6200},
    {"name": "TOOLOR — Ош филиал", "address": "ул. Курманжан Датка 271, Ош", "type": "store", "hours": "10:00–20:00", "lat": 40.5283, "lon": 72.7985},
]


async def seed():
    conn = await asyncpg.connect(DATABASE_URL, ssl="require")

    try:
        # Check if already seeded
        count = await conn.fetchval("SELECT COUNT(*) FROM categories")
        if count > 0:
            print(f"Database already has {count} categories. Clearing and re-seeding...")
            # Clear in correct order (foreign keys)
            await conn.execute("DELETE FROM store_inventory")
            await conn.execute("DELETE FROM order_items")
            await conn.execute("DELETE FROM cart_items")
            await conn.execute("DELETE FROM favorites")
            await conn.execute("DELETE FROM products")
            await conn.execute("DELETE FROM subcategories")
            await conn.execute("DELETE FROM categories")
            await conn.execute("DELETE FROM locations")

        # 1. Categories
        cat_ids = {}
        for c in CATEGORIES:
            cid = uuid.uuid4()
            cat_ids[c["slug"]] = cid
            await conn.execute(
                "INSERT INTO categories (id, name, slug, sort_order) VALUES ($1, $2, $3, $4)",
                cid, c["name"], c["slug"], c["sort_order"]
            )
        print(f"Inserted {len(CATEGORIES)} categories")

        # 2. Subcategories
        subcat_ids = {}
        for s in SUBCATEGORIES:
            sid = uuid.uuid4()
            subcat_ids[s["slug"]] = sid
            await conn.execute(
                "INSERT INTO subcategories (id, category_id, name, slug, sort_order) VALUES ($1, $2, $3, $4, $5)",
                sid, cat_ids[s["cat"]], s["name"], s["slug"], s["sort_order"]
            )
        print(f"Inserted {len(SUBCATEGORIES)} subcategories")

        # 3. Products
        import json
        for p in PRODUCTS:
            pid = uuid.uuid4()
            cat_slug = next(s["cat"] for s in SUBCATEGORIES if s["slug"] == p["subcat"])
            await conn.execute(
                """INSERT INTO products (id, name, slug, description, price, original_price,
                   category_id, subcategory_id, image_url, images, sizes, colors, stock,
                   is_active, is_featured, sort_order)
                   VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10::jsonb,$11::jsonb,$12::jsonb,$13,true,$14,0)""",
                pid, p["name"], p["slug"], p["desc"],
                Decimal(str(p["price"])),
                Decimal(str(p.get("original_price", 0))) if p.get("original_price") else None,
                cat_ids[cat_slug], subcat_ids[p["subcat"]],
                p["image"], json.dumps([p["image"]]),
                json.dumps(p["sizes"]), json.dumps(p["colors"]),
                p.get("stock", 0), p.get("featured", False)
            )
        print(f"Inserted {len(PRODUCTS)} products")

        # 4. Locations
        for loc in LOCATIONS:
            lid = uuid.uuid4()
            await conn.execute(
                """INSERT INTO locations (id, name, address, type, hours, latitude, longitude, is_active, sort_order)
                   VALUES ($1,$2,$3,$4,$5,$6,$7,true,0)""",
                lid, loc["name"], loc["address"], loc["type"], loc["hours"],
                Decimal(str(loc["lat"])), Decimal(str(loc["lon"]))
            )
        print(f"Inserted {len(LOCATIONS)} locations")

        # Summary
        total_products = await conn.fetchval("SELECT COUNT(*) FROM products")
        total_cats = await conn.fetchval("SELECT COUNT(*) FROM categories")
        total_locs = await conn.fetchval("SELECT COUNT(*) FROM locations")
        print(f"\nDone! DB now has: {total_cats} categories, {total_products} products, {total_locs} locations")

    finally:
        await conn.close()


if __name__ == "__main__":
    asyncio.run(seed())
