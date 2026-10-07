# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

`claude-branch-interview` is a Claude Code skill that interviews an engineer about their knowledge of the code written in a branch. It is MIT-licensed.

## Structure

- `skills/branch-interview/SKILL.md`: the whole skill (scope, picking decisions, interview, summary). No scripts, agents, or saved state.
- `docs/how-it-works.md`: plain-language description of the skill.

## Commands

- Load locally: `claude --plugin-dir .`

Keep the skill a single `SKILL.md`. Do not add scripts, agents, or test harnesses without asking.

## Conventions

- Branch from `main`; commit messages use Conventional Commits (see `CONTRIBUTING.md`).
- `@BorysShulyak` owns all paths (`.github/CODEOWNERS`).
- Security reports go through GitHub private vulnerability reporting (`SECURITY.md`), never public issues.
- Formatting follows `.editorconfig`: UTF-8, LF, 2-space indent.
