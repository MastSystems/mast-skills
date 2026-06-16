# REF-BINARY

> Shared reference section. The **common core** of the mast binary-invocation
> doctrine, cited by every v2 skill via its `Reference:` line. Per-skill rationale
> clauses and `start`'s install-GATE block are NOT here — they stay in the citing
> skill's body (RT-2 BLOCKER-3, no-false-merge invariant I3). This section holds
> only what is true for every citer.

## Which binary to invoke (A1 common core)

Always run the **prebuilt `mast` binary** — there is no build step, and consumers
have only the prebuilt binary (no source tree, no `cargo`):

- **As a plugin (the common case)** — the plugin adds `mast` to your `PATH`, so
  call it directly:

  ```bash
  mast <args>
  ```

  The first call provisions the right prebuilt binary for your host
  (SHA-256-verified, then cached); later calls run from cache.

- **In a repo that vendors the shim at its root** — call the shim instead:

  ```bash
  ./bin/mast <args>
  ```

  Same mechanism: it fetches the release pinned in `.mast-version`, verifies the
  SHA-256, and caches it.

If `mast` is unavailable and cannot be provisioned, **stop** — do not improvise a
different invocation, and never fall back to building from source (consumers
don't have it). The stop-and-show install handling is a per-skill concern;
`start` owns its own install-gate block.

## Check-only SHA-256 fail-mode (A1b) — `check`-cited callout

This callout is **only relevant to the `check` skill** and is recorded here as the
single home for the doctrine, but it does not apply to skills that merely run
read-only commands:

> The `./bin/mast` shim never falls back to an unverified or stale binary. A
> failing shim (SHA-256 mismatch, fetch failure, or network trouble) means an
> install or network problem — it is **never** a lint finding and must not be
> reported as one.

## When something's off, `doctor` is the escape hatch (A2 common core)

If a `mast` command fails unexpectedly, the project looks misconfigured, or you
are unsure what state things are in, run the binary-native diagnostic before
guessing — via the same invocation rule as A1:

```bash
mast doctor          # the common case — the plugin provides mast on PATH
./bin/mast doctor    # in a repo that vendors the shim at its root
```

`doctor` is daemon-free and **always exits 0** on a successful diagnosis: it
classifies the onboarding phase, names the next step, and accumulates advisory
findings — each carrying a remediation `hint` (`--format json` for machine
output, `--fix` to perform only the safe P0->P1 setup action). It never mutates
specs and never contacts a daemon, so it is always safe as a first diagnostic
step. A `doctor` invocation that *itself* fails signals an install/environment
problem, not a spec problem.
