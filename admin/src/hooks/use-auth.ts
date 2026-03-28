"use client";

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import api from "@/lib/api-client";
import { setTokens, clearTokens, decodeToken } from "@/lib/auth";
import type { LoginRequest, TokenResponse } from "@/types/auth";

export function useLogin() {
  const router = useRouter();

  return useMutation({
    mutationFn: async (credentials: LoginRequest) => {
      const { data } = await api.post<TokenResponse>(
        "/api/v1/auth/login",
        credentials,
      );
      return data;
    },
    onSuccess: (data) => {
      const payload = decodeToken(data.access_token);
      if (!payload?.is_admin) {
        throw new Error("Access denied: user is not an admin");
      }
      setTokens(data);
      router.push("/");
    },
  });
}

export function useLogout() {
  const router = useRouter();
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async () => {
      clearTokens();
    },
    onSuccess: () => {
      queryClient.invalidateQueries();
      router.push("/login");
    },
  });
}
