---
name: handoff
description: Hand off the current session to another agent — write a document with everything needed to resume the task with zero conversation context. Use when the user runs /handoff or asks to hand off, transfer, or park the current work for another agent or a later session.
disable-model-invocation: true
---

# Handoff

Write a handoff document that lets a fresh agent — zero conversation context —
continue this task without asking a single question or re-discovering anything
this session already learned.

## Location

Write to `.agents/handoff/<yyyy-mm-dd>-<task-slug>.md` at the repo root,
creating the directory if missing (`.agents/` is the canonical agent dir).
An explicit path in the invocation args overrides this.

## Content

Facts over narrative: record the state of the world, not the story of the
session. Where a fact was superseded during the session (a changed limit, a
renamed variable, a corrected command), record only the final value.
Mid-session user corrections and preferences exist only in this conversation
and are the easiest thing to lose — carry every one of them.

Required sections:

1. **Task** — the original request plus every scope change the user made since.
2. **Current state** — done vs remaining; committed vs uncommitted (name the
   commits).
3. **Decisions** — each settled choice with its why, including rejected
   alternatives, so the next agent doesn't relitigate or undo them.
4. **Files** — absolute repo root path, then each file touched or load-bearing
   with one line on its role. When a remaining task's details are defined
   somewhere else (a test file, a spec, a ticket), point at it explicitly.
5. **How to verify** — exact commands including env prefixes and how to get
   the tools (dev shell, container, plain PATH), plus their current expected
   output.
6. **Gotchas** — dead ends already hit, non-obvious constraints, known-broken
   things to ignore.
7. **Next steps** — ordered and concrete, starting with the single next
   action.

A section with nothing to say gets one line saying so ("no uncommitted
changes"), not silence — the reader must be able to tell empty from forgotten.

## After writing

Tell the user the file path and the one-liner to start the next agent, e.g.:

> Read `.agents/handoff/2026-09-01-rate-limit.md` and continue the task.
