#!/usr/bin/env python3
"""Replace undici fetch with http.get in EPGUpdateManageModel.js (--jitless has no WASM)."""
import sys
from pathlib import Path

p = Path(sys.argv[1])
t = p.read_text()
old = (
    "            const response = await fetch(new URL(`/api/services/${serviceId}/programs`, this.mirakurunPath));\n"
    "            const servicePrograms = await response.json();"
)
new = (
    "            const servicePrograms = await mayflowerHttpJson("
    "new URL(`/api/services/${serviceId}/programs`, this.mirakurunPath));"
)
if "function mayflowerHttpJson" not in t:
    helper = r"""
const http = require("http");
const https = require("https");
function mayflowerHttpJson(url) {
    return new Promise((resolve, reject) => {
        const u = typeof url === "string" ? new URL(url) : url;
        const lib = u.protocol === "https:" ? https : http;
        const req = lib.get(u, (res) => {
            const chunks = [];
            res.on("data", (c) => chunks.push(c));
            res.on("end", () => {
                const body = Buffer.concat(chunks).toString("utf8");
                if ((res.statusCode || 0) < 200 || (res.statusCode || 0) >= 300) {
                    reject(new Error("HTTP " + res.statusCode));
                    return;
                }
                try { resolve(JSON.parse(body)); }
                catch (e) { reject(e); }
            });
        });
        req.on("error", reject);
    });
}
"""
    needle = 'Object.defineProperty(exports, "__esModule", { value: true });'
    if needle not in t:
        raise SystemExit("esm needle missing")
    t = t.replace(needle, needle + helper, 1)
if old not in t:
    if "mayflowerHttpJson" in t and "await fetch(" not in t:
        print("already patched fetch")
        sys.exit(0)
    raise SystemExit("fetch block missing")
p.write_text(t.replace(old, new, 1))
print("patched fetch", p)
