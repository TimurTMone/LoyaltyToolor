"use client";

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/api-client";
import type { Order, OrderStatusUpdate } from "@/types/order";
import type { PaginatedResponse } from "@/types/common";

interface OrdersParams {
  status?: string;
  page?: number;
  per_page?: number;
}

export function useOrders(params: OrdersParams = {}) {
  return useQuery({
    queryKey: ["orders", params],
    queryFn: async () => {
      const { data } = await api.get<PaginatedResponse<Order>>(
        "/api/v1/admin/orders",
        { params },
      );
      return data;
    },
  });
}

export function useOrder(id: string) {
  return useQuery({
    queryKey: ["orders", id],
    queryFn: async () => {
      const { data } = await api.get<Order>(`/api/v1/admin/orders/${id}`);
      return data;
    },
    enabled: !!id,
  });
}

export function useUpdateOrderStatus() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({
      id,
      ...update
    }: OrderStatusUpdate & { id: string }) => {
      const { data } = await api.patch<Order>(
        `/api/v1/admin/orders/${id}/status`,
        update,
      );
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["orders"] });
    },
  });
}
