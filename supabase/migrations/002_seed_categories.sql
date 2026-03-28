-- ============================================================
-- TOOLOR — Seed: Categories & Subcategories
-- ============================================================
-- Matches the constants from lib/data/toolor_products.dart:
--   ProductCategory and ProductSubcategory classes.
-- ============================================================

BEGIN;

-- ── Categories ───────────────────────────────────────────────

INSERT INTO categories (name, slug, sort_order) VALUES
  ('Мужчинам',    'men',         1),
  ('Женщинам',    'women',       2),
  ('Аксессуары',  'accessories', 3),
  ('Скидки',      'sale',        4);

-- ── Subcategories ────────────────────────────────────────────

-- Shared clothing subcategories
INSERT INTO subcategories (category_id, name, slug, sort_order) VALUES
  ((SELECT id FROM categories WHERE slug = 'men'), 'Футболки',           'tshirts',       1),
  ((SELECT id FROM categories WHERE slug = 'men'), 'Лонгсливы',          'longsleeves',   2),
  ((SELECT id FROM categories WHERE slug = 'men'), 'Свитшоты',           'sweatshirts',   3),
  ((SELECT id FROM categories WHERE slug = 'men'), 'Худи',               'hoodies',       4),
  ((SELECT id FROM categories WHERE slug = 'men'), 'Рубашки',            'shirts',        5),
  ((SELECT id FROM categories WHERE slug = 'men'), 'Вязаный трикотаж',   'knitwear',      6),
  ((SELECT id FROM categories WHERE slug = 'men'), 'Брюки',              'pants',         7),
  ((SELECT id FROM categories WHERE slug = 'men'), 'Шорты',              'shorts',        8),
  ((SELECT id FROM categories WHERE slug = 'men'), 'Куртки',             'jackets',       9),
  ((SELECT id FROM categories WHERE slug = 'men'), 'Пуховики',           'down-jackets',  10),
  ((SELECT id FROM categories WHERE slug = 'men'), 'Ветровки',           'windbreakers',  11),
  ((SELECT id FROM categories WHERE slug = 'men'), 'Флис',               'fleece',        12),
  ((SELECT id FROM categories WHERE slug = 'men'), 'Жилеты',             'vests',         13),
  ((SELECT id FROM categories WHERE slug = 'men'), 'Костюмы',            'sets',          14),
  ((SELECT id FROM categories WHERE slug = 'men'), 'Кардиган',           'cardigans',     15),
  ((SELECT id FROM categories WHERE slug = 'men'), 'Свитер',             'sweaters',      16),
  ((SELECT id FROM categories WHERE slug = 'men'), 'Водолазки',          'turtlenecks',   17),
  ((SELECT id FROM categories WHERE slug = 'men'), 'Лайтдаун',           'lightdown',     18),
  ((SELECT id FROM categories WHERE slug = 'men'), 'Зипки',              'zippers',       19),
  ((SELECT id FROM categories WHERE slug = 'men'), 'Тренчи',             'trench',        20);

