# claude-branch-interview

Claude Code plugin that interviews an engineer about the code in their branch until they show they own it.

It picks the most important, complex, and questionable parts of your change and asks, one question at a time, what each part does, why it was added, which alternatives existed, and what its weak points are. When you don't know, it leads you to the answer with hints instead of handing it over. The report with your own answers lands in `docs/interviews/`.

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

During the interview you can say `explain` (`объясни`), `skip` (`пропусти`), or `stop` (`хватит`).

The base branch is `main`, then `origin/HEAD`. Override it with `BRANCH_INTERVIEW_BASE=<ref>`.

Local state goes to `.branch-interview/` (added to `.gitignore` on first run). The report goes to `docs/interviews/<key>.md`; commit it if you want reviewers to see it.

## Development

```
bash tests/scope.test.sh                    # scope.sh tests
bash tests/check-dossier.sh <dossier.md>    # dossier structure check
claude --plugin-dir .                       # load the plugin from this checkout
```

Behavior tests for the interviewer are described in [tests/skill/README.md](tests/skill/README.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). This project follows the [Code of Conduct](CODE_OF_CONDUCT.md). To report a vulnerability, see [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
