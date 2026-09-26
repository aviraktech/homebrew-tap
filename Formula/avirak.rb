# frozen_string_literal: true

# AI Head-of-Engineering: portable lead persona + gh-workflow skill payload.
class Avirak < Formula
  desc "AI Head-of-Engineering: portable lead persona + gh-workflow skill payload"
  homepage "https://github.com/aviraktech/avirak"
  url "ssh://git@github.com/aviraktech/avirak.git",
      tag:   "v0.12.9",
      using: :git # repo is private; switch to tarball+sha256 (see tap README) once it's public
  license "MIT"
  head "https://github.com/aviraktech/avirak.git", branch: "main"

  depends_on "go" => :build
  # RUNTIME dep since avirak#417: both shipped ACP adapters (codex-acp and
  # claude-agent-acp) are Node programs, vendored into libexec below. Being the
  # formula's ONE node dependency is also what lets Homebrew's cleaner rewrite
  # their `#!/usr/bin/env node` shebangs to this node's absolute path, so a
  # dispatch never depends on whatever `node` happens to be on PATH.
  depends_on "node"

  # All four are still RUNTIME deps of the surviving skills/gh-workflow scripts
  # (file-issue.sh, init-config.sh, post-persona-handshake.sh,
  # select-quality-mode.sh), which stay bash by ruling (avirak#58). Epic #207
  # ported dispatch.sh + herd-events.sh to the `avirak dispatch` Go verb and
  # deleted them (v0.8.0), but that dropped no dep — the surviving scripts still
  # need bash/gh/jq/python, and the Go binary shells out to none of them.
  depends_on "bash"
  depends_on "gh"
  depends_on "jq"
  depends_on "python@3.11"

  def install
    # Ship the whole payload (skills/, launchd/) into libexec, then build the
    # unified binary INTO that payload and symlink it onto PATH.
    libexec.install Dir["*"]

    # The output path is not arbitrary: avirak finds skills/ and the launchd
    # plist template by resolving its own location (following the bin symlink
    # below) and walking TWO directories up. libexec/bin/avirak is what makes
    # that land on libexec. Until v0.3.0 this path held the bash entrypoint;
    # the Go binary now takes its place.
    cd libexec do
      system "go", "build",
             "-trimpath",
             "-ldflags", "-X main.version=#{stable.version}",
             "-o", libexec/"bin/avirak",
             "./cmd/avirak"
    end

    # avirak#417: vendor the pinned ACP adapters into avirak's OWN libexec —
    # never globally. The payload carries the one pin (package.json) and a
    # lockfile (npm-shrinkwrap.json) pinning every transitive dependency with
    # its sha512; `npm ci` installs EXACTLY that lockfile or fails, and the
    # binary embeds the same package.json, so this formula spells no adapter
    # version of its own and cannot disagree with the binary about one.
    # std_npm_args(prefix: false) is Homebrew's local-install argument set
    # (--ignore-scripts, its npm cache, the release cooldown). Everything is
    # fetched HERE, at install time; nothing is fetched when avirak dispatches.
    cd libexec/"internal/acpadapter/npm" do
      system "npm", "ci", *std_npm_args(prefix: false)
    end

    bin.install_symlink libexec/"bin/avirak"
  end

  test do
    # stable.version, NOT version: on a HEAD build `version` is "HEAD-<rev>",
    # which would both stamp a non-semver into the binary and fail the regex
    # below. The install block stamps stable.version for the same reason.
    assert_match(/\Aavirak \d+\.\d+\.\d+\n\z/, shell_output("#{bin}/avirak version"))

    # setup/doctor/uninstall must be safe to exercise in `brew test` without
    # touching the real machine — point everything at a scratch HOME.
    # Explicitly redirect stdin from /dev/null (not just relying on brew
    # test's own stdin being non-interactive — it can inherit a real tty
    # depending on invocation context, which would otherwise send `setup`
    # into its interactive confirm() prompts and stall for up to a minute
    # on their 30s read timeouts) so setup/uninstall deterministically
    # decline the optional sweep/integrations prompts immediately, without
    # enabling real sweep work.
    fake_home = testpath/"fake-home"
    fake_home.mkpath

    # Formula#system doesn't accept Kernel#system's `in:` kwarg (sorbet
    # signature only allows Integer/Pathname/String/Symbol args), so
    # redirect stdin from /dev/null via an explicit shell command instead.
    system "#{bin}/avirak setup --home #{fake_home} < /dev/null"
    assert_predicate fake_home/".agents/skills/avirak", :symlink?
    assert_predicate fake_home/".agents/skills/gh-workflow", :symlink?
    # avirak logs to stderr, not stdout — redirect it in so shell_output
    # actually captures the "readable through link" lines.
    doctor = shell_output("#{bin}/avirak doctor --home #{fake_home} 2>&1")
    assert_match "readable through link", doctor

    # avirak#417: the vendored ACP adapters exist and report their pinned
    # versions — offline, and without executing either adapter. `version
    # --verbose` prints the pins compiled into the binary; doctor compares them
    # against what `npm ci` installed (present, executable, installed
    # package.json version == pin) and names each entry's interpreter, which
    # must be THIS formula's node (the cleaner's shebang rewrite).
    verbose = shell_output("#{bin}/avirak version --verbose")
    node = Regexp.escape((Formula["node"].opt_bin/"node").to_s)
    %w[codex-acp claude-agent-acp].each do |id|
      assert_match(%r{^pinned @agentclientprotocol/#{id} \d+\.\d+\.\d+ }, verbose)
      assert_match(/\[ok\] acp adapter\s+#{id} \d+\.\d+\.\d+ installed at its pin \(.*, via #{node};/, doctor)
    end
    system "#{bin}/avirak uninstall --home #{fake_home} < /dev/null"
    refute_path_exists fake_home/".agents/skills/avirak"
  end
end
