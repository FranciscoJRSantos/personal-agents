import type { Plugin } from "@opencode-ai/plugin"
import * as fs from "fs"
import * as path from "path"

function loadPatterns(worktree: string): { exact: string[]; regex: RegExp[] } {
  const defaults = {
    exact: [
      "package.json",
      "tsconfig.json",
      ".env",
      ".env.local",
      "yarn.lock",
      "pnpm-lock.yaml",
      "package-lock.json",
    ],
    regex: [
      /^.*\.config\.(js|ts)$/,
      /^\.env\..+$/,
      /^.*\.lock$/,
    ],
  }

  const configPath = path.join(worktree, "plugins", "write-guard-patterns.json")
  if (!fs.existsSync(configPath)) return defaults

  try {
    const raw = JSON.parse(fs.readFileSync(configPath, "utf-8"))
    return {
      exact: raw.exact ?? defaults.exact,
      regex: (raw.regex ?? []).map((p: string) => new RegExp(p)),
    }
  } catch {
    return defaults
  }
}

function isAllowed(filePath: string, exact: string[], regex: RegExp[]): boolean {
  const basename = path.basename(filePath)
  if (exact.some((p) => basename === p || filePath === p)) return true
  if (regex.some((r) => r.test(basename) || r.test(filePath))) return true
  return false
}

export const WriteGuardPlugin: Plugin = async ({ client, worktree }) => {
  const patterns = loadPatterns(worktree)
  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool !== "write") return

      const filePath: string = (output as any).args?.filePath
      if (!filePath) return

      const fullPath = path.isAbsolute(filePath)
        ? filePath
        : path.join(worktree, filePath)

      if (!fs.existsSync(fullPath)) return // New file — allow

      if (isAllowed(filePath, patterns.exact, patterns.regex)) {
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
