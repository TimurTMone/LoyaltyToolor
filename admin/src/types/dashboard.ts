import type { Order } from "./order";

export interface DashboardData {
  total_users: number;
  total_orders: number;
  total_revenue: number;
  pending_orders: number;
  recent_orders: Order[];
}
