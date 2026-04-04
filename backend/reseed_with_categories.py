"""Re-seed database using scraped products + real WooCommerce category mapping."""

import asyncio
import json
import re
import uuid
from decimal import Decimal

import asyncpg

DATABASE_URL = "postgresql://neondb_owner:npg_3NKgvsFrW5io@ep-blue-boat-amiwae15-pooler.c-5.us-east-1.aws.neon.tech/neondb?sslmode=require"


def slugify(text: str) -> str:
    text = text.lower().strip()
    text = re.sub(r'[^\w\s-]', '', text)
    text = re.sub(r'[\s_]+', '-', text)
    text = re.sub(r'-+', '-', text).strip('-')
    return text or "unknown"


async def main():
    # Load scraped products
    with open("scraped_products.json", encoding="utf-8") as f:
        products = json.load(f)

    # Load real category mapping (product_slug -> {category, subcategory})
    with open("product_category_map.json", encoding="utf-8") as f:
        cat_map_data = json.load(f)

    # Apply real categories to products
    for p in products:
        slug = p["slug"]
        if slug in cat_map_data:
            p["category"] = cat_map_data[slug]["category"]
            p["subcategory"] = cat_map_data[slug]["subcategory"]
        else:
            # Try to infer from product name
            name_lower = p["name"].lower()
            if any(w in name_lower for w in ["мужск", "мужчин"]):
                p["category"] = "Мужчинам"
            elif any(w in name_lower for w in ["женск", "женщин"]):
                p["category"] = "Женщинам"
            elif any(w in name_lower for w in ["сумк", "кепк", "шарф", "чехол", "шоппер"]):
                p["category"] = "Аксессуары"
            else:
                p["category"] = "Другое"

            # Infer subcategory from name
            if "куртк" in name_lower or "пуховик" in name_lower or "парк" in name_lower:
                p["subcategory"] = "Куртки"
            elif "брюк" in name_lower or "штан" in name_lower:
                p["subcategory"] = "Брюки"
            elif "футболк" in name_lower:
                p["subcategory"] = "Футболки"
            elif "лонгслив" in name_lower:
                p["subcategory"] = "Лонгсливы"
            elif "свитшот" in name_lower:
                p["subcategory"] = "Свитшоты"
            elif "худи" in name_lower:
                p["subcategory"] = "Худи"
            elif "ветровк" in name_lower:
                p["subcategory"] = "Ветровки"
            elif "рубашк" in name_lower:
                p["subcategory"] = "Рубашки"
            elif "свитер" in name_lower or "кардиган" in name_lower or "водолазк" in name_lower:
                p["subcategory"] = "Вязанный трикотаж"
            elif "сумк" in name_lower or "шоппер" in name_lower or "чехол" in name_lower:
                p["subcategory"] = "Сумки"
            elif "кепк" in name_lower:
                p["subcategory"] = "Кепки"
            elif "шарф" in name_lower or "платок" in name_lower:
                p["subcategory"] = "Платки"
            else:
                p["subcategory"] = p["category"]

    # Merge subcategories that are the same concept across genders
    # (e.g., "Мужчинам::Куртки" and "Женщинам::Куртки" stay separate — that's correct for this brand)

    # Also fix "Оффер > Ветровки" → move to main category
    for p in products:
        if p["category"] == "Оффер":
            # Infer real category
            name_lower = p["name"].lower()
            if any(w in name_lower for w in ["мужск", "мужчин"]):
                p["category"] = "Мужчинам"
            else:
                p["category"] = "Женщинам"
        # Fix subcategory == parent (e.g. "Мужчинам > Мужчинам")
        if p["subcategory"] == p["category"]:
            name_lower = p["name"].lower()
            if "шорт" in name_lower:
                p["subcategory"] = "Шорты"
            elif "флис" in name_lower:
                p["subcategory"] = "Флис"
            elif "лайтдаун" in name_lower or "стеганн" in name_lower:
                p["subcategory"] = "Лайтдаун"
            else:
                p["subcategory"] = "Другое"

    conn = await asyncpg.connect(DATABASE_URL, ssl="require")

    try:
        print("Clearing old data...")
        await conn.execute("DELETE FROM store_inventory")
        await conn.execute("DELETE FROM order_items")
        await conn.execute("DELETE FROM cart_items")
        await conn.execute("DELETE FROM favorites")
        await conn.execute("DELETE FROM products")
        await conn.execute("DELETE FROM subcategories")
        await conn.execute("DELETE FROM categories")

        # Build category + subcategory maps
        cat_ids: dict[str, uuid.UUID] = {}
        subcat_ids: dict[str, tuple[uuid.UUID, str]] = {}

        for p in products:
            cat = p["category"]
            subcat = p["subcategory"]
            if cat not in cat_ids:
                cat_ids[cat] = uuid.uuid4()
            key = f"{cat}::{subcat}"
            if key not in subcat_ids:
                subcat_ids[key] = (uuid.uuid4(), cat)

        # Insert categories
        cat_order = {"Мужчинам": 1, "Женщинам": 2, "Аксессуары": 3}
        for name, cid in cat_ids.items():
            await conn.execute(
                "INSERT INTO categories (id, name, slug, sort_order) VALUES ($1, $2, $3, $4)",
                cid, name, slugify(name), cat_order.get(name, 10),
            )
        print(f"Inserted {len(cat_ids)} categories")

        # Insert subcategories
        for i, (key, (sid, cat_name)) in enumerate(subcat_ids.items()):
            subcat_name = key.split("::", 1)[1]
            await conn.execute(
                "INSERT INTO subcategories (id, category_id, name, slug, sort_order) VALUES ($1, $2, $3, $4, $5)",
                sid, cat_ids[cat_name], subcat_name, slugify(f"{cat_name}-{subcat_name}"), i + 1,
            )
        print(f"Inserted {len(subcat_ids)} subcategories")

        # Insert products
        seen_slugs = set()
        seen_skus = set()
        inserted = 0

        for p in products:
            slug = p["slug"]
            if slug in seen_slugs:
                slug = f"{slug}-{uuid.uuid4().hex[:6]}"
            seen_slugs.add(slug)

            sku = p.get("sku")
            if sku:
                if sku in seen_skus:
                    sku = None
                else:
                    seen_skus.add(sku)

            price = Decimal(p["price"])
            if price <= 0:
                continue

            original_price = Decimal(p["original_price"]) if p.get("original_price") else None
            cat_id = cat_ids[p["category"]]
            key = f"{p['category']}::{p['subcategory']}"
            subcat_id = subcat_ids[key][0]

            is_featured = original_price is not None

            try:
                await conn.execute(
                    """INSERT INTO products
                       (id, sku, name, slug, description, price, original_price,
                        category_id, subcategory_id, image_url, images, sizes, colors,
                        stock, is_active, is_featured, sort_order)
                       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11::jsonb,$12::jsonb,$13::jsonb,$14,true,$15,0)""",
                    uuid.uuid4(), sku, p["name"], slug, p.get("description", ""),
                    price, original_price,
                    cat_id, subcat_id,
                    p["image_url"], json.dumps(p.get("images", [])),
                    json.dumps(p.get("sizes", [])), json.dumps(p.get("colors", [])),
                    p.get("stock", 50), is_featured,
                )
                inserted += 1
            except Exception as e:
                print(f"  SKIP {p['name']}: {e}")

        # Also re-insert locations (keep them)
        locations = [
            {"name": "TOOLOR Flagship — Бишкек", "address": "ул. Киевская 96, Бишкек", "type": "store", "hours": "10:00–21:00", "lat": "42.8746", "lon": "74.5698"},
            {"name": "TOOLOR — ТЦ Дордой Плаза", "address": "пр. Чуй 155, Бишкек", "type": "store", "hours": "10:00–22:00", "lat": "42.8700", "lon": "74.5900"},
            {"name": "TOOLOR — ТЦ Asia Mall", "address": "пр. Мира 46, Бишкек", "type": "store", "hours": "10:00–21:00", "lat": "42.8670", "lon": "74.5840"},
            {"name": "TOOLOR — Ош Базар", "address": "ул. Бейшеналиевой 2, Бишкек", "type": "store", "hours": "09:00–18:00", "lat": "42.8770", "lon": "74.5820"},
            {"name": "TOOLOR Ателье", "address": "ул. Токтогула 125, Бишкек", "type": "atelier", "hours": "10:00–19:00", "lat": "42.8730", "lon": "74.6000"},
            {"name": "TOOLOR Склад", "address": "ул. Алматинская 508, Бишкек", "type": "warehouse", "hours": "09:00–18:00", "lat": "42.8600", "lon": "74.6200"},
            {"name": "TOOLOR — Ош филиал", "address": "ул. Курманжан Датка 271, Ош", "type": "store", "hours": "10:00–20:00", "lat": "40.5283", "lon": "72.7985"},
        ]

        existing_locs = await conn.fetchval("SELECT COUNT(*) FROM locations")
        if existing_locs == 0:
            for loc in locations:
                await conn.execute(
                    "INSERT INTO locations (id, name, address, type, hours, latitude, longitude, is_active, sort_order) VALUES ($1,$2,$3,$4,$5,$6,$7,true,0)",
                    uuid.uuid4(), loc["name"], loc["address"], loc["type"], loc["hours"],
                    Decimal(loc["lat"]), Decimal(loc["lon"]),
                )
            print(f"Inserted {len(locations)} locations")

        # Summary
        total_p = await conn.fetchval("SELECT COUNT(*) FROM products")
        total_c = await conn.fetchval("SELECT COUNT(*) FROM categories")
        total_sc = await conn.fetchval("SELECT COUNT(*) FROM subcategories")
        total_f = await conn.fetchval("SELECT COUNT(*) FROM products WHERE is_featured = true")
        total_l = await conn.fetchval("SELECT COUNT(*) FROM locations")

        print(f"\n{'=' * 60}")
        print(f"DATABASE READY")
        print(f"  Categories:    {total_c}")
        print(f"  Subcategories: {total_sc}")
        print(f"  Products:      {total_p} ({total_f} on sale)")
        print(f"  Locations:     {total_l}")
        print(f"{'=' * 60}")

    finally:
        await conn.close()


if __name__ == "__main__":
    asyncio.run(main())
