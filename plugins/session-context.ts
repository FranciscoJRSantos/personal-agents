import type { Plugin } from "@opencode-ai/plugin"
import * as fs from "fs"
import * as path from "path"
import * as os from "os"

export const SessionContextPlugin: Plugin = async ({ client, worktree }) => {
  return {
    "session.created": async () => {
      const artifactsDir = path.join(worktree, ".agents", "artifacts")

      if (!fs.existsSync(artifactsDir)) {
        await client.app.log({
          body: {
            service: "session-context-plugin",
            level: "debug",
            message: "No artifacts directory found",
            extra: { checked: artifactsDir },
          },
        })
        return
      }

      // Find the most recent Kanban board artifact
      const kanbanFiles = fs
        .readdirSync(artifactsDir)
        .filter((f) => f.endsWith("-kanban-board.md"))
        .map((f) => ({
          name: f,
          mtime: fs.statSync(path.join(artifactsDir, f)).mtimeMs,
        }))
        .sort((a, b) => b.mtime - a.mtime)

      if (kanbanFiles.length > 0) {
        const ticket = kanbanFiles[0].name.replace(/-kanban-board\.md$/, "")
        const content = fs.readFileSync(
          path.join(artifactsDir, kanbanFiles[0].name),
          "utf-8",
        )
        const preview = content.slice(0, 300).replace(/\n/g, " ")
        await client.app.log({
          body: {
            service: "session-context-plugin",
            level: "info",
            message: `Kanban board loaded for ${ticket}`,
            extra: { ticket, preview, source: kanbanFiles[0].name },
          },
        })
      }

      // Check for active implement session
      const progressFiles = fs
        .readdirSync(artifactsDir)
        .filter((f) => f.endsWith("-impl-progress.md"))
        .map((f) => ({
          name: f,
          mtime: fs.statSync(path.join(artifactsDir, f)).mtimeMs,
        }))
        .sort((a, b) => b.mtime - a.mtime)

      if (progressFiles.length > 0) {
        const ticket = progressFiles[0].name.replace(/-impl-progress\.md$/, "")
        const content = fs.readFileSync(
          path.join(artifactsDir, progressFiles[0].name),
          "utf-8",
        )
        const preview = content.slice(0, 300).replace(/\n/g, " ")
        await client.app.log({
          body: {
            service: "session-context-plugin",
            level: "info",
            message: `Active implement session: ${ticket}`,
            extra: {
              ticket,
              preview,
              artifactsDir,
              source: progressFiles[0].name,
            },
          },
        })
      }

      // Check for last-session memory
      const lastSessionFile = path.join(
        os.homedir(),
        ".agents",
        "memory",
        "last-session.md",
      )
      if (fs.existsSync(lastSessionFile)) {
        const content = fs.readFileSync(lastSessionFile, "utf-8")
        const preview = content.slice(0, 200).replace(/\n/g, " ")
        await client.app.log({
          body: {
            service: "session-context-plugin",
            level: "info",
            message: "Last session memory loaded",
            extra: { preview, path: lastSessionFile },
          },
        })
      } else {
        await client.app.log({
          body: {
            service: "session-context-plugin",
            level: "debug",
            message: "No last-session memory found",
            extra: { checked: lastSessionFile },
          },
        })
      }
    },
  }
}
