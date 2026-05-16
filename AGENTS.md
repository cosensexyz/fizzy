# Project

Fizzy is a desktop virtual pet that receives notifications from AI coding agents (Claude Code, Codex, etc.) and displays them as an interactive bubble companion on your screen.

## Commands

- `swift build` — build the project
- `swift test` — run all tests
- `swift run Fizzy` — launch the desktop pet

## Coding Guidelines

### Think Before Coding

Don't assume. Don't hide confusion. Surface tradeoffs.

- State assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.

### Simplicity First (KISS)

Minimum code that solves the problem. Nothing speculative.

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- No duplicated logic (DRY) — extract only when reuse is real, not hypothetical.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### Test Everything

Every change — feature, bugfix, refactor — must have a corresponding test.

- No code lands without a test that proves it works.
- Test suites should be minimal and complete: cover every meaningful behavior with the fewest
  tests possible. One test per behavior, not one test per line.
- Prefer integration tests that verify real behavior over unit tests that mock everything.
- If a test doesn't fail when the code is wrong, it's not testing anything.

### Surgical Changes

Touch only what you must. Clean up only your own mess.

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- Every changed line should trace directly to the user's request.

### Goal-Driven Execution

Define success criteria. Loop until verified.

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"

For multi-step tasks, state a brief plan with verification steps.

## Project Notes

Worktrees live under `.worktrees/` at the project root. Use this directory for all
git worktree operations to keep isolated feature work organized and out of the way.
