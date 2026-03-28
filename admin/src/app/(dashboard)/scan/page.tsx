"use client";

import { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Loader2, ScanLine, CheckCircle2, XCircle, Star, Coins, ShoppingBag } from "lucide-react";
import api from "@/lib/api-client";
import { toast } from "sonner";

const TIER_COLORS: Record<string, string> = {
  bronze: "bg-orange-100 text-orange-800",
  silver: "bg-gray-100 text-gray-700",
  gold: "bg-yellow-100 text-yellow-800",
  platinum: "bg-purple-100 text-purple-800",
};

const TIER_LABELS: Record<string, string> = {
  bronze: "Бронза",
  silver: "Серебро",
  gold: "Золото",
  platinum: "Платина",
};

interface ScanResult {
  valid: boolean;
  reason?: string;
  customer?: {
    name: string;
    phone: string;
    tier: string;
    points: number;
    total_spent: number;
    cashback_percent: number;
  };
}

export default function ScanPage() {
  const [qrToken, setQrToken] = useState("");
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<ScanResult | null>(null);

  const handleScan = async () => {
    const token = qrToken.trim();
    if (!token) {
      toast.error("Введите или отсканируйте QR код");
      return;
    }

    setLoading(true);
    setResult(null);
    try {
      const { data } = await api.post("/api/v1/loyalty/scan", { qr_token: token });
      setResult(data);
      if (data.valid) {
        toast.success(`Клиент найден: ${data.customer.name}`);
      } else {
        const reasons: Record<string, string> = {
          expired: "QR код истёк. Попросите клиента обновить.",
          invalid_signature: "QR код поддельный.",
          invalid_format: "Неверный формат QR кода.",
          user_not_found: "Пользователь не найден.",
        };
        toast.error(reasons[data.reason] || "Неизвестная ошибка");
      }
    } catch {
      toast.error("Ошибка проверки QR кода");
    } finally {
      setLoading(false);
    }
  };

  const handleClear = () => {
    setQrToken("");
    setResult(null);
  };

  return (
    <div className="space-y-6 max-w-lg mx-auto">
      <h1 className="text-2xl font-semibold">Сканировать QR</h1>
      <p className="text-muted-foreground">
        Введите QR код клиента для проверки лояльности
      </p>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <ScanLine className="size-5" />
            QR код клиента
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <Input
            placeholder="Вставьте QR токен..."
            value={qrToken}
            onChange={(e) => setQrToken(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && handleScan()}
          />
          <div className="flex gap-2">
            <Button onClick={handleScan} disabled={loading} className="flex-1">
              {loading ? (
                <Loader2 className="size-4 animate-spin mr-2" />
              ) : (
                <ScanLine className="size-4 mr-2" />
              )}
              Проверить
            </Button>
            <Button variant="outline" onClick={handleClear}>
              Очистить
            </Button>
          </div>
        </CardContent>
      </Card>

      {result && (
        <Card
          className={
            result.valid
              ? "border-green-200 bg-green-50 dark:border-green-900 dark:bg-green-950"
              : "border-red-200 bg-red-50 dark:border-red-900 dark:bg-red-950"
          }
        >
          <CardContent className="pt-6">
            {result.valid && result.customer ? (
              <div className="space-y-4">
                <div className="flex items-center gap-3">
                  <CheckCircle2 className="size-8 text-green-600" />
                  <div>
                    <p className="font-semibold text-lg">{result.customer.name}</p>
                    <p className="text-muted-foreground">{result.customer.phone}</p>
                  </div>
                  <Badge
                    className={`ml-auto ${TIER_COLORS[result.customer.tier] || ""}`}
                  >
                    {TIER_LABELS[result.customer.tier] || result.customer.tier}
                  </Badge>
                </div>

                <div className="grid grid-cols-3 gap-3">
                  <div className="text-center p-3 rounded-lg bg-background">
                    <Coins className="size-4 mx-auto mb-1 text-muted-foreground" />
                    <p className="text-xl font-bold">{result.customer.points}</p>
                    <p className="text-xs text-muted-foreground">Баллы</p>
                  </div>
                  <div className="text-center p-3 rounded-lg bg-background">
                    <ShoppingBag className="size-4 mx-auto mb-1 text-muted-foreground" />
                    <p className="text-xl font-bold">
                      {Math.round(result.customer.total_spent).toLocaleString()}
                    </p>
                    <p className="text-xs text-muted-foreground">Потрачено KGS</p>
                  </div>
                  <div className="text-center p-3 rounded-lg bg-background">
                    <Star className="size-4 mx-auto mb-1 text-muted-foreground" />
                    <p className="text-xl font-bold">
                      {result.customer.cashback_percent}%
                    </p>
                    <p className="text-xs text-muted-foreground">Кешбэк</p>
                  </div>
                </div>
              </div>
            ) : (
              <div className="flex items-center gap-3">
                <XCircle className="size-8 text-red-600" />
                <div>
                  <p className="font-semibold">QR код недействителен</p>
                  <p className="text-sm text-muted-foreground">
                    {result.reason === "expired" && "Код истёк. Попросите обновить."}
                    {result.reason === "invalid_signature" && "Код поддельный."}
                    {result.reason === "invalid_format" && "Неверный формат."}
                    {result.reason === "user_not_found" && "Пользователь не найден."}
                  </p>
                </div>
              </div>
            )}
          </CardContent>
        </Card>
      )}
    </div>
  );
}
