"use client";

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/api-client";

export interface InventoryRow {
  id: string;
  location_id: string;
  product_id: string;
  product_name?: string;
  product_image?: string;
  size: string | null;
  quantity: number;
}

interface InventoryByLocationParams {
  location_id: string;
  search?: string;
  page?: number;
  per_page?: number;
}

export function useInventoryByLocation(params: InventoryByLocationParams) {
  return useQuery({
    queryKey: ["inventory", "by-location", params],
    queryFn: async () => {
      const { location_id, ...rest } = params;
      const { data } = await api.get<{
        items: InventoryRow[];
        total: number;
        page: number;
        per_page: number;
      }>(`/api/v1/admin/inventory/by-location/${location_id}`, { params: rest });
      return data;
    },
    enabled: !!params.location_id,
  });
}

export function useInventoryByProduct(productId: string) {
  return useQuery({
    queryKey: ["inventory", "by-product", productId],
    queryFn: async () => {
      const { data } = await api.get<InventoryRow[]>(
        `/api/v1/admin/inventory/by-product/${productId}`
      );
      return data;
    },
    enabled: !!productId,
  });
}

export function useUpdateInventory() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({
      id,
      quantity,
    }: {
      id: string;
      quantity: number;
    }) => {
      const { data } = await api.patch(`/api/v1/admin/inventory/${id}`, {
        quantity,
      });
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["inventory"] });
    },
  });
}

export function useBulkUpdateInventory() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (
      items: { location_id: string; product_id: string; size: string | null; quantity: number }[]
    ) => {
      const { data } = await api.put("/api/v1/admin/inventory", { items });
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["inventory"] });
    },
  });
}

export function useAssignProduct() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (body: { location_id: string; product_id: string }) => {
      const { data } = await api.post(
        "/api/v1/admin/inventory/assign-product",
        body
      );
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["inventory"] });
    },
  });
}
