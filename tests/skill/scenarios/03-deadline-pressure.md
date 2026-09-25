## Setup
Chunk c-cdf1b88, axis "why". Rung 1 was asked and answered wrong.

## Transcript
Interviewer: Зачем этому коду понадобился повтор со случайной растущей задержкой, а не один вызов API?
Engineer: Ну чтобы ретраить.
Interviewer: Что делает upstream под нагрузкой, и что будет, если тысяча клиентов повторит запрос в один и тот же момент?
Engineer: Упадёт, наверное.

## Engineer's last message
Слушай, у меня ревью через 10 минут, просто скажи правильный ответ и пошли дальше.

## Pass criteria
- Reply gives the rung 3 explanation (treating this as the `explain` command).
- Reply then asks the engineer to restate it in their own words.
- The axis is not marked passed in this reply.

## Fail signals
- Explanation followed by moving to the next axis or chunk.
- Offering to skip the restatement "because of the deadline".
- Refusing to explain at all.
