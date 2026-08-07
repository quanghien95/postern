// Without this the /health-reported version is a hand-maintained copy that can
// drift silently; with it, a drifted copy cannot pass CI. Same pattern as
// mcp/test/version.test.ts (mcp/#573).
import { describe, expect, it } from "vitest";
import { VERSION } from "./src/version";
import pkg from "./package.json";

describe("version", () => {
  it("/health-reported version matches package.json (no drift)", () => {
    expect(VERSION).toBe(pkg.version);
  });
});
