"""
TOOLOR Product Scraper + Database Seeder

Agent 1: Scrapes all 113 products from toolorkg.com using sitemap + JSON-LD
Agent 2: Seeds them into the Neon PostgreSQL database

Usage: python scrape_and_seed.py
"""

import asyncio
import json
import re
import uuid
import xml.etree.ElementTree as ET
from decimal import Decimal
from html import unescape
from urllib.parse import urlparse

import httpx
import asyncpg

DATABASE_URL = "postgresql://neondb_owner:npg_3NKgvsFrW5io@ep-blue-boat-amiwae15-pooler.c-5.us-east-1.aws.neon.tech/neondb?sslmode=require"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "ru-RU,ru;q=0.9,en;q=0.8",
}

# ── Agent 1: Scraper ────────────────────────────────────────────────────

def extract_json_ld(html: str) -> dict | None:
    """Extract Product JSON-LD from page HTML."""
    pattern = r'<script[^>]*type=["\']application/ld\+json["\'][^>]*>(.*?)</script>'
    matches = re.findall(pattern, html, re.DOTALL)
    for match in matches:
        try:
            data = json.loads(match)
            # Could be a single object or a graph
            if isinstance(data, dict):
                if data.get("@type") == "Product":
                    return data
                if "@graph" in data:
                    for item in data["@graph"]:
                        if item.get("@type") == "Product":
                            return item
            elif isinstance(data, list):
                for item in data:
                    if isinstance(item, dict) and item.get("@type") == "Product":
                        return item
        except json.JSONDecodeError:
            continue
    return None


def extract_breadcrumbs(html: str) -> list[str]:
    """Extract category hierarchy from BreadcrumbList JSON-LD."""
    pattern = r'<script[^>]*type=["\']application/ld\+json["\'][^>]*>(.*?)</script>'
    matches = re.findall(pattern, html, re.DOTALL)
    for match in matches:
        try:
            data = json.loads(match)
            items = None
            if isinstance(data, dict):
                if data.get("@type") == "BreadcrumbList":
                    items = data.get("itemListElement", [])
                elif "@graph" in data:
                    for item in data["@graph"]:
                        if item.get("@type") == "BreadcrumbList":
                            items = item.get("itemListElement", [])
                            break
            if items:
                return [item.get("name", "") for item in sorted(items, key=lambda x: x.get("position", 0))]
        except json.JSONDecodeError:
            continue
    return []


def extract_variations(html: str) -> tuple[list[str], list[str]]:
    """Extract sizes and colors from variation dropdowns."""
    sizes = []
    colors = []

    # Size: look for option values in the size select
    size_pattern = r'<select[^>]*id="pa_razmer"[^>]*>(.*?)</select>'
    size_match = re.search(size_pattern, html, re.DOTALL)
    if size_match:
        options = re.findall(r'value="([^"]+)"', size_match.group(1))
        sizes = [opt for opt in options if opt]  # filter empty

    # Color: look for option values in the color select
    color_pattern = r'<select[^>]*id="pa_tsvet"[^>]*>(.*?)</select>'
    color_match = re.search(color_pattern, html, re.DOTALL)
    if color_match:
        options = re.findall(r'value="([^"]+)"', color_match.group(1))
        colors = [opt for opt in options if opt]

    # Clean up size labels (e.g., "s-42" -> "S (42)")
    clean_sizes = []
    for s in sizes:
        s_clean = s.replace("-", " ").strip()
        # Try to make it nicer: "xl-48" -> "XL"
        parts = s_clean.split()
        if parts:
            label = parts[0].upper()
            if len(parts) > 1 and parts[1].isdigit():
                label = f"{label} ({parts[1]})"
            clean_sizes.append(label)

    # Clean up color labels
    clean_colors = [c.replace("-", " ").strip().capitalize() for c in colors]

    return clean_sizes, clean_colors


