"use client";

import { useState } from "react";
import {
  usePromoCodes,
  useCreatePromoCode,
  useUpdatePromoCode,
  useDeletePromoCode,
} from "@/hooks/use-promo-codes";
import { toast } from "sonner";
import { format } from "date-fns";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Pagination,
  PaginationContent,
  PaginationItem,
  PaginationNext,
  PaginationPrevious,
} from "@/components/ui/pagination";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { Skeleton } from "@/components/ui/skeleton";
import { Plus, Pencil, Trash2, Loader2 } from "lucide-react";
import type { PromoCode } from "@/types/promo-code";

interface FormState {
  code: string;
  discount_type: string;
  discount_value: number;
  min_order: number;
  max_uses: number;
  valid_from: string;
  valid_until: string;
  is_active: boolean;
}

const emptyForm: FormState = {
  code: "",
  discount_type: "percent",
  discount_value: 0,
  min_order: 0,
  max_uses: 0,
  valid_from: "",
  valid_until: "",
  is_active: true,
};

export default function PromoCodesPage() {
  const [page, setPage] = useState(1);
  const { data, isLoading } = usePromoCodes({ page });

  const createPromo = useCreatePromoCode();
  const updatePromo = useUpdatePromoCode();
  const deletePromo = useDeletePromoCode();

  const [dialogOpen, setDialogOpen] = useState(false);
  const [editId, setEditId] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(emptyForm);

  const openCreate = () => {
    setEditId(null);
    setForm(emptyForm);
    setDialogOpen(true);
  };

  const openEdit = (promo: PromoCode) => {
    setEditId(promo.id);
    setForm({
      code: promo.code,
      discount_type: promo.discount_type,
      discount_value: promo.discount_value,
      min_order: promo.min_order,
      max_uses: promo.max_uses,
      valid_from: promo.valid_from.slice(0, 16),
      valid_until: promo.valid_until.slice(0, 16),
      is_active: promo.is_active,
    });
    setDialogOpen(true);
  };

  const handleSave = () => {
    if (!form.code.trim()) {
      toast.error("Введите код");
      return;
    }

    const payload = {
      ...form,
      valid_from: new Date(form.valid_from).toISOString(),
      valid_until: new Date(form.valid_until).toISOString(),
    };

    if (editId) {
      updatePromo.mutate(
        { id: editId, ...payload },
        {
          onSuccess: () => {
            toast.success("Промокод обновлен");
            setDialogOpen(false);
          },
          onError: () => toast.error("Ошибка обновления"),
        }
      );
    } else {
      createPromo.mutate(payload, {
        onSuccess: () => {
          toast.success("Промокод создан");
          setDialogOpen(false);
        },
        onError: () => toast.error("Ошибка создания"),
      });
    }
  };

  const handleDelete = (id: string, code: string) => {
    if (!confirm(`Удалить промокод "${code}"?`)) return;
    deletePromo.mutate(id, {
      onSuccess: () => toast.success("Промокод удален"),
      onError: () => toast.error("Ошибка удаления"),
    });
  };

  const isPending = createPromo.isPending || updatePromo.isPending;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold tracking-tight">Промокоды</h1>
        <Button onClick={openCreate}>
          <Plus data-icon="inline-start" />
          Добавить промокод
        </Button>
      </div>

      {isLoading ? (
        <div className="space-y-3">
          {Array.from({ length: 5 }).map((_, i) => (
            <Skeleton key={i} className="h-14 w-full" />
          ))}
        </div>
      ) : (
        <>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Код</TableHead>
                <TableHead>Тип</TableHead>
                <TableHead>Значение</TableHead>
                <TableHead>Мин. заказ</TableHead>
                <TableHead>Исп. / Макс.</TableHead>
                <TableHead>Действует</TableHead>
                <TableHead>Активен</TableHead>
                <TableHead className="w-[100px]">Действия</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {data?.items.map((promo) => (
                <TableRow key={promo.id}>
                  <TableCell className="font-mono font-medium">
                    {promo.code}
                  </TableCell>
                  <TableCell>
                    {promo.discount_type === "percent" ? "%" : "KGS"}
                  </TableCell>
                  <TableCell>
                    {promo.discount_type === "percent"
                      ? `${promo.discount_value}%`
                      : `${new Intl.NumberFormat("ru-RU").format(promo.discount_value)} KGS`}
                  </TableCell>
                  <TableCell>
                    {new Intl.NumberFormat("ru-RU").format(promo.min_order)} KGS
                  </TableCell>
                  <TableCell>
                    {promo.uses_count} / {promo.max_uses || "-"}
                  </TableCell>
                  <TableCell className="text-xs">
                    {format(new Date(promo.valid_from), "dd.MM.yy")} -{" "}
                    {format(new Date(promo.valid_until), "dd.MM.yy")}
                  </TableCell>
                  <TableCell>
                    <Badge
                      variant={promo.is_active ? "default" : "secondary"}
                    >
                      {promo.is_active ? "Да" : "Нет"}
                    </Badge>
                  </TableCell>
                  <TableCell>
                    <div className="flex items-center gap-1">
                      <Button
                        variant="ghost"
                        size="icon-sm"
                        onClick={() => openEdit(promo)}
                      >
                        <Pencil />
                      </Button>
                      <Button
                        variant="ghost"
                        size="icon-sm"
                        onClick={() => handleDelete(promo.id, promo.code)}
                        disabled={deletePromo.isPending}
                      >
                        <Trash2 className="text-destructive" />
                      </Button>
                    </div>
                  </TableCell>
                </TableRow>
              ))}
              {data?.items.length === 0 && (
                <TableRow>
                  <TableCell
                    colSpan={8}
                    className="text-center text-muted-foreground"
                  >
                    Промокоды не найдены
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>

          {data && data.pages > 1 && (
            <Pagination>
              <PaginationContent>
                <PaginationItem>
                  <PaginationPrevious
                    onClick={() => setPage((p) => Math.max(1, p - 1))}
                    aria-disabled={page <= 1}
                    className={
                      page <= 1 ? "pointer-events-none opacity-50" : ""
                    }
                  />
                </PaginationItem>
                <PaginationItem>
                  <span className="px-3 text-sm text-muted-foreground">
                    {page} / {data.pages}
                  </span>
                </PaginationItem>
                <PaginationItem>
                  <PaginationNext
                    onClick={() =>
                      setPage((p) => Math.min(data.pages, p + 1))
                    }
                    aria-disabled={page >= data.pages}
                    className={
                      page >= data.pages
                        ? "pointer-events-none opacity-50"
                        : ""
                    }
                  />
                </PaginationItem>
              </PaginationContent>
            </Pagination>
          )}
        </>
      )}

      {/* Create / Edit dialog */}
      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>
              {editId ? "Редактировать промокод" : "Новый промокод"}
            </DialogTitle>
          </DialogHeader>
          <div className="grid gap-4">
            <div className="grid gap-1.5">
              <Label htmlFor="promo_code">Код</Label>
              <Input
                id="promo_code"
                value={form.code}
                onChange={(e) =>
                  setForm((f) => ({ ...f, code: e.target.value.toUpperCase() }))
                }
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div className="grid gap-1.5">
                <Label>Тип скидки</Label>
                <Select
                  value={form.discount_type}
                  onValueChange={(val) =>
                    setForm((f) => ({ ...f, discount_type: val }))
                  }
                >
                  <SelectTrigger className="w-full">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="percent">Процент (%)</SelectItem>
                    <SelectItem value="fixed">Фикс. (KGS)</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="grid gap-1.5">
                <Label htmlFor="discount_value">Значение</Label>
                <Input
                  id="discount_value"
                  type="number"
                  value={form.discount_value}
                  onChange={(e) =>
                    setForm((f) => ({
                      ...f,
                      discount_value: Number(e.target.value),
                    }))
                  }
                />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div className="grid gap-1.5">
                <Label htmlFor="min_order">Мин. заказ (KGS)</Label>
                <Input
                  id="min_order"
                  type="number"
                  value={form.min_order}
                  onChange={(e) =>
                    setForm((f) => ({
                      ...f,
                      min_order: Number(e.target.value),
                    }))
                  }
                />
              </div>
              <div className="grid gap-1.5">
                <Label htmlFor="max_uses">Макс. использований</Label>
                <Input
                  id="max_uses"
                  type="number"
                  value={form.max_uses}
                  onChange={(e) =>
                    setForm((f) => ({
                      ...f,
                      max_uses: Number(e.target.value),
                    }))
                  }
                />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div className="grid gap-1.5">
                <Label htmlFor="valid_from">Действует с</Label>
                <Input
                  id="valid_from"
                  type="datetime-local"
                  value={form.valid_from}
                  onChange={(e) =>
                    setForm((f) => ({ ...f, valid_from: e.target.value }))
                  }
                />
              </div>
              <div className="grid gap-1.5">
                <Label htmlFor="valid_until">Действует до</Label>
                <Input
                  id="valid_until"
                  type="datetime-local"
                  value={form.valid_until}
                  onChange={(e) =>
                    setForm((f) => ({ ...f, valid_until: e.target.value }))
                  }
                />
              </div>
            </div>

            <div className="flex items-center gap-2">
              <Switch
                id="promo_active"
                checked={form.is_active}
                onCheckedChange={(checked: boolean) =>
                  setForm((f) => ({ ...f, is_active: checked }))
                }
              />
              <Label htmlFor="promo_active">Активен</Label>
            </div>
          </div>
          <DialogFooter>
            <Button onClick={handleSave} disabled={isPending}>
              {isPending && (
                <Loader2 className="mr-2 size-4 animate-spin" />
              )}
              {editId ? "Сохранить" : "Создать"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
