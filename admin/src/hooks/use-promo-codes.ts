"use client";

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/api-client";
import type {
  PromoCode,
  PromoCodeCreate,
  PromoCodeUpdate,
} from "@/types/promo-code";
import type { PaginatedResponse } from "@/types/common";

interface PromoCodesParams {
  page?: number;
  per_page?: number;
}

export function usePromoCodes(params: PromoCodesParams = {}) {
  return useQuery({
    queryKey: ["promo-codes", params],
    queryFn: async () => {
      const { data } = await api.get<PaginatedResponse<PromoCode>>(
        "/api/v1/admin/promo-codes",
        { params },
      );
      return data;
    },
  });
}

export function useCreatePromoCode() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (promoCode: PromoCodeCreate) => {
      const { data } = await api.post<PromoCode>(
        "/api/v1/admin/promo-codes",
        promoCode,
      );
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["promo-codes"] });
    },
  });
}

export function useUpdatePromoCode() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({
      id,
      ...update
    }: PromoCodeUpdate & { id: string }) => {
      const { data } = await api.patch<PromoCode>(
        `/api/v1/admin/promo-codes/${id}`,
        update,
      );
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["promo-codes"] });
    },
  });
}

export function useDeletePromoCode() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (id: string) => {
      await api.delete(`/api/v1/admin/promo-codes/${id}`);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["promo-codes"] });
    },
  });
}
