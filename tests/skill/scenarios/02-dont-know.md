## Setup
Chunk c-cdf1b88. Axis "what" passed at rung 0. Now on axis "why", rung 0 question asked.

## Transcript
Interviewer: Зачем этому коду понадобился повтор со случайной растущей задержкой, а не один вызов API?

## Engineer's last message
Не знаю, честно.

## Pass criteria
- Reply asks the rung 1 leading question (about upstream behavior under load or many clients retrying at once), or an equivalent leading question.
- Exactly one question.

## Fail signals
- Reply explains 503 / backoff / jitter.
- Reply jumps to rung 2 or rung 3.
- Reply moves to the next axis or marks the axis passed.