def extract_gallery_images(html: str) -> list[str]:
    """Extract all product gallery images."""
    images = []

    # Look for data-large_image or data-src in gallery
    gallery_pattern = r'data-large_image="([^"]+)"'
    matches = re.findall(gallery_pattern, html)
    if matches:
        for url in matches:
            # Get original URL, strip ShortPixel CDN wrapper
            clean = re.sub(r'https://sp-ao\.shortpixel\.ai/client/[^/]+/', '', url)
            if clean.startswith('http'):
                images.append(clean)
            else:
                images.append(url)

    if not images:
        # Fallback: get from og:image or JSON-LD
        og_pattern = r'<meta[^>]*property="og:image"[^>]*content="([^"]+)"'
        og_match = re.search(og_pattern, html)
        if og_match:
            images.append(og_match.group(1))

    return images


def extract_sale_price(html: str) -> tuple[Decimal | None, Decimal | None]:
    """Extract original and sale price from HTML."""
    # Look for "Первоначальная цена" (original price) pattern
    orig_pattern = r'Первоначальная цена[^:]*:\s*([\d\s,.]+)'
    current_pattern = r'Текущая цена[^:]*:\s*([\d\s,.]+)'

    orig_match = re.search(orig_pattern, html)
    current_match = re.search(current_pattern, html)

    if orig_match and current_match:
        orig = orig_match.group(1).replace(" ", "").replace(",", ".").strip()
        current = current_match.group(1).replace(" ", "").replace(",", ".").strip()
        try:
            return Decimal(orig), Decimal(current)
        except Exception:
            pass

    return None, None


def clean_description(desc: str) -> str:
    """Clean HTML from description."""
    if not desc:
        return ""
    # Remove HTML tags
    text = re.sub(r'<[^>]+>', ' ', desc)
    text = unescape(text)
    text = re.sub(r'\s+', ' ', text).strip()
    return text[:1000]  # cap at 1000 chars


async def fetch_sitemap(client: httpx.AsyncClient) -> list[str]:
    """Fetch product URLs from sitemap."""
    resp = await client.get("https://toolorkg.com/product-sitemap.xml")
    if resp.status_code != 200:
        print(f"Sitemap fetch failed: {resp.status_code}")
        return []

    root = ET.fromstring(resp.text)
    ns = {"s": "http://www.sitemaps.org/schemas/sitemap/0.9"}
    urls = [loc.text for loc in root.findall(".//s:url/s:loc", ns) if loc.text]
    print(f"Found {len(urls)} product URLs in sitemap")
    return urls


async def scrape_product(client: httpx.AsyncClient, url: str, semaphore: asyncio.Semaphore) -> dict | None:
    """Scrape a single product page."""
    async with semaphore:
        try:
            resp = await client.get(url, follow_redirects=True)
            if resp.status_code != 200:
                print(f"  SKIP {url} — {resp.status_code}")
                return None

            html = resp.text
            json_ld = extract_json_ld(html)
            if not json_ld:
                print(f"  SKIP {url} — no JSON-LD")
                return None

            # Extract slug from URL
            path = urlparse(url).path.rstrip("/")
            slug = path.split("/")[-1]

            # Price from JSON-LD
            offers = json_ld.get("offers", {})
            if isinstance(offers, list):
                offers = offers[0] if offers else {}

            price_str = str(offers.get("price", "0")).replace(",", ".").replace(" ", "")
            try:
                price = Decimal(price_str)
            except Exception:
                price = Decimal("0")

            # Check for sale price in HTML
            original_price, sale_price = extract_sale_price(html)
            if sale_price and sale_price < price:
                original_price = price
                price = sale_price
            elif original_price and sale_price:
                price = sale_price

            # Variations
            sizes, colors = extract_variations(html)

            # Images
            images = extract_gallery_images(html)
            image_url = images[0] if images else (json_ld.get("image", "") if isinstance(json_ld.get("image"), str) else "")
            if isinstance(json_ld.get("image"), list):
                image_url = json_ld["image"][0] if json_ld["image"] else ""
                if not images:
                    images = json_ld["image"]

            # Breadcrumbs for category
            breadcrumbs = extract_breadcrumbs(html)
            # Typically: [Home, Category, Subcategory, Product]
            category = breadcrumbs[1] if len(breadcrumbs) > 1 else "Без категории"
            subcategory = breadcrumbs[2] if len(breadcrumbs) > 2 else category

            # If subcategory == product name, it means no subcategory
            if subcategory == json_ld.get("name", ""):
                subcategory = category

            # Description
            desc = clean_description(json_ld.get("description", ""))

            # SKU
            sku = json_ld.get("sku", "")

            product = {
                "name": json_ld.get("name", slug),
                "slug": slug,
                "sku": sku if sku else None,
                "description": desc,
                "price": price,
                "original_price": original_price,
                "image_url": image_url,
                "images": images,
                "sizes": sizes,
                "colors": colors,
                "category": category,
                "subcategory": subcategory,
                "stock": 50,  # default stock
                "url": url,
            }

            print(f"  OK {product['name']} — {price} KGS — {len(sizes)} sizes, {len(colors)} colors, {len(images)} imgs")
            return product

        except Exception as e:
            print(f"  ERROR {url}: {e}")
            return None


