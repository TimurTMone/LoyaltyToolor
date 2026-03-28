export interface User {
  id: string;
  phone: string;
  full_name: string | null;
  email: string | null;
  avatar_url: string | null;
  birth_date: string | null;
  language: string;
  is_admin: boolean;
  referral_code: string;
  referred_by: string | null;
  fcm_token: string | null;
  created_at: string;
  updated_at: string;
}

export interface AdminUserUpdate {
  full_name?: string;
  email?: string;
  is_admin?: boolean;
  birth_date?: string;
  language?: string;
}
