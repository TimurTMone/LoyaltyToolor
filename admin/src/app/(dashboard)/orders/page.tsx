"use client";

import { useState } from "react";
import Link from "next/link";
import { useOrders } from "@/hooks/use-orders";
import { ORDER_STATUSES } from "@/lib/constants";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Tabs,
  TabsList,
  TabsTrigger,
  TabsContent,
} from "@/components/ui/tabs";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  Pagination,
  PaginationContent,
  PaginationItem,
  PaginationNext,
  PaginationPrevious,
} from "@/components/ui/pagination";
import { Button } from "@/components/ui/button";
import { Eye } from "lucide-react";
import { format } from "date-fns";

function formatKGS(amount: number) {
  return new Intl.NumberFormat("ru-RU").format(amount) + " KGS";
}

function statusLabel(value: string) {
  return ORDER_STATUSES.find((s) => s.value === value)?.label ?? value;
}

function statusVariant(value: string) {
  switch (value) {
    case "delivered":
      return "default" as const;
    case "cancelled":
      return "destructive" as const;
    case "shipped":
      return "secondary" as const;
    default:
      return "outline" as const;
  }
}

const TAB_ALL = "all";

export default function OrdersPage() {
  const [status, setStatus] = useState(TAB_ALL);
  const [page, setPage] = useState(1);

  const { data, isLoading } = useOrders({
    status: status === TAB_ALL ? undefined : status,
    page,
  });

  const handleTabChange = (val: string | number | null) => {
    setStatus(String(val ?? TAB_ALL));
    setPage(1);
  };

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-semibold tracking-tight">Заказы</h1>

      <Tabs value={status} onValueChange={handleTabChange}>
        <TabsList className="flex-wrap h-auto">
          <TabsTrigger value={TAB_ALL}>Все</TabsTrigger>
          {ORDER_STATUSES.map((s) => (
            <TabsTrigger key={s.value} value={s.value}>
              {s.label}
            </TabsTrigger>
          ))}
        </TabsList>

        <TabsContent value={status} className="mt-4">
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
                    <TableHead>Номер</TableHead>
                    <TableHead>Телефон</TableHead>
                    <TableHead>Статус</TableHead>
                    <TableHead>Сумма</TableHead>
                    <TableHead>Доставка</TableHead>
                    <TableHead>Дата</TableHead>
                    <TableHead className="w-[60px]">Действия</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {data?.items.map((order) => (
                    <TableRow key={order.id}>
                      <TableCell className="font-medium">
                        {order.order_number}
                      </TableCell>
                      <TableCell>{order.user?.phone ?? "-"}</TableCell>
                      <TableCell>
                        <Badge variant={statusVariant(order.status)}>
                          {statusLabel(order.status)}
                        </Badge>
                      </TableCell>
                      <TableCell>{formatKGS(order.total)}</TableCell>
                      <TableCell>{order.delivery_type}</TableCell>
                      <TableCell>
                        {format(new Date(order.created_at), "dd.MM.yyyy HH:mm")}
                      </TableCell>
                      <TableCell>
                        <Button
                          variant="ghost"
                          size="icon-sm"
                          asChild
                        >
                          <Link href={`/orders/${order.id}`}>
                            <Eye />
                          </Link>
                        </Button>
                      </TableCell>
                    </TableRow>
                  ))}
                  {data?.items.length === 0 && (
                    <TableRow>
                      <TableCell
                        colSpan={7}
                        className="text-center text-muted-foreground"
                      >
                        Заказы не найдены
                      </TableCell>
                    </TableRow>
                  )}
                </TableBody>
              </Table>

              {data && data.pages > 1 && (
                <Pagination className="mt-4">
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
        </TabsContent>
      </Tabs>
    </div>
  );
}
