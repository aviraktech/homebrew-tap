# frozen_string_literal: true

# AI Head-of-Engineering: portable lead persona + gh-workflow skill payload.
class Avirak < Formula
  desc "AI Head-of-Engineering: portable lead persona + gh-workflow skill payload"
  homepage "https://github.com/aviraktech/avirak"
  url "ssh://git@github.com/aviraktech/avirak.git",
      tag:   "v0.4.0",
      using: :git # repo is private; switch to tarball+sha256 (see tap README) once it's public
  license "MIT"
  head "https://github.com/aviraktech/avirak.git", branch: "main"

  depends_on "go" => :build

  # All four are still RUNTIME deps of the shipped bash payload (dispatch.sh,
  # herd-events.sh, the gh-workflow scripts), which stays bash by ruling
  # (avirak#58). Retiring bin/avirak and install-sweep.sh did not drop any of
  # them — the Go binary itself shells out to none of them.
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
    assert_match "readable through link", shell_output("#{bin}/avirak doctor --home #{fake_home} 2>&1")
    system "#{bin}/avirak uninstall --home #{fake_home} < /dev/null"
    refute_path_exists fake_home/".agents/skills/avirak"
  end
end
