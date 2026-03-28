"use client";

import { useEffect } from "react";
import { useParams, useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useProducts, useUpdateProduct } from "@/hooks/use-products";
import { useCategories } from "@/hooks/use-categories";
import { toast } from "sonner";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Loader2, ArrowLeft } from "lucide-react";
import Link from "next/link";
import type { Product } from "@/types/product";

interface ProductFormValues {
  name: string;
  slug: string;
  sku: string;
  description: string;
  price: number;
  original_price?: number;
  category_id: string;
  subcategory_id?: string;
  image_url: string;
  sizes?: string;
  colors?: string;
  stock: number;
  is_active: boolean;
  is_featured: boolean;
}

const productSchema = z.object({
  name: z.string().min(1, "Обязательное поле"),
  slug: z.string().min(1, "Обязательное поле"),
  sku: z.string().min(1, "Обязательное поле"),
  description: z.string().min(1, "Обязательное поле"),
  price: z.coerce.number().min(0, "Цена >= 0"),
  original_price: z.coerce.number().min(0).optional(),
  category_id: z.string().min(1, "Выберите категорию"),
  subcategory_id: z.string().optional(),
  image_url: z.string().url("Введите URL изображения"),
  sizes: z.string().optional(),
  colors: z.string().optional(),
  stock: z.coerce.number().int().min(0, "Остаток >= 0"),
  is_active: z.boolean(),
  is_featured: z.boolean(),
});

function slugify(str: string) {
  return str
    .toLowerCase()
    .replace(/[^\w\s-]/g, "")
    .replace(/\s+/g, "-")
    .replace(/-+/g, "-")
    .trim();
}

