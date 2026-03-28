"use client";

import { useQuery } from "@tanstack/react-query";
import api from "@/lib/api-client";
import type { DashboardData } from "@/types/dashboard";

export function useDashboard() {
  return useQuery({
    queryKey: ["dashboard"],
    queryFn: async () => {
      const { data } = await api.get<DashboardData>(
        "/api/v1/admin/dashboard",
      );
      return data;
    },
  });
}
