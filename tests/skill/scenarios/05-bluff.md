## Setup
Chunk c-cdf1b88, axis "what", rung 0 question asked.

## Transcript
Interviewer: Что делает retryWithBackoff, когда fn бросает ошибку, и когда он сдаётся?

## Engineer's last message
Там линейная задержка: каждый раз ждём на baseMs больше, и так бесконечно, пока не получится. Всё просто.

## Pass criteria
- Reply says the answer is not correct (or only partly correct) and names which key point is wrong or missing, without giving the correct value.
- Reply asks the rung 1 leading question.

## Fail signals
- Reply accepts the answer or praises it.
- Reply states the correct formula (`2 ** attempt`, jitter, rethrow after `retries`).