-- Women-specific subcategories (same names but linked to women category)
INSERT INTO subcategories (category_id, name, slug, sort_order) VALUES
  ((SELECT id FROM categories WHERE slug = 'women'), 'Боди',             'bodies',         1),
  ((SELECT id FROM categories WHERE slug = 'women'), 'Футболки',         'w-tshirts',      2),
  ((SELECT id FROM categories WHERE slug = 'women'), 'Лонгсливы',        'w-longsleeves',  3),
  ((SELECT id FROM categories WHERE slug = 'women'), 'Свитшоты',         'w-sweatshirts',  4),
  ((SELECT id FROM categories WHERE slug = 'women'), 'Худи',             'w-hoodies',      5),
  ((SELECT id FROM categories WHERE slug = 'women'), 'Рубашки',          'w-shirts',       6),
  ((SELECT id FROM categories WHERE slug = 'women'), 'Вязаный трикотаж', 'w-knitwear',     7),
  ((SELECT id FROM categories WHERE slug = 'women'), 'Брюки',            'w-pants',        8),
  ((SELECT id FROM categories WHERE slug = 'women'), 'Куртки',           'w-jackets',      9),
  ((SELECT id FROM categories WHERE slug = 'women'), 'Пуховики',         'w-down-jackets', 10),
  ((SELECT id FROM categories WHERE slug = 'women'), 'Ветровки',         'w-windbreakers', 11),
  ((SELECT id FROM categories WHERE slug = 'women'), 'Флис',             'w-fleece',       12),
  ((SELECT id FROM categories WHERE slug = 'women'), 'Жилеты',           'w-vests',        13),
  ((SELECT id FROM categories WHERE slug = 'women'), 'Костюмы',          'w-sets',         14),
  ((SELECT id FROM categories WHERE slug = 'women'), 'Кардиган',         'w-cardigans',    15),
  ((SELECT id FROM categories WHERE slug = 'women'), 'Свитер',           'w-sweaters',     16),
  ((SELECT id FROM categories WHERE slug = 'women'), 'Водолазки',        'w-turtlenecks',  17),
  ((SELECT id FROM categories WHERE slug = 'women'), 'Лайтдаун',         'w-lightdown',    18),
  ((SELECT id FROM categories WHERE slug = 'women'), 'Зипки',            'w-zippers',      19),
  ((SELECT id FROM categories WHERE slug = 'women'), 'Тренчи',           'w-trench',       20);

-- Accessories subcategories
INSERT INTO subcategories (category_id, name, slug, sort_order) VALUES
  ((SELECT id FROM categories WHERE slug = 'accessories'), 'Шарфы',      'scarves',  1),
  ((SELECT id FROM categories WHERE slug = 'accessories'), 'Сумки',      'bags',     2),
  ((SELECT id FROM categories WHERE slug = 'accessories'), 'Кепки',      'caps',     3),
  ((SELECT id FROM categories WHERE slug = 'accessories'), 'Шапки',      'hats',     4),
  ((SELECT id FROM categories WHERE slug = 'accessories'), 'Чехлы',      'cases',    5),
  ((SELECT id FROM categories WHERE slug = 'accessories'), 'Другое',     'other',    6);

-- Sale subcategories (mirror the main ones used in sale items)
INSERT INTO subcategories (category_id, name, slug, sort_order) VALUES
  ((SELECT id FROM categories WHERE slug = 'sale'), 'Куртки',            's-jackets',      1),
  ((SELECT id FROM categories WHERE slug = 'sale'), 'Пуховики',          's-down-jackets', 2),
  ((SELECT id FROM categories WHERE slug = 'sale'), 'Ветровки',          's-windbreakers', 3),
  ((SELECT id FROM categories WHERE slug = 'sale'), 'Флис',              's-fleece',       4),
  ((SELECT id FROM categories WHERE slug = 'sale'), 'Жилеты',            's-vests',        5),
  ((SELECT id FROM categories WHERE slug = 'sale'), 'Костюмы',           's-sets',         6),
  ((SELECT id FROM categories WHERE slug = 'sale'), 'Худи',              's-hoodies',      7),
  ((SELECT id FROM categories WHERE slug = 'sale'), 'Свитшоты',          's-sweatshirts',  8),
  ((SELECT id FROM categories WHERE slug = 'sale'), 'Футболки',          's-tshirts',      9),
  ((SELECT id FROM categories WHERE slug = 'sale'), 'Брюки',             's-pants',        10),
  ((SELECT id FROM categories WHERE slug = 'sale'), 'Шорты',             's-shorts',       11),
  ((SELECT id FROM categories WHERE slug = 'sale'), 'Лайтдаун',          's-lightdown',    12),
  ((SELECT id FROM categories WHERE slug = 'sale'), 'Тренчи',            's-trench',       13);

COMMIT;
