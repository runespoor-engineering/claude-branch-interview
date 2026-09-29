#!/usr/bin/env bash
# Builds the fixture repo used by the skill behavior tests.
# Usage: bash tests/skill/make-fixture.sh <target-dir>
# Result: repo with branch feat/retry off main. Seeded chunks:
#   src/retry.js  - exponential backoff with jitter; BUG: no upper bound on delay;
#                   doubtful: retries every error, including 4xx
#   src/cache.js  - TTL memoize; weakness: expired entries are never evicted
#   src/http.js   - wires retry + cache into getJson
#   noise         - package-lock.json, rename docs/usage.md -> docs/guide.md
set -euo pipefail

target=${1:?usage: make-fixture.sh <target-dir>}
[ ! -e "$target" ] || { echo "make-fixture.sh: $target already exists" >&2; exit 1; }
mkdir -p "$target"
cd "$target"

git init -q -b main
git config user.email fixture@example.com
git config user.name fixture

mkdir -p src docs
cat > src/http.js <<'EOF'
async function getJson(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

module.exports = { getJson };
EOF
printf '# Usage\n\nCall getJson(url).\n' > docs/usage.md
git add -A
git commit -qm "feat: add getJson helper"

git checkout -qb feat/retry

cat > src/retry.js <<'EOF'
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// Retries fn with exponential backoff and full jitter.
async function retryWithBackoff(fn, { retries = 5, baseMs = 100 } = {}) {
  let attempt = 0;
  for (;;) {
    try {
      return await fn();
    } catch (err) {
      attempt += 1;
      if (attempt > retries) throw err;
      const delay = Math.random() * baseMs * 2 ** attempt;
      await sleep(delay);
    }
  }
}

module.exports = { retryWithBackoff };
EOF
git add -A
git commit -qm "feat: retry failed requests with exponential backoff

Upstream API returns 503 under load. Jitter spreads retries so clients
do not hit it in lockstep."

cat > src/cache.js <<'EOF'
// Memoizes an async function per key for ttlMs.
function memoizeTtl(fn, ttlMs) {
  const entries = new Map();
  return async (key) => {
    const hit = entries.get(key);
    if (hit && hit.expires > Date.now()) return hit.value;
    const value = await fn(key);
    entries.set(key, { value, expires: Date.now() + ttlMs });
    return value;
  };
}

module.exports = { memoizeTtl };
EOF
cat > src/http.js <<'EOF'
const { retryWithBackoff } = require('./retry');
const { memoizeTtl } = require('./cache');

async function fetchJson(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

const getJson = memoizeTtl((url) => retryWithBackoff(() => fetchJson(url)), 30_000);

module.exports = { getJson };
EOF
printf '{\n  "name": "fixture",\n  "lockfileVersion": 3\n}\n' > package-lock.json
git add -A
git commit -qm "feat: cache getJson responses for 30s"

git mv docs/usage.md docs/guide.md
git commit -qm "docs: rename usage to guide"

echo "fixture ready: $target (branch feat/retry)"
