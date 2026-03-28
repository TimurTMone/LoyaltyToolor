"use client";

import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useCreateProduct } from "@/hooks/use-products";
import { useCategories } from "@/hooks/use-categories";
import { toast } from "sonner";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Loader2, ArrowLeft } from "lucide-react";
import Link from "next/link";

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

export default function CreateProductPage() {
  const router = useRouter();
  const createProduct = useCreateProduct();
  const { data: categories } = useCategories();

  const {
    register,
    handleSubmit,
    watch,
    setValue,
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
      original_price: undefined,
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

  const watchCategoryId = watch("category_id");
  const subcategories =
    categories?.find((c) => c.id === watchCategoryId)?.subcategories ?? [];

  const onSubmit = (values: ProductFormValues) => {
    const payload = {
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

    createProduct.mutate(payload, {
      onSuccess: () => {
        toast.success("Товар создан");
        router.push("/products");
      },
      onError: () => toast.error("Ошибка создания товара"),
    });
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="icon" asChild>
          <Link href="/products">
            <ArrowLeft />
          </Link>
        </Button>
        <h1 className="text-2xl font-semibold tracking-tight">
          Новый товар
        </h1>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Информация о товаре</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit(onSubmit)} className="grid gap-4 md:grid-cols-2">
            {/* Name */}
            <div className="grid gap-1.5">
              <Label htmlFor="name">Название</Label>
              <Input
                id="name"
                {...register("name", {
                  onChange: (e) => {
                    setValue("slug", slugify(e.target.value));
                  },
                })}
                aria-invalid={!!errors.name}
              />
              {errors.name && (
                <p className="text-xs text-destructive">{errors.name.message}</p>
              )}
            </div>

            {/* Slug */}
            <div className="grid gap-1.5">
              <Label htmlFor="slug">Slug</Label>
              <Input id="slug" {...register("slug")} aria-invalid={!!errors.slug} />
              {errors.slug && (
                <p className="text-xs text-destructive">{errors.slug.message}</p>
              )}
            </div>

            {/* SKU */}
            <div className="grid gap-1.5">
              <Label htmlFor="sku">SKU</Label>
              <Input id="sku" {...register("sku")} aria-invalid={!!errors.sku} />
              {errors.sku && (
                <p className="text-xs text-destructive">{errors.sku.message}</p>
              )}
            </div>

            {/* Image URL */}
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

            {/* Description */}
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

            {/* Price */}
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

            {/* Original Price */}
            <div className="grid gap-1.5">
              <Label htmlFor="original_price">Старая цена (KGS)</Label>
              <Input
                id="original_price"
                type="number"
                step="0.01"
                {...register("original_price")}
              />
            </div>

            {/* Category */}
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

            {/* Subcategory */}
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

            {/* Sizes */}
            <div className="grid gap-1.5">
              <Label htmlFor="sizes">Размеры (через запятую)</Label>
              <Input
                id="sizes"
                placeholder="S, M, L, XL"
                {...register("sizes")}
              />
            </div>

            {/* Colors */}
            <div className="grid gap-1.5">
              <Label htmlFor="colors">Цвета (через запятую)</Label>
              <Input
                id="colors"
                placeholder="Черный, Белый"
                {...register("colors")}
              />
            </div>

            {/* Stock */}
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

            {/* Switches */}
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

            {/* Submit */}
            <div className="md:col-span-2">
              <Button
                type="submit"
                disabled={createProduct.isPending}
                className="w-full sm:w-auto"
              >
                {createProduct.isPending && (
                  <Loader2 className="mr-2 size-4 animate-spin" />
                )}
                Создать товар
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
