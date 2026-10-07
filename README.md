# claude-branch-interview

Claude Code plugin that interviews an engineer about the code in their branch until they show they own it.

## Why

AI writes code fast. Every line it writes still has to be read, changed, supported, and checked for security holes by someone, for as long as the product lives. This is the cost of code ownership, and each generated line makes the product more expensive to own. Generated code also shapes the architecture and the non-functional properties of the system. If the engineer does not control that, the product costs more to maintain every month. The time saved at generation is paid back later, with interest.

Cybernetics has a rule for this. W. Ross Ashby stated his law of requisite variety in *An Introduction to Cybernetics* (1956) as "only variety can destroy variety": a regulator can keep a system under control only if it has at least as many distinct responses as there are distinct disturbances it must handle. Applied to software, an engineer who does not understand the code cannot steer the AI that writes it, and a large project quickly outgrows them. A driver can take a car across town without knowing how the engine works. The engineer who designs the car cannot. A developer working with AI is in the second position. They need to know how the generated code works and why it looks the way it does, instead of trusting the tool.

This plugin checks that understanding before the code leaves your machine. It does not grade the code. It checks whether you, the person who will own it, can explain it.

## What it does

It picks the decisions in your change (at most 5, riskiest first) and asks about them one question at a time: what each part does, why it was added, why not the obvious alternative, and where it is weak. When you don't know, it leads you to the answer with hints instead of handing it over. Only your own words count. At the end you get a summary in the chat: what you knew, what needed a hint, and what to reread. The whole plugin is one `SKILL.md`, with no scripts, agents, or saved state.

For the full design, see [docs/how-it-works.md](docs/how-it-works.md).

## Install

```
/plugin marketplace add runespoor-engineering/claude-plugins
/plugin install branch-interview@runespoor
```

The plugin is listed in the [runespoor marketplace](https://github.com/runespoor-engineering/claude-plugins). To update, run `/plugin marketplace update runespoor`.

## Use

```
/branch-interview:branch-interview branch             # your branch vs its merge-base with main
/branch-interview:branch-interview last-commit        # only HEAD
/branch-interview:branch-interview uncommitted        # staged, unstaged, and untracked changes
/branch-interview:branch-interview files <path>...    # chosen files vs the merge-base
```

By default you are asked about at most 5 decisions. Tests, docs, and other changes that only follow from a decision are not asked about directly. Add `--all` to list every decision.

During the interview you can say `explain`, `skip`, or `stop`, in any language.

The base branch is `main`, then `master`, then `origin/HEAD`. Override it with `--base <ref>` (e.g. `/branch-interview:branch-interview branch --base develop`).

## Development

```
claude --plugin-dir .    # load the plugin from this checkout
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). This project follows the [Code of Conduct](CODE_OF_CONDUCT.md). To report a vulnerability, see [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
