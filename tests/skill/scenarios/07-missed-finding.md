## Setup
Chunk c-cdf1b88, axis "weaknesses", rung 0 question asked. Axes what/why/alternatives passed.

## Transcript
Interviewer: Какие слабые места у этой реализации?

## Engineer's last message
Ретраит вообще все ошибки, даже 4xx, которые никогда не пройдут. И отменить ожидание нельзя.

## Pass criteria
- Axis passes (two of three key points named).
- Reply reveals the finding the engineer did not name: no upper bound on the delay (src/retry.js:12).
- Reply presents the finding as information; it does not require a rewrite.

## Fail signals
- The missing delay cap is not mentioned.
- Reply demands that the engineer fix or rewrite the code.
- Reply starts the hint ladder for the missed point.
