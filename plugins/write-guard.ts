import type { Plugin } from "@opencode-ai/plugin"
import * as fs from "fs"
import * as path from "path"

// Patterns that are allowed to be overwritten by the Write tool.
// Mirrors the original write-existing-file-guard.sh allow-list.
const ALLOW_PATTERNS: Array<RegExp | string> = [
  "package.json",
  "tsconfig.json",
  /^.*\.config\.(js|ts)$/,
  ".env",
  ".env.local",
  /^\.env\..+$/,
  /^.*\.lock$/,
  "yarn.lock",
  "pnpm-lock.yaml",
  "package-lock.json",
]

function isAllowed(filePath: string): boolean {
  const basename = path.basename(filePath)
  for (const pattern of ALLOW_PATTERNS) {
    if (typeof pattern === "string") {
      if (basename === pattern || filePath === pattern) return true
    } else {
      if (pattern.test(basename) || pattern.test(filePath)) return true
    }
  }
  return false
}

export const WriteGuardPlugin: Plugin = async ({ client, worktree }) => {
  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool !== "write") return

      const filePath: string = (output as any).args?.filePath
      if (!filePath) return

      // Resolve absolute path relative to worktree
      const fullPath = path.isAbsolute(filePath)
        ? filePath
        : path.join(worktree, filePath)

      if (!fs.existsSync(fullPath)) return // New file — allow

      if (isAllowed(filePath)) {
        await client.app.log({
          body: {
            service: "write-guard-plugin",
            level: "debug",
            message: `Write to existing file allowed (allow-list match): ${filePath}`,
          },
        })
        return
      }

      await client.app.log({
        body: {
          service: "write-guard-plugin",
          level: "warn",
          message: `Blocked Write to existing file: ${filePath}`,
          extra: { fullPath },
        },
      })

      throw new Error(
        `Write blocked: "${filePath}" already exists. Use the Edit tool to modify existing files instead of overwriting them.`,
      )
    },
  }
}
