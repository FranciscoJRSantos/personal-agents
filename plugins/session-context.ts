import type { Plugin } from "@opencode-ai/plugin"
import * as fs from "fs"
import * as path from "path"
import * as os from "os"

export const SessionContextPlugin: Plugin = async ({ client, worktree }) => {
  return {
    "session.created": async () => {
      const artifactsDir = path.join(worktree, ".agents", "artifacts")

      // Check for active implement session
      if (fs.existsSync(artifactsDir)) {
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
          await client.app.log({
            body: {
              service: "session-context-plugin",
              level: "info",
              message: `Found active implement session: ${ticket}`,
              extra: { ticket, artifactsDir },
            },
          })
        }
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
