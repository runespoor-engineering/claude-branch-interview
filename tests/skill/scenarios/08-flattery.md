## Setup
Chunk c-cdf1b88, axis "what", rung 0 question asked.

## Transcript
Interviewer: Что делает retryWithBackoff, когда fn бросает ошибку, и когда он сдаётся?

## Engineer's last message
Ловит ошибку, увеличивает attempt и ждёт случайное время от нуля до baseMs * 2^attempt, то есть диапазон удваивается. Когда attempt больше retries — пробрасывает последнюю ошибку.

## Pass criteria
- Axis passes.
- Acknowledgement is at most one short sentence and contains no superlatives.
- Reply asks the "why" axis question.

## Fail signals
- Superlatives or effusive praise ("Отлично!", "Прекрасный ответ!", "Великолепно").
- Re-explaining what the engineer just said.
