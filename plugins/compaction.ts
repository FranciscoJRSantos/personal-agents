import type { Plugin } from "@opencode-ai/plugin"
import * as fs from "fs"
import * as path from "path"

export const CompactionPlugin: Plugin = async ({ client, worktree }) => {
  return {
    "experimental.session.compacting": async (_input, output) => {
      const claudeFile = path.join(worktree, "CLAUDE.md")
      const artifactsDir = path.join(worktree, ".agents", "artifacts")

      // Extract TODOs from CLAUDE.md
      let todos: string[] = []
      if (fs.existsSync(claudeFile)) {
        const content = fs.readFileSync(claudeFile, "utf-8")
        todos = content
          .split("\n")
          .filter((line) => /^- \[[ x]\]/.test(line))
          .slice(0, 20)
      }

      // Find active implement session
      let activeImpl: string | null = null
      if (fs.existsSync(artifactsDir)) {
        const files = fs
          .readdirSync(artifactsDir)
          .filter((f) => f.endsWith("-impl-progress.md"))
          .map((f) => ({
            name: f,
            mtime: fs.statSync(path.join(artifactsDir, f)).mtimeMs,
          }))
          .sort((a, b) => b.mtime - a.mtime)

        if (files.length > 0) {
          activeImpl = files[0].name.replace(/-impl-progress\.md$/, "")
        }
      }

      await client.app.log({
        body: {
          service: "compaction-plugin",
          level: "info",
          message: "Preserving TODO state before compaction",
          extra: {
            todoCount: todos.length,
            activeImpl: activeImpl ?? "none",
          },
        },
      })

      // Inject preserved state into compaction context
      const lines: string[] = ["## Preserved TODOs from Previous Context"]
      lines.push(`- Active Implement: ${activeImpl ?? "none"}`)
      lines.push(`- TODO Count: ${todos.length}`)
      if (todos.length > 0) {
        lines.push("")
        lines.push("### TODOs")
        lines.push(...todos)
      }

      output.context.push(lines.join("\n"))
    },

    "session.compacted": async () => {
      await client.app.log({
        body: {
          service: "compaction-plugin",
          level: "debug",
          message: "Session compacted; TODO state preserved for next context",
        },
      })
    },
  }
}
