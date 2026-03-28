"use client";

import { useState } from "react";
import {
  useLocations,
  useCreateLocation,
  useUpdateLocation,
  useDeleteLocation,
} from "@/hooks/use-locations";
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
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { Skeleton } from "@/components/ui/skeleton";
import { Plus, Pencil, Trash2, Loader2 } from "lucide-react";
import type { Location } from "@/types/location";

interface FormState {
  name: string;
  address: string;
  type: string;
  hours: string;
  note: string;
  latitude: number;
  longitude: number;
  is_active: boolean;
  sort_order: number;
}

const emptyForm: FormState = {
  name: "",
  address: "",
  type: "",
  hours: "",
  note: "",
  latitude: 0,
  longitude: 0,
  is_active: true,
  sort_order: 0,
};

export default function LocationsPage() {
  const { data: locations, isLoading } = useLocations();
  const createLocation = useCreateLocation();
  const updateLocation = useUpdateLocation();
  const deleteLocation = useDeleteLocation();

  const [dialogOpen, setDialogOpen] = useState(false);
  const [editId, setEditId] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(emptyForm);

  const openCreate = () => {
    setEditId(null);
    setForm(emptyForm);
    setDialogOpen(true);
  };

  const openEdit = (loc: Location) => {
    setEditId(loc.id);
    setForm({
      name: loc.name,
      address: loc.address,
      type: loc.type,
      hours: loc.hours,
      note: loc.note ?? "",
      latitude: loc.latitude,
      longitude: loc.longitude,
      is_active: loc.is_active,
      sort_order: loc.sort_order,
    });
    setDialogOpen(true);
  };

  const handleSave = () => {
    if (!form.name.trim() || !form.address.trim()) {
      toast.error("Заполните название и адрес");
      return;
    }

    const payload = {
      ...form,
      note: form.note || undefined,
    };

    if (editId) {
      updateLocation.mutate(
        { id: editId, ...payload },
        {
          onSuccess: () => {
            toast.success("Точка обновлена");
            setDialogOpen(false);
          },
          onError: () => toast.error("Ошибка обновления"),
        }
      );
    } else {
      createLocation.mutate(payload, {
        onSuccess: () => {
          toast.success("Точка создана");
          setDialogOpen(false);
        },
        onError: () => toast.error("Ошибка создания"),
      });
    }
  };

  const handleDelete = (id: string, name: string) => {
    if (!confirm(`Удалить точку "${name}"?`)) return;
    deleteLocation.mutate(id, {
      onSuccess: () => toast.success("Точка удалена"),
      onError: () => toast.error("Ошибка удаления"),
    });
  };

  const isPending = createLocation.isPending || updateLocation.isPending;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold tracking-tight">Точки</h1>
        <Button onClick={openCreate}>
          <Plus data-icon="inline-start" />
          Добавить точку
        </Button>
      </div>

      {isLoading ? (
        <div className="space-y-3">
          {Array.from({ length: 4 }).map((_, i) => (
            <Skeleton key={i} className="h-14 w-full" />
          ))}
        </div>
      ) : (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Название</TableHead>
              <TableHead>Адрес</TableHead>
              <TableHead>Тип</TableHead>
              <TableHead>Часы работы</TableHead>
              <TableHead>Активна</TableHead>
              <TableHead>Порядок</TableHead>
              <TableHead className="w-[100px]">Действия</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {locations?.map((loc) => (
              <TableRow key={loc.id}>
                <TableCell className="font-medium">{loc.name}</TableCell>
                <TableCell>{loc.address}</TableCell>
                <TableCell>{loc.type}</TableCell>
                <TableCell>{loc.hours}</TableCell>
                <TableCell>
                  <Badge variant={loc.is_active ? "default" : "secondary"}>
                    {loc.is_active ? "Да" : "Нет"}
                  </Badge>
                </TableCell>
                <TableCell>{loc.sort_order}</TableCell>
                <TableCell>
                  <div className="flex items-center gap-1">
                    <Button
                      variant="ghost"
                      size="icon-sm"
                      onClick={() => openEdit(loc)}
                    >
                      <Pencil />
                    </Button>
                    <Button
                      variant="ghost"
                      size="icon-sm"
                      onClick={() => handleDelete(loc.id, loc.name)}
                      disabled={deleteLocation.isPending}
                    >
                      <Trash2 className="text-destructive" />
                    </Button>
                  </div>
                </TableCell>
              </TableRow>
            ))}
            {locations?.length === 0 && (
              <TableRow>
                <TableCell
                  colSpan={7}
                  className="text-center text-muted-foreground"
                >
                  Точки не найдены
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      )}

      {/* Create / Edit dialog */}
      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>
              {editId ? "Редактировать точку" : "Новая точка"}
            </DialogTitle>
          </DialogHeader>
          <div className="grid gap-4">
            <div className="grid gap-1.5">
              <Label htmlFor="loc_name">Название</Label>
              <Input
                id="loc_name"
                value={form.name}
                onChange={(e) =>
                  setForm((f) => ({ ...f, name: e.target.value }))
                }
              />
            </div>

            <div className="grid gap-1.5">
              <Label htmlFor="loc_address">Адрес</Label>
              <Input
                id="loc_address"
                value={form.address}
                onChange={(e) =>
                  setForm((f) => ({ ...f, address: e.target.value }))
                }
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div className="grid gap-1.5">
                <Label htmlFor="loc_type">Тип</Label>
                <Input
                  id="loc_type"
                  value={form.type}
                  onChange={(e) =>
                    setForm((f) => ({ ...f, type: e.target.value }))
                  }
                  placeholder="store / pickup"
                />
              </div>
              <div className="grid gap-1.5">
                <Label htmlFor="loc_hours">Часы работы</Label>
                <Input
                  id="loc_hours"
                  value={form.hours}
                  onChange={(e) =>
                    setForm((f) => ({ ...f, hours: e.target.value }))
                  }
                  placeholder="09:00-21:00"
                />
              </div>
            </div>

            <div className="grid gap-1.5">
              <Label htmlFor="loc_note">Примечание</Label>
              <Textarea
                id="loc_note"
                rows={2}
                value={form.note}
                onChange={(e) =>
                  setForm((f) => ({ ...f, note: e.target.value }))
                }
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div className="grid gap-1.5">
                <Label htmlFor="loc_lat">Широта</Label>
                <Input
                  id="loc_lat"
                  type="number"
                  step="any"
                  value={form.latitude}
                  onChange={(e) =>
                    setForm((f) => ({
                      ...f,
                      latitude: Number(e.target.value),
                    }))
                  }
                />
              </div>
              <div className="grid gap-1.5">
                <Label htmlFor="loc_lng">Долгота</Label>
                <Input
                  id="loc_lng"
                  type="number"
                  step="any"
                  value={form.longitude}
                  onChange={(e) =>
                    setForm((f) => ({
                      ...f,
                      longitude: Number(e.target.value),
                    }))
                  }
                />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div className="flex items-center gap-2">
                <Switch
                  id="loc_active"
                  checked={form.is_active}
                  onCheckedChange={(checked: boolean) =>
                    setForm((f) => ({ ...f, is_active: checked }))
                  }
                />
                <Label htmlFor="loc_active">Активна</Label>
              </div>
              <div className="grid gap-1.5">
                <Label htmlFor="loc_sort">Порядок</Label>
                <Input
                  id="loc_sort"
                  type="number"
                  value={form.sort_order}
                  onChange={(e) =>
                    setForm((f) => ({
                      ...f,
                      sort_order: Number(e.target.value),
                    }))
                  }
                />
              </div>
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
