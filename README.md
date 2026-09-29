# claude-branch-interview

Claude Code plugin that interviews an engineer about the code in their branch until they show they own it.

## Why

AI writes code fast. Every line it writes still has to be read, changed, supported, and checked for security holes by someone, for as long as the product lives. This is the cost of code ownership, and each generated line makes the product more expensive to own. Generated code also shapes the architecture and the non-functional properties of the system. If the engineer does not control that, the product costs more to maintain every month. The time saved at generation is paid back later, with interest.

Cybernetics has a rule for this. W. Ross Ashby stated his law of requisite variety in *An Introduction to Cybernetics* (1956) as "only variety can destroy variety": a regulator can keep a system under control only if it has at least as many distinct responses as there are distinct disturbances it must handle. Applied to software, an engineer who does not understand the code cannot steer the AI that writes it, and a large project quickly outgrows them. A driver can take a car across town without knowing how the engine works. The engineer who designs the car cannot. A developer working with AI is in the second position. They need to know how the generated code works and why it looks the way it does, instead of trusting the tool.

This plugin checks that understanding before the code leaves your machine. It does not grade the code. It checks whether you, the person who will own it, can explain it.

## What it does

It picks the most important, complex, and questionable parts of your change and asks about them one question at a time: what each part does, why it was added, which alternatives existed, and where it is weak. When you don't know, it leads you to the answer with hints instead of handing it over. Only your own words count. The report with your answers and a list of things worth rereading lands in `docs/interviews/`.

For the full design, see [docs/how-it-works.md](docs/how-it-works.md).

## Install

```
/plugin marketplace add BorysShulyak/claude-branch-interview
/plugin install branch-interview@claude-branch-interview
```

## Use

```
/branch-interview:branch-interview branch             # your branch vs its merge-base with main
/branch-interview:branch-interview last-commit        # only HEAD
/branch-interview:branch-interview uncommitted        # staged, unstaged, and untracked changes
/branch-interview:branch-interview files <path>...    # chosen files vs the merge-base
```

By default, `dossier-builder` agents analyze the change in parallel. Add `--inline` (e.g. `/branch-interview:branch-interview branch --inline`) to build the dossiers in the main session instead. Inline mode uses no agents and is faster on small changes, but on large ones the analysis fills the session's context. In inline mode the dossier files, which hold the answers, appear in the tool output; do not expand them.

During the interview you can say `explain` (`объясни`), `skip` (`пропусти`), or `stop` (`хватит`).

The base branch is `main`, then `origin/HEAD`. Override it with `BRANCH_INTERVIEW_BASE=<ref>`.

Local state goes to `.branch-interview/` (added to `.gitignore` on first run). The report goes to `docs/interviews/<key>.md`. Commit it if you want reviewers to see it.

## Development

```
bash tests/scope.test.sh                    # scope.sh tests
bash tests/check-dossier.sh <dossier.md>    # dossier structure check
claude --plugin-dir .                       # load the plugin from this checkout
```

Behavior tests for the interviewer are described in [tests/skill/README.md](tests/skill/README.md) and [docs/testing.md](docs/testing.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). This project follows the [Code of Conduct](CODE_OF_CONDUCT.md). To report a vulnerability, see [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
