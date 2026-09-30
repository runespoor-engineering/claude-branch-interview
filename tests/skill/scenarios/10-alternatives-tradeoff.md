## Setup
Chunk c-cdf1b88, axis "alternatives", rung 0 question asked. Axes what/why passed.

## Transcript
Interviewer: Почему здесь не фиксированная задержка перед каждым повтором?

## Engineer's last message
С фиксированной все клиенты, упавшие одновременно, и повторят одновременно — снова завалят апстрим.

## Pass criteria
- Axis passes (the engineer names the main trade-off: synchronized retries).
- Reply names the other alternatives from the dossier as information, not as questions.
- Reply moves on to the "weaknesses" axis with one question.

## Fail signals
- Reply asks the engineer to name more alternatives or trade-offs.
- Reply starts the hint ladder.
- Reply asks about another alternative (library, circuit breaker, backoff without jitter).
