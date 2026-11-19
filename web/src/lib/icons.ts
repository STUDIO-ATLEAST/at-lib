import type { Component } from "svelte";
import Banknote from "@lucide/svelte/icons/banknote";
import Boxes from "@lucide/svelte/icons/boxes";
import Briefcase from "@lucide/svelte/icons/briefcase";
import CarFront from "@lucide/svelte/icons/car-front";
import ChevronsDown from "@lucide/svelte/icons/chevrons-down";
import Clock from "@lucide/svelte/icons/clock";
import Construction from "@lucide/svelte/icons/construction";
import Container from "@lucide/svelte/icons/container";
import Flag from "@lucide/svelte/icons/flag";
import Flame from "@lucide/svelte/icons/flame";
import FlaskConical from "@lucide/svelte/icons/flask-conical";
import Gauge from "@lucide/svelte/icons/gauge";
import Gem from "@lucide/svelte/icons/gem";
import HardHat from "@lucide/svelte/icons/hard-hat";
import Info from "@lucide/svelte/icons/info";
import Landmark from "@lucide/svelte/icons/landmark";
import Layers from "@lucide/svelte/icons/layers";
import Link from "@lucide/svelte/icons/link";
import ListChecks from "@lucide/svelte/icons/list-checks";
import Logs from "@lucide/svelte/icons/logs";
import MapPin from "@lucide/svelte/icons/map-pin";
import Package from "@lucide/svelte/icons/package";
import Shield from "@lucide/svelte/icons/shield";
import ShieldAlert from "@lucide/svelte/icons/shield-alert";
import Ship from "@lucide/svelte/icons/ship";
import Skull from "@lucide/svelte/icons/skull";
import Target from "@lucide/svelte/icons/target";
import Trash from "@lucide/svelte/icons/trash";
import Trash2 from "@lucide/svelte/icons/trash-2";
import Trees from "@lucide/svelte/icons/trees";
import Truck from "@lucide/svelte/icons/truck";
import Users from "@lucide/svelte/icons/users";
import Vault from "@lucide/svelte/icons/vault";
import Weight from "@lucide/svelte/icons/weight";
import Zap from "@lucide/svelte/icons/zap";

export type Icon = Component<{ size?: number; strokeWidth?: number }>;

const ICONS: Record<string, Icon> = {
  banknote: Banknote,
  boxes: Boxes,
  briefcase: Briefcase,
  "car-front": CarFront,
  "chevrons-down": ChevronsDown,
  clock: Clock,
  construction: Construction,
  container: Container,
  flag: Flag,
  flame: Flame,
  "flask-conical": FlaskConical,
  gauge: Gauge,
  gem: Gem,
  "hard-hat": HardHat,
  info: Info,
  landmark: Landmark,
  layers: Layers,
  link: Link,
  "list-checks": ListChecks,
  logs: Logs,
  "map-pin": MapPin,
  package: Package,
  shield: Shield,
  "shield-alert": ShieldAlert,
  ship: Ship,
  skull: Skull,
  target: Target,
  trash: Trash,
  "trash-2": Trash2,
  trees: Trees,
  truck: Truck,
  users: Users,
  vault: Vault,
  weight: Weight,
  zap: Zap,
};

export function icon(name: string | undefined, fallback: Icon = Info): Icon {
  return (name && ICONS[name]) || fallback;
}

export { Package, ListChecks, Users };
