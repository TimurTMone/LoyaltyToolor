"use client";

import { useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import { useUserDetail, useAdjustLoyalty } from "@/hooks/use-users";
import { LOYALTY_TIERS } from "@/lib/constants";
import { toast } from "sonner";
import { format } from "date-fns";
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
  DialogTrigger,
  DialogFooter,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";
import { Skeleton } from "@/components/ui/skeleton";
import { ArrowLeft, Loader2, QrCode, Star, Coins } from "lucide-react";

function formatKGS(amount: number) {
  return new Intl.NumberFormat("ru-RU").format(amount) + " KGS";
}

function tierLabel(tier: string) {
  const entry = LOYALTY_TIERS.find((t) => t.name === tier);
  if (!entry) return tier;
  return `${tier.charAt(0).toUpperCase() + tier.slice(1)} (${entry.cashback}%)`;
}

export default function UserDetailPage() {
  const params = useParams<{ id: string }>();
  const id = params.id;

  const { data, isLoading } = useUserDetail(id);
  const adjustLoyalty = useAdjustLoyalty();

  const [dialogOpen, setDialogOpen] = useState(false);
  const [pointsChange, setPointsChange] = useState<number>(0);
  const [description, setDescription] = useState("");

  const handleAdjust = () => {
    if (!pointsChange || !description.trim()) {
      toast.error("Заполните все поля");
      return;
    }
    adjustLoyalty.mutate(
      { user_id: id, points_change: pointsChange, description },
      {
        onSuccess: () => {
          toast.success("Баллы скорректированы");
          setPointsChange(0);
          setDescription("");
          setDialogOpen(false);
        },
        onError: () => toast.error("Ошибка корректировки баллов"),
      }
    );
  };

  if (isLoading) {
    return (
      <div className="space-y-6">
        <Skeleton className="h-8 w-48" />
        <div className="grid gap-6 md:grid-cols-2">
          <Skeleton className="h-64" />
          <Skeleton className="h-64" />
        </div>
      </div>
    );
  }

  if (!data) {
    return (
      <div className="space-y-4">
        <h1 className="text-2xl font-semibold">Пользователь не найден</h1>
        <Button variant="outline" asChild>
          <Link href="/users">Назад</Link>
        </Button>
      </div>
    );
  }

  const { user, loyalty } = data;

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="icon" asChild>
          <Link href="/users">
            <ArrowLeft />
          </Link>
        </Button>
        <h1 className="text-2xl font-semibold tracking-tight">
          {user.full_name || user.phone}
        </h1>
        {user.is_admin && <Badge variant="default">Админ</Badge>}
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        {/* User info */}
        <Card>
          <CardHeader>
            <CardTitle>Информация</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3 text-sm">
            <div className="grid grid-cols-2 gap-2">
              <span className="text-muted-foreground">Имя</span>
              <span>{user.full_name || "-"}</span>

              <span className="text-muted-foreground">Телефон</span>
              <span>{user.phone}</span>

              <span className="text-muted-foreground">Email</span>
              <span>{user.email || "-"}</span>

              <span className="text-muted-foreground">Дата рождения</span>
              <span>
                {user.birth_date
                  ? format(new Date(user.birth_date), "dd.MM.yyyy")
                  : "-"}
              </span>

              <span className="text-muted-foreground">Язык</span>
              <span>{user.language}</span>

              <span className="text-muted-foreground">Реферальный код</span>
              <span className="font-mono text-xs">{user.referral_code}</span>

              <span className="text-muted-foreground">Приглашен</span>
              <span>{user.referred_by ?? "-"}</span>

              <span className="text-muted-foreground">Регистрация</span>
              <span>
                {format(new Date(user.created_at), "dd.MM.yyyy HH:mm")}
              </span>
            </div>
          </CardContent>
        </Card>

        {/* Loyalty info */}
        <Card>
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle>Лояльность</CardTitle>
            <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
              <DialogTrigger asChild>
                <Button variant="outline" size="sm">
                  <Coins className="size-3.5 mr-1" />
                  Корректировать баллы
                </Button>
              </DialogTrigger>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle>Корректировка баллов</DialogTitle>
                </DialogHeader>
                <div className="grid gap-4">
                  <div className="grid gap-1.5">
                    <Label htmlFor="points_change">Баллы (+/-)</Label>
                    <Input
                      id="points_change"
                      type="number"
                      value={pointsChange}
                      onChange={(e) =>
                        setPointsChange(Number(e.target.value))
                      }
                      placeholder="100 или -50"
                    />
                  </div>
                  <div className="grid gap-1.5">
                    <Label htmlFor="adj_desc">Описание</Label>
                    <Textarea
                      id="adj_desc"
                      rows={2}
                      value={description}
                      onChange={(e) => setDescription(e.target.value)}
                      placeholder="Причина корректировки..."
                    />
                  </div>
                </div>
                <DialogFooter>
                  <Button
                    onClick={handleAdjust}
                    disabled={adjustLoyalty.isPending}
                  >
                    {adjustLoyalty.isPending && (
                      <Loader2 className="mr-2 size-4 animate-spin" />
                    )}
                    Применить
                  </Button>
                </DialogFooter>
              </DialogContent>
            </Dialog>
          </CardHeader>
          <CardContent className="space-y-3 text-sm">
            {loyalty ? (
              <>
                <div className="grid grid-cols-2 gap-2">
                  <span className="text-muted-foreground">
                    <Star className="mr-1 inline size-3.5" />
                    Уровень
                  </span>
                  <span className="font-medium">{tierLabel(loyalty.tier)}</span>

                  <span className="text-muted-foreground">
                    <Coins className="mr-1 inline size-3.5" />
                    Баллы
                  </span>
                  <span className="font-medium">{loyalty.points}</span>

                  <span className="text-muted-foreground">Всего потрачено</span>
                  <span>{formatKGS(loyalty.total_spent)}</span>
                </div>

                <Separator />

                <div className="grid grid-cols-2 gap-2">
                  <span className="text-muted-foreground">
                    <QrCode className="mr-1 inline size-3.5" />
                    QR-код
                  </span>
                  <span className="break-all font-mono text-xs">
                    {loyalty.qr_code}
                  </span>
                </div>
              </>
            ) : (
              <p className="text-muted-foreground">
                Нет данных о лояльности
              </p>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