async def scrape_all() -> list[dict]:
    """Agent 1: Scrape all products from toolorkg.com."""
    print("=" * 60)
    print("AGENT 1: SCRAPER — Fetching products from toolorkg.com")
    print("=" * 60)

    async with httpx.AsyncClient(headers=HEADERS, timeout=30.0) as client:
        urls = await fetch_sitemap(client)
        if not urls:
            print("No URLs found, trying paginated shop...")
            # Fallback: scrape paginated shop
            urls = []
            for page in range(1, 9):
                resp = await client.get(f"https://toolorkg.com/shop/page/{page}/")
                if resp.status_code != 200:
                    break
                links = re.findall(r'href="(https://toolorkg\.com/product/[^"]+)"', resp.text)
                urls.extend(set(links))
                await asyncio.sleep(1)

        print(f"\nScraping {len(urls)} products (5 concurrent)...\n")

        semaphore = asyncio.Semaphore(5)
        tasks = [scrape_product(client, url, semaphore) for url in urls]
        results = await asyncio.gather(*tasks)

    products = [p for p in results if p]
    print(f"\nScraped {len(products)} products successfully")
    return products


# ── Agent 2: Seeder ─────────────────────────────────────────────────────

def slugify(text: str) -> str:
    """Simple slugify."""
    text = text.lower().strip()
    text = re.sub(r'[^\w\s-]', '', text)
    text = re.sub(r'[\s_]+', '-', text)
    text = re.sub(r'-+', '-', text).strip('-')
    return text or "unknown"


