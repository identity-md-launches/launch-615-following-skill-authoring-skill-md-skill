#!/usr/bin/env node
// Checks that layerzero-oft/example/config/routes.json uses only v2-shaped endpoint ids
// (30000 and above, per REFERENCE.md), never the legacy v1 ids (101, 202, ...).
//
//   node layerzero-oft/example/check-routes.mjs

import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const routesPath = join(dirname(fileURLToPath(import.meta.url)), "config", "routes.json");
const { routes } = JSON.parse(readFileSync(routesPath, "utf8"));

const bad = [];
for (const route of routes) {
  for (const key of ["sourceEid", "dstEid"]) {
    const eid = route[key];
    if (typeof eid !== "number" || eid < 30000) bad.push(`${route.sourceChain} -> ${route.destinationChain}: ${key} ${eid}`);
  }
}

if (bad.length > 0) {
  console.error(`bad routes.json: v1-shaped or missing eid (want >= 30000):\n${bad.join("\n")}`);
  process.exit(1);
}
console.log(`ok  routes.json: ${routes.length} route(s), all eids >= 30000`);
