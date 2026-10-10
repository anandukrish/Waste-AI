# WASTE Project Quality Guidelines

## Finish the user's flow

- Define the visible result before changing code.
- Implement the smallest complete user flow, not only a button or placeholder.
- If a check or server is started, keep going until its result is verified or
  a specific blocker is recorded.
- If a command errors, inspect and retry a safe bounded fix; never hide a
  failed check with a no-op.

## Verification is required

Before calling a feature complete:

1. Run the applicable project tests, lint, typecheck or build checks.
2. Exercise the user-visible path when possible.
3. Verify generated files, server health or an independent structured result.
4. Report passed, failed, skipped and unavailable checks separately.

Never claim a check, server, build, generated artifact or deployment passed
unless it was actually run and observed.

## Safe local-first development

- Keep default development local and bind services to loopback.
- Never commit API keys, pairing tokens, passwords, cookies, private logs,
  model credentials or personal conversation data.
- Keep offline and online AI paths explicit; never silently upload offline data.
- Ask before installing tools, connecting external services, publishing data or
  deleting files.
- Require clear confirmation for destructive or consequential actions.
- Preserve unrelated animation files and existing user work.

## Server and handoff rules

- Verify a started server's URL or health endpoint in the same work session.
- Do not use public port forwarding as a shortcut.
- Keep README/setup commands aligned with the actual project.
- Record the next concrete step when work is partial.
- End with what changed, how to try it, checks run and real gaps.

## Good-session rule

Optimize for a reproducible user-visible result and honest evidence, not token
counts, streaks or cosmetic progress.
