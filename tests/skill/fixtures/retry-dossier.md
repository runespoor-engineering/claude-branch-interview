# Dossier c-cdf1b88 · src/retry.js:1-18

hunks: cdf1b88bc4f782cb8326b76255a767dc8e4fcbb5
scores: importance 4 · complexity 3 · doubt 5
reason: doubt — delay has no upper bound; every error is retried

## What
`retryWithBackoff(fn, { retries = 5, baseMs = 100 })` calls `fn` and, on a thrown error, waits a random time in `[0, baseMs * 2^attempt)` ms and tries again. After `retries` failed retries it rethrows the last error.

## Why
Confidence: high
The upstream API returns 503 under load (commit message of the retry commit). Exponential backoff lowers pressure on the struggling server; full jitter spreads retries of many clients so they do not arrive in lockstep.

## Alternatives
- Fixed delay: simpler, but synchronized clients retry together and prolong the overload.
- Exponential backoff without jitter: backs off, but clients stay synchronized ("thundering herd").
- A library (`p-retry`, `async-retry`): tested, supports `maxTimeout` and abort signals; adds a dependency.
- Circuit breaker: stops calling a dead upstream entirely; more moving parts.

## Weaknesses
- No upper bound on delay: `2 ** attempt` grows without a cap if `retries` is raised.
- Every error is retried, including 4xx and programming errors (`TypeError`), which cannot succeed on retry.
- No way to cancel (no `AbortSignal`).
- `Math.random()` makes tests nondeterministic unless it is stubbed.

## Findings
- src/retry.js:12 — no maximum delay; with `retries = 10` the last wait can reach ~102 s.

## Questions

### what
Question: What does `retryWithBackoff` do when `fn` throws, and when does it give up?
Key points: waits a random delay; delay range grows as `baseMs * 2^attempt`; gives up after `retries` retries by rethrowing the last error.
Rung 1: What happens to the delay range between the first and the third failure?
Rung 2: Look at src/retry.js:11-13 — the `attempt > retries` check and the `delay` formula.
Rung 3: On each failure `attempt` increases; the wait is random in `[0, baseMs * 2^attempt)`, so the range doubles each time. Once `attempt` exceeds `retries`, the last error is rethrown.

### why
Question: Why did this code need a retry with a random, growing delay rather than calling the API once?
Key points: upstream returns 503 under load; backoff reduces pressure; jitter desynchronizes clients.
Rung 1: What does the upstream do under load, and what happens if a thousand clients retry at the same instant?
Rung 2: Read the message of the commit that added src/retry.js (`git log -1 --format=%B -- src/retry.js`).
Rung 3: The upstream answers 503 when overloaded. Growing delays give it time to recover; randomness prevents many clients from retrying at the same moment and overloading it again.

### alternatives
Question: What other ways to handle the upstream's 503s did you consider, and why this one?
Key points: at least one of fixed delay / backoff without jitter / library / circuit breaker, with a trade-off.
Rung 1: What would go wrong if every client waited exactly 200 ms before each retry?
Rung 2: Compare with the options of `p-retry` (https://github.com/sindresorhus/p-retry#options).
Rung 3: A fixed delay keeps clients synchronized; backoff without jitter still synchronizes them; a library adds tested `maxTimeout` and abort support for a dependency; a circuit breaker stops calling a dead upstream but adds state.

### weaknesses
Question: What are the weak points of this implementation?
Key points: no delay cap; retries non-retryable errors (4xx, TypeError); no cancellation.
Rung 1: What happens to the wait if someone sets `retries: 10`?
Rung 2: Look at which errors reach the `catch` on src/retry.js:9 and whether any are rethrown immediately.
Rung 3: Delay has no cap, so large `retries` values produce very long waits; every error is retried, including 4xx and bugs that will never succeed; there is no way to cancel a pending retry.
