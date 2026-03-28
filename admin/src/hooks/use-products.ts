"use client";

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/api-client";
import type { Product, ProductCreate, ProductUpdate } from "@/types/product";
import type { PaginatedResponse } from "@/types/common";

interface ProductsParams {
  search?: string;
  category_id?: string;
  is_active?: boolean;
  page?: number;
  per_page?: number;
}

export function useProducts(params: ProductsParams = {}) {
  return useQuery({
    queryKey: ["products", params],
    queryFn: async () => {
      const { data } = await api.get<PaginatedResponse<Product>>(
        "/api/v1/admin/products",
        { params },
      );
      return data;
    },
  });
}

export function useCreateProduct() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (product: ProductCreate) => {
      const { data } = await api.post<Product>(
        "/api/v1/admin/products",
        product,
      );
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["products"] });
    },
  });
}

export function useUpdateProduct() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ id, ...update }: ProductUpdate & { id: string }) => {
      const { data } = await api.patch<Product>(
        `/api/v1/admin/products/${id}`,
        update,
      );
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["products"] });
    },
  });
}

export function useDeleteProduct() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (id: string) => {
      await api.delete(`/api/v1/admin/products/${id}`);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["products"] });
    },
  });
}
