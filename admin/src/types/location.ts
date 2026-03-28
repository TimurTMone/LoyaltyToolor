export interface Location {
  id: string;
  name: string;
  address: string;
  type: string;
  hours: string;
  note: string | null;
  latitude: number;
  longitude: number;
  is_active: boolean;
  sort_order: number;
  created_at: string;
}

export interface LocationCreate {
  name: string;
  address: string;
  type: string;
  hours: string;
  note?: string;
  latitude: number;
  longitude: number;
  is_active?: boolean;
  sort_order?: number;
}

export interface LocationUpdate {
  name?: string;
  address?: string;
  type?: string;
  hours?: string;
  note?: string;
  latitude?: number;
  longitude?: number;
  is_active?: boolean;
  sort_order?: number;
}
