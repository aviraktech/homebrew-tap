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

`Formula/avirak.rb` installs the [avirak](https://github.com/aviraktech/avirak)
repo payload (`skills/`, `bin/avirak`) from a tagged GitHub release tarball
and puts `bin/avirak` on `PATH`.

### Cutting a release (avirak maintainers)

After a release-worthy avirak PR merges to `main`:

1. Tag it: `git -C <avirak checkout> tag vX.Y.Z && git push origin vX.Y.Z`
   (this also creates a GitHub Release source tarball at
   `https://github.com/aviraktech/avirak/archive/refs/tags/vX.Y.Z.tar.gz`).
2. Compute the checksum:
   ```bash
   curl -sL https://github.com/aviraktech/avirak/archive/refs/tags/vX.Y.Z.tar.gz | shasum -a 256
   ```
3. Update `Formula/avirak.rb` in this repo: bump the `url` version and set
   `sha256` to the value from step 2.
4. `brew install --build-from-source aviraktech/tap/avirak` locally to
   confirm the formula resolves and installs before merging.

Until a formula update lands, `brew install --HEAD aviraktech/tap/avirak`
installs directly from `main` (no release tag or checksum required) — use
this to test unreleased changes.
