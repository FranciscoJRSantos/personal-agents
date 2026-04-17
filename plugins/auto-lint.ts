import type { Plugin } from "@opencode-ai/plugin"
import * as fs from "fs"
import * as path from "path"

const LINTABLE_EXTENSIONS = new Set([".ts", ".js", ".tsx", ".jsx"])

async function detectLintCommand(
  worktree: string,
  filePath: string,
): Promise<string | null> {
  // 1. Check opencode.json for a "lint" key
  const opencodeJson = path.join(worktree, "opencode.json")
  if (fs.existsSync(opencodeJson)) {
    try {
      const config = JSON.parse(fs.readFileSync(opencodeJson, "utf-8"))
      if (typeof config.lint === "string") {
        return `${config.lint} -- ${filePath}`
      }
    } catch {
      // ignore parse errors
    }
  }

  // 2. Check package.json for a "lint" script
  const packageJson = path.join(worktree, "package.json")
  if (fs.existsSync(packageJson)) {
    try {
      const pkg = JSON.parse(fs.readFileSync(packageJson, "utf-8"))
      if (pkg.scripts?.lint) {
        return `npm run lint -- ${filePath}`
      }
    } catch {
      // ignore parse errors
    }
  }

  // 3. Check Makefile for a "lint:" target
  const makefile = path.join(worktree, "Makefile")
  if (fs.existsSync(makefile)) {
    const makeContent = fs.readFileSync(makefile, "utf-8")
    if (/^lint:/m.test(makeContent)) {
      return `make lint`
    }
  }

  return null
}

export const AutoLintPlugin: Plugin = async ({ client, worktree, $ }) => {
  return {
    "tool.execute.after": async (input, output) => {
      if (input.tool !== "write") return

      const filePath: string = (output as any).args?.filePath
      if (!filePath) return

      const ext = path.extname(filePath)
      if (!LINTABLE_EXTENSIONS.has(ext)) return

      const lintCmd = await detectLintCommand(worktree, filePath)

      if (!lintCmd) {
        await client.app.log({
          body: {
            service: "auto-lint-plugin",
            level: "debug",
            message: `No lint command found for ${filePath}`,
          },
        })
        return
      }

      await client.app.log({
        body: {
          service: "auto-lint-plugin",
          level: "info",
          message: `Running lint on ${filePath}`,
          extra: { command: lintCmd },
        },
      })

      let lintOutput = ""
      let lintFailed = false

      try {
        const result = await $`cd ${worktree} && ${lintCmd}`.text()
        lintOutput = result.split("\n").slice(0, 20).join("\n")
      } catch (err: any) {
        lintFailed = true
        lintOutput = (err?.stdout ?? err?.message ?? String(err))
          .split("\n")
          .slice(0, 20)
          .join("\n")
      }

      if (lintFailed) {
        await client.app.log({
          body: {
            service: "auto-lint-plugin",
            level: "warn",
            message: `Lint errors detected in ${filePath}`,
            extra: { output: lintOutput },
          },
        })

        // Prompt user to decide whether to continue or abort
        throw new Error(
          `Lint errors detected after writing ${filePath}:\n\n${lintOutput}\n\nFix the lint errors before proceeding, or override by running the write again with lint issues acknowledged.`,
        )
      } else {
        await client.app.log({
          body: {
            service: "auto-lint-plugin",
            level: "info",
            message: `Lint passed for ${filePath}`,
          },
        })
      }
    },
  }
}
