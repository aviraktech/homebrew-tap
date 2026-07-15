# homebrew-tap
Homebrew tap for avirak — an AI Head-of-Engineering

## Install

```bash
brew install aviraktech/tap/avirak
avirak setup
```

See the [avirak README](https://github.com/aviraktech/avirak#readme) for
what `avirak setup` does and the full command reference.

## Formula

`aviraktech/avirak` is currently **private**, so `Formula/avirak.rb` installs
the repo payload (`skills/`, `bin/avirak`) via a git+SSH checkout of a tagged
ref (`url "ssh://git@github.com/aviraktech/avirak.git", tag: ..., using: :git`)
and puts `bin/avirak` on `PATH`. This requires the installing machine to have
SSH access to the repo — there is no checksum step while this scheme is in
use.

### Cutting a release (avirak maintainers) — current private-repo flow

After a release-worthy avirak PR merges to `main`:

1. Tag it: `git -C <avirak checkout> tag vX.Y.Z && git push origin vX.Y.Z`.
2. Update `Formula/avirak.rb` in this repo: bump the `tag:` value to `vX.Y.Z`.
3. `brew install --build-from-source aviraktech/tap/avirak` locally to
   confirm the formula resolves and installs before merging.

Until a formula update lands, `brew install --HEAD aviraktech/tap/avirak`
installs directly from `main` (no release tag required) — use this to test
unreleased changes.

### Once `aviraktech/avirak` goes public — switch to tarball+sha256

Tagging still creates a GitHub Release source tarball at
`https://github.com/aviraktech/avirak/archive/refs/tags/vX.Y.Z.tar.gz`. Once
the repo is public, switch the formula off the git+SSH scheme so installs
don't need SSH access:

1. Compute the checksum:
   ```bash
   curl -sL https://github.com/aviraktech/avirak/archive/refs/tags/vX.Y.Z.tar.gz | shasum -a 256
   ```
2. Replace the `url .../using: :git` block in `Formula/avirak.rb` with
   `url "https://github.com/aviraktech/avirak/archive/refs/tags/vX.Y.Z.tar.gz"`
   and `sha256 "<value from step 1>"`.
3. `brew install --build-from-source aviraktech/tap/avirak` locally to
   confirm the formula resolves and installs before merging.
