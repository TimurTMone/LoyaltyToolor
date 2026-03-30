"use client";

import { useState } from "react";
import { useLocations } from "@/hooks/use-locations";
import {
  useInventoryByLocation,
  useUpdateInventory,
  useAssignProduct,
  type InventoryRow,
} from "@/hooks/use-inventory";
import { useProducts } from "@/hooks/use-products";
import { toast } from "sonner";
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
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { Plus, Loader2, Search } from "lucide-react";

export default function InventoryPage() {
  const [selectedLocationId, setSelectedLocationId] = useState("");
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  const [editingRow, setEditingRow] = useState<InventoryRow | null>(null);
  const [editQty, setEditQty] = useState(0);
  const [showAssign, setShowAssign] = useState(false);
  const [assignProductId, setAssignProductId] = useState("");

  const { data: locations, isLoading: locsLoading } = useLocations();
  const { data: inventoryData, isLoading: invLoading } =
    useInventoryByLocation({
      location_id: selectedLocationId,
      search: search || undefined,
      page,
      per_page: 50,
    });

  const updateMutation = useUpdateInventory();
  const assignMutation = useAssignProduct();
  const { data: productsData } = useProducts({ per_page: 100 });

  const stores =
    locations?.filter(
      (l: { type: string; is_active: boolean }) =>
        l.type === "store" && l.is_active
    ) ?? [];

  // Auto-select first store
  if (!selectedLocationId && stores.length > 0) {
    setSelectedLocationId(stores[0].id);
  }

  function handleSaveQty() {
    if (!editingRow) return;
    updateMutation.mutate(
      { id: editingRow.id, quantity: editQty },
      {
        onSuccess: () => {
          toast.success("Количество обновлено");
          setEditingRow(null);
        },
        onError: () => toast.error("Ошибка при обновлении"),
      }
    );
  }

  function handleAssign() {
    if (!selectedLocationId || !assignProductId) return;
    assignMutation.mutate(
      { location_id: selectedLocationId, product_id: assignProductId },
      {
        onSuccess: (data: { created: number }) => {
          toast.success(`Товар добавлен (${data.created} размеров)`);
          setShowAssign(false);
          setAssignProductId("");
        },
        onError: () => toast.error("Ошибка при добавлении"),
      }
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Склад</h1>
        <Button onClick={() => setShowAssign(true)} disabled={!selectedLocationId}>
          <Plus className="size-4 mr-2" />
          Добавить товар
        </Button>
      </div>

      {/* Store selector + search */}
      <div className="flex gap-4">
        <div className="w-64">
          <Label className="mb-1.5 block text-sm">Магазин</Label>
          {locsLoading ? (
            <Skeleton className="h-10 w-full" />
          ) : (
            <Select value={selectedLocationId} onValueChange={(v) => { setSelectedLocationId(v); setPage(1); }}>
              <SelectTrigger>
                <SelectValue placeholder="Выберите магазин" />
              </SelectTrigger>
              <SelectContent>
                {stores.map((s: { id: string; name: string }) => (
                  <SelectItem key={s.id} value={s.id}>
                    {s.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          )}
        </div>
        <div className="flex-1">
          <Label className="mb-1.5 block text-sm">Поиск</Label>
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 size-4 text-muted-foreground" />
            <Input
              className="pl-9"
              placeholder="Поиск товара..."
              value={search}
              onChange={(e) => { setSearch(e.target.value); setPage(1); }}
            />
          </div>
        </div>
      </div>

      {/* Inventory table */}
      {!selectedLocationId ? (
        <p className="text-muted-foreground text-center py-12">
          Выберите магазин для просмотра склада
        </p>
      ) : invLoading ? (
        <div className="space-y-2">
          {Array.from({ length: 8 }).map((_, i) => (
            <Skeleton key={i} className="h-12 w-full" />
          ))}
        </div>
      ) : (
        <>
          <div className="rounded-md border">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="w-16">Фото</TableHead>
                  <TableHead>Товар</TableHead>
                  <TableHead className="w-24">Размер</TableHead>
                  <TableHead className="w-32">Количество</TableHead>
                  <TableHead className="w-24" />
                </TableRow>
              </TableHeader>
              <TableBody>
                {inventoryData?.items.length === 0 && (
                  <TableRow>
                    <TableCell colSpan={5} className="text-center py-8 text-muted-foreground">
                      Нет товаров в этом магазине
                    </TableCell>
                  </TableRow>
                )}
                {inventoryData?.items.map((row) => (
                  <TableRow key={row.id}>
                    <TableCell>
                      {row.product_image ? (
                        <img
                          src={row.product_image}
                          alt=""
                          className="w-10 h-10 object-cover rounded"
                        />
                      ) : (
                        <div className="w-10 h-10 bg-muted rounded" />
                      )}
                    </TableCell>
                    <TableCell className="font-medium">
                      {row.product_name}
                    </TableCell>
                    <TableCell>
                      {row.size ? (
                        <Badge variant="outline">{row.size}</Badge>
                      ) : (
                        <span className="text-muted-foreground">—</span>
                      )}
                    </TableCell>
                    <TableCell>
                      <Badge variant={row.quantity > 0 ? "default" : "destructive"}>
                        {row.quantity}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => {
                          setEditingRow(row);
                          setEditQty(row.quantity);
                        }}
                      >
                        Изменить
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>

          {/* Pagination */}
          {inventoryData && inventoryData.total > 50 && (
            <div className="flex items-center justify-between">
              <p className="text-sm text-muted-foreground">
                Всего: {inventoryData.total}
              </p>
              <div className="flex gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  disabled={page <= 1}
                  onClick={() => setPage(page - 1)}
                >
                  Назад
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  disabled={
                    page >= Math.ceil(inventoryData.total / 50)
                  }
                  onClick={() => setPage(page + 1)}
                >
                  Далее
                </Button>
              </div>
            </div>
          )}
        </>
      )}

      {/* Edit quantity dialog */}
      <Dialog open={!!editingRow} onOpenChange={() => setEditingRow(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Изменить количество</DialogTitle>
          </DialogHeader>
          {editingRow && (
            <div className="space-y-4 py-4">
              <p className="font-medium">{editingRow.product_name}</p>
              {editingRow.size && (
                <p className="text-sm text-muted-foreground">
                  Размер: {editingRow.size}
                </p>
              )}
              <div>
                <Label>Количество</Label>
                <Input
                  type="number"
                  min={0}
                  value={editQty}
                  onChange={(e) => setEditQty(parseInt(e.target.value) || 0)}
                />
              </div>
            </div>
          )}
          <DialogFooter>
            <Button variant="outline" onClick={() => setEditingRow(null)}>
              Отмена
            </Button>
            <Button onClick={handleSaveQty} disabled={updateMutation.isPending}>
              {updateMutation.isPending && (
                <Loader2 className="size-4 mr-2 animate-spin" />
              )}
              Сохранить
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Assign product dialog */}
      <Dialog open={showAssign} onOpenChange={setShowAssign}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Добавить товар в магазин</DialogTitle>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <p className="text-sm text-muted-foreground">
              Выберите товар. Будут созданы строки для всех его размеров с
              количеством 0. После добавления укажите количество.
            </p>
            <div>
              <Label>Товар</Label>
              <Select value={assignProductId} onValueChange={setAssignProductId}>
                <SelectTrigger>
                  <SelectValue placeholder="Выберите товар" />
                </SelectTrigger>
                <SelectContent className="max-h-60">
                  {productsData?.items?.map(
                    (p: { id: string; name: string }) => (
                      <SelectItem key={p.id} value={p.id}>
                        {p.name}
                      </SelectItem>
                    )
                  )}
                </SelectContent>
              </Select>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowAssign(false)}>
              Отмена
            </Button>
            <Button
              onClick={handleAssign}
              disabled={!assignProductId || assignMutation.isPending}
            >
              {assignMutation.isPending && (
                <Loader2 className="size-4 mr-2 animate-spin" />
              )}
              Добавить
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
