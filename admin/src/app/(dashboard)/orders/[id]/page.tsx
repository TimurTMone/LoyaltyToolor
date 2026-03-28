"use client";

import { useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import { useOrder, useUpdateOrderStatus } from "@/hooks/use-orders";
import { ORDER_STATUSES } from "@/lib/constants";
import { toast } from "sonner";
import { format } from "date-fns";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Skeleton } from "@/components/ui/skeleton";
import { Separator } from "@/components/ui/separator";
import { ArrowLeft, Loader2 } from "lucide-react";

function formatKGS(amount: number) {
  return new Intl.NumberFormat("ru-RU").format(amount) + " KGS";
}

function statusLabel(value: string) {
  return ORDER_STATUSES.find((s) => s.value === value)?.label ?? value;
}

export default function OrderDetailPage() {
  const params = useParams<{ id: string }>();
  const id = params.id;

  const { data: order, isLoading } = useOrder(id);
  const updateStatus = useUpdateOrderStatus();

  const [newStatus, setNewStatus] = useState("");
  const [adminNotes, setAdminNotes] = useState("");

  const handleStatusUpdate = () => {
    if (!newStatus) return;
    updateStatus.mutate(
      { id, status: newStatus, admin_notes: adminNotes || undefined },
      {
        onSuccess: () => {
          toast.success("Статус обновлен");
          setAdminNotes("");
        },
        onError: () => toast.error("Ошибка обновления статуса"),
      }
    );
  };

  if (isLoading) {
    return (
      <div className="space-y-6">
        <Skeleton className="h-8 w-64" />
        <div className="grid gap-6 lg:grid-cols-3">
          <Skeleton className="h-96 lg:col-span-2" />
          <Skeleton className="h-96" />
        </div>
      </div>
    );
  }

  if (!order) {
    return (
      <div className="space-y-4">
        <h1 className="text-2xl font-semibold">Заказ не найден</h1>
        <Button variant="outline" asChild>
          <Link href="/orders">Назад к заказам</Link>
        </Button>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="icon" asChild>
          <Link href="/orders">
            <ArrowLeft />
          </Link>
        </Button>
        <h1 className="text-2xl font-semibold tracking-tight">
          Заказ {order.order_number}
        </h1>
        <Badge variant="secondary">{statusLabel(order.status)}</Badge>
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        {/* Left column - order info */}
        <div className="space-y-6 lg:col-span-2">
          <Card>
            <CardHeader>
              <CardTitle>Детали заказа</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="grid grid-cols-2 gap-2 text-sm">
                <span className="text-muted-foreground">Тип доставки</span>
                <span>{order.delivery_type}</span>

                <span className="text-muted-foreground">Адрес</span>
                <span>{order.delivery_address ?? "-"}</span>

                <span className="text-muted-foreground">Оплата</span>
                <span>{order.payment_method}</span>

                <span className="text-muted-foreground">Примерка дома</span>
                <span>{order.try_at_home ? "Да" : "Нет"}</span>

                <span className="text-muted-foreground">Дата создания</span>
                <span>
                  {format(new Date(order.created_at), "dd.MM.yyyy HH:mm")}
                </span>
              </div>

              <Separator />

              <div className="grid grid-cols-2 gap-2 text-sm">
                <span className="text-muted-foreground">Подитог</span>
                <span>{formatKGS(order.subtotal)}</span>

                <span className="text-muted-foreground">Скидка</span>
                <span>-{formatKGS(order.discount_amount)}</span>

                <span className="text-muted-foreground">Баллы списано</span>
                <span>
                  -{formatKGS(order.points_discount)} ({order.points_used} б.)
                </span>

                <span className="font-medium">Итого</span>
                <span className="font-medium">{formatKGS(order.total)}</span>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Товары</CardTitle>
            </CardHeader>
            <CardContent>
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Товар</TableHead>
                    <TableHead>Размер</TableHead>
                    <TableHead>Цвет</TableHead>
                    <TableHead className="text-right">Кол-во</TableHead>
                    <TableHead className="text-right">Цена</TableHead>
                    <TableHead className="text-right">Сумма</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {order.items.map((item) => (
                    <TableRow key={item.id}>
                      <TableCell className="font-medium">
                        {item.product_name}
                      </TableCell>
                      <TableCell>{item.selected_size ?? "-"}</TableCell>
                      <TableCell>{item.selected_color ?? "-"}</TableCell>
                      <TableCell className="text-right">
                        {item.quantity}
                      </TableCell>
                      <TableCell className="text-right">
                        {formatKGS(item.product_price)}
                      </TableCell>
                      <TableCell className="text-right">
                        {formatKGS(item.line_total)}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </CardContent>
          </Card>
        </div>

        {/* Right column - customer + status update */}
        <div className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>Покупатель</CardTitle>
            </CardHeader>
            <CardContent className="space-y-2 text-sm">
              <div className="grid grid-cols-2 gap-2">
                <span className="text-muted-foreground">Имя</span>
                <span>{order.user?.full_name ?? "-"}</span>

                <span className="text-muted-foreground">Телефон</span>
                <span>{order.user?.phone ?? "-"}</span>

                <span className="text-muted-foreground">Email</span>
                <span>{order.user?.email ?? "-"}</span>
              </div>
              {order.delivery_notes && (
                <>
                  <Separator />
                  <div>
                    <span className="text-muted-foreground">Примечание:</span>
                    <p className="mt-1">{order.delivery_notes}</p>
                  </div>
                </>
              )}
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Обновить статус</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid gap-1.5">
                <Label>Новый статус</Label>
                <Select
                  value={newStatus}
                  onValueChange={setNewStatus}
                >
                  <SelectTrigger className="w-full">
                    <SelectValue placeholder="Выберите статус" />
                  </SelectTrigger>
                  <SelectContent>
                    {ORDER_STATUSES.map((s) => (
                      <SelectItem key={s.value} value={s.value}>
                        {s.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <div className="grid gap-1.5">
                <Label htmlFor="admin_notes">Заметка администратора</Label>
                <Textarea
                  id="admin_notes"
                  rows={3}
                  value={adminNotes}
                  onChange={(e) => setAdminNotes(e.target.value)}
                  placeholder="Необязательно..."
                />
              </div>

              <Button
                onClick={handleStatusUpdate}
                disabled={!newStatus || updateStatus.isPending}
                className="w-full"
              >
                {updateStatus.isPending && (
                  <Loader2 className="mr-2 size-4 animate-spin" />
                )}
                Обновить статус
              </Button>

              {order.admin_notes && (
                <div className="rounded-md bg-muted p-3 text-sm">
                  <span className="font-medium">Предыдущая заметка:</span>
                  <p className="mt-1 text-muted-foreground">
                    {order.admin_notes}
                  </p>
                </div>
              )}
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}
