import { Building2, MapPin, Server, Tags, Trash2, type LucideIcon } from "lucide-react";
import type { SettingsSectionId } from "./sections";

export const SECTION_ICONS: Record<SettingsSectionId, LucideIcon> = {
  organisation: Building2,
  "item-types": Tags,
  venues: MapPin,
  "recycle-bin": Trash2,
  system: Server,
};