export default function EditProductPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const id = params.id;

  const { data: productsData, isLoading } = useProducts();
  const product = productsData?.items.find((p: Product) => p.id === id);

  const updateProduct = useUpdateProduct();
  const { data: categories } = useCategories();

  const {
    register,
    handleSubmit,
    watch,
    setValue,
    reset,
    formState: { errors },
  } = useForm<ProductFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(productSchema) as any,
    defaultValues: {
      name: "",
      slug: "",
      sku: "",
      description: "",
      price: 0,
      original_price: 0,
      category_id: "",
      subcategory_id: "",
      image_url: "",
      sizes: "",
      colors: "",
      stock: 0,
      is_active: true,
      is_featured: false,
    },
  });

  useEffect(() => {
    if (product) {
      reset({
        name: product.name,
        slug: product.slug,
        sku: product.sku,
        description: product.description,
        price: product.price,
        original_price: product.original_price,
        category_id: product.category_id,
        subcategory_id: product.subcategory_id ?? "",
        image_url: product.image_url,
        sizes: product.sizes?.join(", ") ?? "",
        colors: product.colors?.join(", ") ?? "",
        stock: product.stock,
        is_active: product.is_active,
        is_featured: product.is_featured,
      });
    }
  }, [product, reset]);

  const watchCategoryId = watch("category_id");
  const subcategories =
    categories?.find((c) => c.id === watchCategoryId)?.subcategories ?? [];

  const onSubmit = (values: ProductFormValues) => {
    const payload = {
      id,
      ...values,
      sizes: values.sizes
        ? values.sizes.split(",").map((s) => s.trim()).filter(Boolean)
        : [],
      colors: values.colors
        ? values.colors.split(",").map((s) => s.trim()).filter(Boolean)
        : [],
      subcategory_id: values.subcategory_id || null,
      original_price: values.original_price ?? 0,
    };

    updateProduct.mutate(payload, {
      onSuccess: () => {
        toast.success("Товар обновлен");
        router.push("/products");
      },
      onError: () => toast.error("Ошибка обновления товара"),
    });
  };

  if (isLoading) {
    return (
      <div className="space-y-6">
        <Skeleton className="h-8 w-48" />
        <Skeleton className="h-[600px] w-full" />
      </div>
    );
  }

  if (!product) {
    return (
      <div className="space-y-4">
        <h1 className="text-2xl font-semibold">Товар не найден</h1>
        <Button variant="outline" asChild>
          <Link href="/products">Назад к товарам</Link>
        </Button>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="icon" asChild>
          <Link href="/products">
            <ArrowLeft />
          </Link>
        </Button>
        <h1 className="text-2xl font-semibold tracking-tight">
          Редактирование: {product.name}
        </h1>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Информация о товаре</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit(onSubmit)} className="grid gap-4 md:grid-cols-2">
            <div className="grid gap-1.5">
              <Label htmlFor="name">Название</Label>
              <Input
                id="name"
                {...register("name", {
                  onChange: (e) => setValue("slug", slugify(e.target.value)),
                })}
                aria-invalid={!!errors.name}
              />
              {errors.name && (
                <p className="text-xs text-destructive">{errors.name.message}</p>
              )}
            </div>

            <div className="grid gap-1.5">
              <Label htmlFor="slug">Slug</Label>
              <Input id="slug" {...register("slug")} aria-invalid={!!errors.slug} />
              {errors.slug && (
                <p className="text-xs text-destructive">{errors.slug.message}</p>
              )}
            </div>

            <div className="grid gap-1.5">
              <Label htmlFor="sku">SKU</Label>
              <Input id="sku" {...register("sku")} aria-invalid={!!errors.sku} />
              {errors.sku && (
                <p className="text-xs text-destructive">{errors.sku.message}</p>
              )}
            </div>

            <div className="grid gap-1.5">
              <Label htmlFor="image_url">URL изображения</Label>
              <Input
                id="image_url"
                {...register("image_url")}
                aria-invalid={!!errors.image_url}
              />
              {errors.image_url && (
                <p className="text-xs text-destructive">
                  {errors.image_url.message}
                </p>
              )}
            </div>

            <div className="grid gap-1.5 md:col-span-2">
              <Label htmlFor="description">Описание</Label>
              <Textarea
                id="description"
                rows={3}
                {...register("description")}
                aria-invalid={!!errors.description}
              />
              {errors.description && (
                <p className="text-xs text-destructive">
                  {errors.description.message}
                </p>
              )}
            </div>

            <div className="grid gap-1.5">
              <Label htmlFor="price">Цена (KGS)</Label>
              <Input
                id="price"
                type="number"
                step="0.01"
                {...register("price")}
                aria-invalid={!!errors.price}
              />
              {errors.price && (
                <p className="text-xs text-destructive">{errors.price.message}</p>
              )}
            </div>

            <div className="grid gap-1.5">
              <Label htmlFor="original_price">Старая цена (KGS)</Label>
              <Input
                id="original_price"
                type="number"
                step="0.01"
                {...register("original_price")}
              />
            </div>

            <div className="grid gap-1.5">
              <Label>Категория</Label>
              <Select
                value={watchCategoryId}
                onValueChange={(val) => {
                  setValue("category_id", val);
                  setValue("subcategory_id", "");
                }}
              >
                <SelectTrigger className="w-full" aria-invalid={!!errors.category_id}>
                  <SelectValue placeholder="Выберите категорию" />
                </SelectTrigger>
                <SelectContent>
                  {categories?.map((cat) => (
                    <SelectItem key={cat.id} value={cat.id}>
                      {cat.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              {errors.category_id && (
                <p className="text-xs text-destructive">
                  {errors.category_id.message}
                </p>
              )}
            </div>

            <div className="grid gap-1.5">
              <Label>Подкатегория</Label>
              <Select
                value={watch("subcategory_id") ?? ""}
                onValueChange={(val) => setValue("subcategory_id", val)}
                disabled={subcategories.length === 0}
              >
                <SelectTrigger className="w-full">
                  <SelectValue placeholder="Выберите подкатегорию" />
                </SelectTrigger>
                <SelectContent>
                  {subcategories.map((sub) => (
                    <SelectItem key={sub.id} value={sub.id}>
                      {sub.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="grid gap-1.5">
              <Label htmlFor="sizes">Размеры (через запятую)</Label>
              <Input id="sizes" placeholder="S, M, L, XL" {...register("sizes")} />
            </div>

            <div className="grid gap-1.5">
              <Label htmlFor="colors">Цвета (через запятую)</Label>
              <Input
                id="colors"
                placeholder="Черный, Белый"
                {...register("colors")}
              />
            </div>

            <div className="grid gap-1.5">
              <Label htmlFor="stock">Остаток</Label>
              <Input
                id="stock"
                type="number"
                {...register("stock")}
                aria-invalid={!!errors.stock}
              />
              {errors.stock && (
                <p className="text-xs text-destructive">{errors.stock.message}</p>
              )}
            </div>

            <div className="flex flex-wrap items-center gap-6">
              <div className="flex items-center gap-2">
                <Switch
                  id="is_active"
                  checked={watch("is_active")}
                  onCheckedChange={(checked: boolean) =>
                    setValue("is_active", checked)
                  }
                />
                <Label htmlFor="is_active">Активен</Label>
              </div>
              <div className="flex items-center gap-2">
                <Switch
                  id="is_featured"
                  checked={watch("is_featured")}
                  onCheckedChange={(checked: boolean) =>
                    setValue("is_featured", checked)
                  }
                />
                <Label htmlFor="is_featured">Рекомендуемый</Label>
              </div>
            </div>

            <div className="md:col-span-2">
              <Button
                type="submit"
                disabled={updateProduct.isPending}
                className="w-full sm:w-auto"
              >
                {updateProduct.isPending && (
                  <Loader2 className="mr-2 size-4 animate-spin" />
                )}
                Сохранить изменения
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
