# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

`claude-branch-interview` is a Claude Code skill that interviews an engineer about their knowledge of the code written in a branch. It is MIT-licensed.

## Structure

- `skills/branch-interview/SKILL.md`: session driver (setup, hint-ladder interview, state, report).
- `skills/branch-interview/scripts/scope.sh`: deterministic scope, hunk hashes, noise flags, state diff. Must run on bash 3.2.
- `skills/branch-interview/report-template.md`: report skeleton with ru/en headings.
- `agents/dossier-builder.md`: plugin agent that writes one dossier per chunk.
- `tests/skill/`: fixture repo builder, interviewer scenarios, recorded runs.

## Commands

- Test: `bash tests/scope.test.sh`
- Lint: `shellcheck skills/branch-interview/scripts/scope.sh tests/*.sh tests/skill/*.sh`
- Load locally: `claude --plugin-dir .`

Changes to `SKILL.md` or `agents/dossier-builder.md` follow superpowers:writing-skills: rerun the scenarios in `tests/skill/` before and after.

## Conventions

- Branch from `main`; commit messages use Conventional Commits (see `CONTRIBUTING.md`).
- `@BorysShulyak` owns all paths (`.github/CODEOWNERS`).
- Security reports go through GitHub private vulnerability reporting (`SECURITY.md`), never public issues.
- Formatting follows `.editorconfig`: UTF-8, LF, 2-space indent.
