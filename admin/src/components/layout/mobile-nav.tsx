"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  ScanLine,
  Package,
  ShoppingCart,
  Users,
  FolderTree,
  Ticket,
  MapPin,
  type LucideIcon,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { NAV_ITEMS } from "@/lib/constants";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";

const iconMap: Record<string, LucideIcon> = {
  LayoutDashboard,
  ScanLine,
  Package,
  ShoppingCart,
  Users,
  FolderTree,
  Ticket,
  MapPin,
};

interface MobileNavProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function MobileNav({ open, onOpenChange }: MobileNavProps) {
  const pathname = usePathname();

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="left" className="w-64 p-0">
        <SheetHeader className="border-b px-4">
          <SheetTitle className="text-lg font-semibold tracking-tight">
            TOOLOR Admin
          </SheetTitle>
        </SheetHeader>

        <nav className="flex-1 overflow-y-auto p-3 space-y-1">
          {NAV_ITEMS.map((item) => {
            const Icon = iconMap[item.icon];
            const isActive =
              item.href === "/"
                ? pathname === "/"
                : pathname.startsWith(item.href);

            return (
              <Link
                key={item.href}
                href={item.href}
                onClick={() => onOpenChange(false)}
                className={cn(
                  "flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors",
                  isActive
                    ? "bg-accent text-accent-foreground"
                    : "text-muted-foreground hover:bg-accent/50 hover:text-accent-foreground"
                )}
              >
                {Icon && <Icon className="size-4 shrink-0" />}
                {item.label}
              </Link>
            );
          })}
        </nav>
      </SheetContent>
    </Sheet>
  );
}
