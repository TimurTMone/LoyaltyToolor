export interface PromoCode {
  id: string;
  code: string;
  discount_type: string;
  discount_value: number;
  min_order: number;
  max_uses: number;
  uses_count: number;
  valid_from: string;
  valid_until: string;
  is_active: boolean;
  created_at: string;
}

export interface PromoCodeCreate {
  code: string;
  discount_type: string;
  discount_value: number;
  min_order?: number;
  max_uses?: number;
  valid_from: string;
  valid_until: string;
  is_active?: boolean;
}

export interface PromoCodeUpdate {
  code?: string;
  discount_type?: string;
  discount_value?: number;
  min_order?: number;
  max_uses?: number;
  valid_from?: string;
  valid_until?: string;
  is_active?: boolean;
}
