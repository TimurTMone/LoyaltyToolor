export interface LoyaltyAccount {
  id: string;
  user_id: string;
  qr_code: string;
  tier: string;
  points: number;
  total_spent: number;
  created_at: string;
  updated_at: string;
}

export interface LoyaltyTransaction {
  id: string;
  loyalty_id: string;
  user_id: string;
  order_id: string | null;
  type: string;
  amount: number;
  points_change: number;
  description: string;
  created_at: string;
}

export interface AdminLoyaltyAdjust {
  user_id: string;
  points_change: number;
  description: string;
}
