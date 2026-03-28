export interface Product {
  id: string;
  sku: string;
  name: string;
  slug: string;
  description: string;
  price: number;
  original_price: number;
  category_id: string;
  subcategory_id: string | null;
  image_url: string;
  images: string[];
  sizes: string[];
  colors: string[];
  stock: number;
  is_active: boolean;
  is_featured: boolean;
  sort_order: number;
  metadata: Record<string, unknown>;
  created_at: string;
  updated_at: string;
}

export interface ProductCreate {
  sku: string;
  name: string;
  slug: string;
  description: string;
  price: number;
  original_price?: number;
  category_id: string;
  subcategory_id?: string | null;
  image_url: string;
  images?: string[];
  sizes?: string[];
  colors?: string[];
  stock: number;
  is_active?: boolean;
  is_featured?: boolean;
  sort_order?: number;
  metadata?: Record<string, unknown>;
}

export interface ProductUpdate {
  sku?: string;
  name?: string;
  slug?: string;
  description?: string;
  price?: number;
  original_price?: number;
  category_id?: string;
  subcategory_id?: string | null;
  image_url?: string;
  images?: string[];
  sizes?: string[];
  colors?: string[];
  stock?: number;
  is_active?: boolean;
  is_featured?: boolean;
  sort_order?: number;
  metadata?: Record<string, unknown>;
}

export interface Category {
  id: string;
  name: string;
  slug: string;
  sort_order: number;
  subcategories: Subcategory[];
}

export interface Subcategory {
  id: string;
  category_id: string;
  name: string;
  slug: string;
  sort_order: number;
}

export interface CategoryCreate {
  name: string;
  slug: string;
  sort_order?: number;
}

export interface SubcategoryCreate {
  category_id: string;
  name: string;
  slug: string;
  sort_order?: number;
}

export interface CategoryUpdate {
  name?: string;
  slug?: string;
  sort_order?: number;
}

export interface SubcategoryUpdate {
  category_id?: string;
  name?: string;
  slug?: string;
  sort_order?: number;
}