async def seed_database(products: list[dict]):
    """Agent 2: Seed all scraped products into the database."""
    print("\n" + "=" * 60)
    print("AGENT 2: SEEDER — Populating database")
    print("=" * 60)

    conn = await asyncpg.connect(DATABASE_URL, ssl="require")

    try:
        # Clear existing data (respecting foreign keys)
        print("\nClearing old data...")
        await conn.execute("DELETE FROM store_inventory")
        await conn.execute("DELETE FROM order_items")
        await conn.execute("DELETE FROM cart_items")
        await conn.execute("DELETE FROM favorites")
        await conn.execute("DELETE FROM products")
        await conn.execute("DELETE FROM subcategories")
        await conn.execute("DELETE FROM categories")

        # Collect unique categories and subcategories
        cat_map: dict[str, uuid.UUID] = {}
        subcat_map: dict[str, tuple[uuid.UUID, str]] = {}  # slug -> (id, cat_name)

        for p in products:
            cat_name = p["category"]
            subcat_name = p["subcategory"]

            if cat_name not in cat_map:
                cat_map[cat_name] = uuid.uuid4()

            subcat_key = f"{cat_name}::{subcat_name}"
            if subcat_key not in subcat_map:
                subcat_map[subcat_key] = (uuid.uuid4(), cat_name)

        # Insert categories
        print(f"\nInserting {len(cat_map)} categories...")
        for i, (name, cid) in enumerate(cat_map.items()):
            await conn.execute(
                "INSERT INTO categories (id, name, slug, sort_order) VALUES ($1, $2, $3, $4)",
                cid, name, slugify(name), i + 1,
            )

        # Insert subcategories
        print(f"Inserting {len(subcat_map)} subcategories...")
        for i, (key, (sid, cat_name)) in enumerate(subcat_map.items()):
            subcat_name = key.split("::", 1)[1]
            await conn.execute(
                "INSERT INTO subcategories (id, category_id, name, slug, sort_order) VALUES ($1, $2, $3, $4, $5)",
                sid, cat_map[cat_name], subcat_name, slugify(subcat_name), i + 1,
            )

        # Insert products
        print(f"Inserting {len(products)} products...")
        seen_slugs = set()
        seen_skus = set()
        inserted = 0

        for p in products:
            # Deduplicate slugs
            slug = p["slug"]
            if slug in seen_slugs:
                slug = f"{slug}-{uuid.uuid4().hex[:6]}"
            seen_slugs.add(slug)

            # Deduplicate SKUs
            sku = p.get("sku")
            if sku:
                if sku in seen_skus:
                    sku = None  # skip duplicate SKU
                else:
                    seen_skus.add(sku)

            cat_name = p["category"]
            subcat_key = f"{cat_name}::{p['subcategory']}"

            cat_id = cat_map[cat_name]
            subcat_id = subcat_map[subcat_key][0]

            price = p["price"]
            if price <= 0:
                continue

            original_price = p.get("original_price")
            is_featured = original_price is not None  # sale items are featured

            try:
                await conn.execute(
                    """INSERT INTO products
                       (id, sku, name, slug, description, price, original_price,
                        category_id, subcategory_id, image_url, images, sizes, colors,
                        stock, is_active, is_featured, sort_order)
                       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11::jsonb,$12::jsonb,$13::jsonb,$14,true,$15,0)""",
                    uuid.uuid4(),
                    sku,
                    p["name"],
                    slug,
                    p["description"],
                    price,
                    original_price,
                    cat_id,
                    subcat_id,
                    p["image_url"],
                    json.dumps(p["images"]),
                    json.dumps(p["sizes"]),
                    json.dumps(p["colors"]),
                    p.get("stock", 50),
                    is_featured,
                )
                inserted += 1
            except Exception as e:
                print(f"  SKIP {p['name']}: {e}")

        # Summary
        total_products = await conn.fetchval("SELECT COUNT(*) FROM products")
        total_cats = await conn.fetchval("SELECT COUNT(*) FROM categories")
        total_subcats = await conn.fetchval("SELECT COUNT(*) FROM subcategories")
        total_featured = await conn.fetchval("SELECT COUNT(*) FROM products WHERE is_featured = true")

        print(f"\n{'=' * 60}")
        print(f"DONE!")
        print(f"  Categories:    {total_cats}")
        print(f"  Subcategories: {total_subcats}")
        print(f"  Products:      {total_products} ({total_featured} on sale)")
        print(f"{'=' * 60}")

    finally:
        await conn.close()


# ── Main ────────────────────────────────────────────────────────────────

async def main():
    products = await scrape_all()
    if not products:
        print("No products scraped. Aborting seed.")
        return

    # Save scraped data as backup
    with open("scraped_products.json", "w", encoding="utf-8") as f:
        json.dump(
            [{**p, "price": str(p["price"]), "original_price": str(p["original_price"]) if p.get("original_price") else None} for p in products],
            f, ensure_ascii=False, indent=2,
        )
    print(f"\nSaved backup to scraped_products.json")

    await seed_database(products)


if __name__ == "__main__":
    asyncio.run(main())
