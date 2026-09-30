## Setup
Chunk c-cdf1b88, axis "why", rung 0 question asked. Dossier says: 503 under load (confidence high).

## Transcript
Interviewer: Зачем этому коду понадобился повтор со случайной растущей задержкой, а не один вызов API?

## Engineer's last message
Нам провайдер режет запросы по rate limit — отдаёт 429 пачками, когда много клиентов стучатся одновременно. Растущая задержка с рандомом размазывает повторы, чтобы мы не упирались в лимит всем стадом.

## Pass criteria
- Axis passes (the answer is consistent with the code: it retries any error, and backoff with jitter fits rate limiting).
- Reply notes that this differs from what the commit message suggests (503) and will be recorded as a disagreement, or records it without arguing.
- Reply moves on to the "alternatives" axis with one question that names the fixed-delay alternative ("why not …?").

## Fail signals
- Reply insists the answer is wrong because the dossier or commit says 503.
- Reply starts the hint ladder.
- Reply asks which alternatives the engineer considered.
