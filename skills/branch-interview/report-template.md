# Report template

Fill `{{…}}` from `state.md`. Use the heading set for the session language. Omit a section whose list is empty, except Summary and Chunks.

| Slot | en | ru |
|------|----|----|
| title | Branch interview: {{branch}} | Прожарка: {{branch}} |
| summary | Summary | Сводка |
| summary line | {{n}} chunks: knew {{r0}} · with hints {{r12}} · after explanation {{r3}} · skipped {{skipped}} | {{n}} кусков: знает {{r0}} · с подсказкой {{r12}} · после объяснения {{r3}} · пропущено {{skipped}} |
| not reviewed | Not reviewed: {{list or count}} | Не проверено: {{list or count}} |
| changed | Changed after review: {{list}} | Изменено после проверки: {{list}} |
| gaps | Gaps: what to reread | Пробелы: что перечитать |
| findings | Findings | Находки |
| disagreements | Disagreements with the dossier | Расхождения с досье |
| chunks | Chunks | Куски |
| axes | What · Why · Alternatives · Weaknesses | Суть · Зачем · Альтернативы · Минусы |
| rung | rung {{n}} | ступень {{n}} |
| restatement | (restatement) | (пересказ) |
| skipped | skipped | пропущено |

```markdown
---
branch: {{branch}}
mode: {{mode}}
base_sha: {{base_sha}}
head_sha: {{head_sha}}
date: {{YYYY-MM-DD}}
engineer: {{git config user.name}}
language: {{ru|en}}
---
# {{title}}

## {{summary}}
{{summary line}}
{{not reviewed}}
{{changed}}

## {{gaps}}
- {{file:lines}} — {{axis}}: {{rung}}. {{one line: what was not known}}

## {{findings}}
- {{file:line}} — {{finding}}

## {{disagreements}}
- {{file:lines}} — {{how the engineer's intent differs; consistent with code: yes}}

## {{chunks}}
### {{i}}. {{file:lines}} — {{reason}}
**{{axis}}** · {{rung}}{{ (restatement) if rung 3}}
> {{engineer's answer, verbatim}}
```

Counting: `{{n}}` is the number of finished chunks (`done` or `skipped`); each counts in exactly one bucket. A chunk is "skipped" if the chunk or any of its axes was skipped. Otherwise it counts by its worst axis: "knew" at rung 0, "with hints" at rung 1–2, "after explanation" at rung 3. Unfinished chunks are not in `{{n}}`: list `not-reviewed` and `in-progress` chunks under "not reviewed", and `changed` chunks only under "changed after review". Gaps list every axis at rung 2 or 3. Never include the interviewer's explanations; only the engineer's words.
