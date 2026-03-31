import { User } from "./user";

export interface OrderItem {
  id: string;
  order_id: string;
  product_id: string;
  product_name: string;
  product_price: number;
  selected_size: string | null;
  selected_color: string | null;
  quantity: number;
  line_total: number;
}

export interface Order {
  id: string;
  user_id: string;
  order_number: string;
  status: string;
  subtotal: number;
  discount_amount: number;
  points_used: number;
  points_discount: number;
  total: number;
  currency: string;
  payment_method: string;
  delivery_address: string | null;
  delivery_type: string;
  delivery_notes: string | null;
  try_at_home: boolean;
  admin_notes: string | null;
  confirmed_by: string | null;
  confirmed_at: string | null;
  shipped_at: string | null;
  delivered_at: string | null;
  created_at: string;
  updated_at: string;
  items: OrderItem[];
  user: User | null;
}

export type AdminOrderOut = Order;

export interface OrderStatusUpdate {
  status: string;
  admin_notes?: string;
}
