"use client";

import { useState } from "react";
import {
  useCategories,
  useCreateCategory,
  useUpdateCategory,
  useDeleteCategory,
  useCreateSubcategory,
  useUpdateSubcategory,
  useDeleteSubcategory,
} from "@/hooks/use-categories";
import { toast } from "sonner";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import {
  ChevronDown,
  ChevronRight,
  Plus,
  Pencil,
  Trash2,
  Loader2,
} from "lucide-react";
import type { Category, Subcategory } from "@/types/product";

function slugify(str: string) {
  return str
    .toLowerCase()
    .replace(/[^\w\s-]/g, "")
    .replace(/\s+/g, "-")
    .replace(/-+/g, "-")
    .trim();
}

type DialogMode =
  | { type: "create-category" }
  | { type: "edit-category"; category: Category }
  | { type: "create-subcategory"; categoryId: string }
  | { type: "edit-subcategory"; subcategory: Subcategory }
  | null;

export default function CategoriesPage() {
  const { data: categories, isLoading } = useCategories();
  const createCategory = useCreateCategory();
  const updateCategory = useUpdateCategory();
  const deleteCategory = useDeleteCategory();
  const createSubcategory = useCreateSubcategory();
  const updateSubcategory = useUpdateSubcategory();
  const deleteSubcategory = useDeleteSubcategory();

  const [expanded, setExpanded] = useState<Set<string>>(new Set());
  const [dialog, setDialog] = useState<DialogMode>(null);
  const [formName, setFormName] = useState("");
  const [formSlug, setFormSlug] = useState("");
  const [formSortOrder, setFormSortOrder] = useState(0);

  const toggle = (id: string) => {
    setExpanded((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const openDialog = (mode: DialogMode) => {
    setDialog(mode);
    if (mode?.type === "edit-category") {
      setFormName(mode.category.name);
      setFormSlug(mode.category.slug);
      setFormSortOrder(mode.category.sort_order);
    } else if (mode?.type === "edit-subcategory") {
      setFormName(mode.subcategory.name);
      setFormSlug(mode.subcategory.slug);
      setFormSortOrder(mode.subcategory.sort_order);
    } else {
      setFormName("");
      setFormSlug("");
      setFormSortOrder(0);
    }
  };

  const isPending =
    createCategory.isPending ||
    updateCategory.isPending ||
    createSubcategory.isPending ||
    updateSubcategory.isPending;

  const handleSubmit = () => {
    if (!formName.trim()) {
      toast.error("Введите название");
      return;
    }

    const slug = formSlug || slugify(formName);

    if (dialog?.type === "create-category") {
      createCategory.mutate(
        { name: formName, slug, sort_order: formSortOrder },
        {
          onSuccess: () => {
            toast.success("Категория создана");
            setDialog(null);
          },
          onError: () => toast.error("Ошибка создания"),
        }
      );
    } else if (dialog?.type === "edit-category") {
      updateCategory.mutate(
        {
          id: dialog.category.id,
          name: formName,
          slug,
          sort_order: formSortOrder,
        },
        {
          onSuccess: () => {
            toast.success("Категория обновлена");
            setDialog(null);
          },
          onError: () => toast.error("Ошибка обновления"),
        }
      );
    } else if (dialog?.type === "create-subcategory") {
      createSubcategory.mutate(
        {
          category_id: dialog.categoryId,
          name: formName,
          slug,
          sort_order: formSortOrder,
        },
        {
          onSuccess: () => {
            toast.success("Подкатегория создана");
            setDialog(null);
          },
          onError: () => toast.error("Ошибка создания"),
        }
      );
    } else if (dialog?.type === "edit-subcategory") {
      updateSubcategory.mutate(
        {
          id: dialog.subcategory.id,
          name: formName,
          slug,
          sort_order: formSortOrder,
        },
        {
          onSuccess: () => {
            toast.success("Подкатегория обновлена");
            setDialog(null);
          },
          onError: () => toast.error("Ошибка обновления"),
        }
      );
    }
  };

  const handleDeleteCategory = (id: string, name: string) => {
    if (!confirm(`Удалить категорию "${name}" и все подкатегории?`)) return;
    deleteCategory.mutate(id, {
      onSuccess: () => toast.success("Категория удалена"),
      onError: () => toast.error("Ошибка удаления"),
    });
  };

  const handleDeleteSubcategory = (id: string, name: string) => {
    if (!confirm(`Удалить подкатегорию "${name}"?`)) return;
    deleteSubcategory.mutate(id, {
      onSuccess: () => toast.success("Подкатегория удалена"),
      onError: () => toast.error("Ошибка удаления"),
    });
  };

  const dialogTitle =
    dialog?.type === "create-category"
      ? "Новая категория"
      : dialog?.type === "edit-category"
        ? "Редактировать категорию"
        : dialog?.type === "create-subcategory"
          ? "Новая подкатегория"
          : dialog?.type === "edit-subcategory"
            ? "Редактировать подкатегорию"
            : "";

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold tracking-tight">Категории</h1>
        <Button onClick={() => openDialog({ type: "create-category" })}>
          <Plus data-icon="inline-start" />
          Добавить категорию
        </Button>
      </div>

      {isLoading ? (
        <div className="space-y-3">
          {Array.from({ length: 4 }).map((_, i) => (
            <Skeleton key={i} className="h-16 w-full" />
          ))}
        </div>
      ) : (
        <div className="space-y-2">
          {categories?.map((cat) => (
            <Card key={cat.id}>
              <CardHeader className="flex flex-row items-center justify-between py-3">
                <button
                  onClick={() => toggle(cat.id)}
                  className="flex items-center gap-2 text-left"
                >
                  {expanded.has(cat.id) ? (
                    <ChevronDown className="size-4" />
                  ) : (
                    <ChevronRight className="size-4" />
                  )}
                  <CardTitle className="text-base">{cat.name}</CardTitle>
                  <span className="text-xs text-muted-foreground">
                    ({cat.subcategories.length} подкатегорий)
                  </span>
                </button>
                <div className="flex items-center gap-1">
                  <Button
                    variant="ghost"
                    size="icon-sm"
                    onClick={() =>
                      openDialog({ type: "edit-category", category: cat })
                    }
                  >
                    <Pencil />
                  </Button>
                  <Button
                    variant="ghost"
                    size="icon-sm"
                    onClick={() => handleDeleteCategory(cat.id, cat.name)}
                  >
                    <Trash2 className="text-destructive" />
                  </Button>
                </div>
              </CardHeader>

              {expanded.has(cat.id) && (
                <CardContent className="pt-0">
                  <div className="ml-6 space-y-1">
                    {cat.subcategories.map((sub) => (
                      <div
                        key={sub.id}
                        className="flex items-center justify-between rounded-md px-3 py-2 hover:bg-muted/50"
                      >
                        <span className="text-sm">{sub.name}</span>
                        <div className="flex items-center gap-1">
                          <Button
                            variant="ghost"
                            size="icon-xs"
                            onClick={() =>
                              openDialog({
                                type: "edit-subcategory",
                                subcategory: sub,
                              })
                            }
                          >
                            <Pencil />
                          </Button>
                          <Button
                            variant="ghost"
                            size="icon-xs"
                            onClick={() =>
                              handleDeleteSubcategory(sub.id, sub.name)
                            }
                          >
                            <Trash2 className="text-destructive" />
                          </Button>
                        </div>
                      </div>
                    ))}

                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() =>
                        openDialog({
                          type: "create-subcategory",
                          categoryId: cat.id,
                        })
                      }
                      className="mt-1"
                    >
                      <Plus data-icon="inline-start" />
                      Добавить подкатегорию
                    </Button>
                  </div>
                </CardContent>
              )}
            </Card>
          ))}

          {categories?.length === 0 && (
            <p className="text-sm text-muted-foreground">
              Категории не найдены
            </p>
          )}
        </div>
      )}

      {/* Dialog for create/edit */}
      <Dialog open={dialog !== null} onOpenChange={(open) => !open && setDialog(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{dialogTitle}</DialogTitle>
          </DialogHeader>
          <div className="grid gap-4">
            <div className="grid gap-1.5">
              <Label htmlFor="cat_name">Название</Label>
              <Input
                id="cat_name"
                value={formName}
                onChange={(e) => {
                  setFormName(e.target.value);
                  if (
                    dialog?.type === "create-category" ||
                    dialog?.type === "create-subcategory"
                  ) {
                    setFormSlug(slugify(e.target.value));
                  }
                }}
              />
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor="cat_slug">Slug</Label>
              <Input
                id="cat_slug"
                value={formSlug}
                onChange={(e) => setFormSlug(e.target.value)}
              />
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor="cat_sort">Порядок сортировки</Label>
              <Input
                id="cat_sort"
                type="number"
                value={formSortOrder}
                onChange={(e) => setFormSortOrder(Number(e.target.value))}
              />
            </div>
          </div>
          <DialogFooter>
            <Button onClick={handleSubmit} disabled={isPending}>
              {isPending && (
                <Loader2 className="mr-2 size-4 animate-spin" />
              )}
              Сохранить
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
