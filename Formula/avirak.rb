class Avirak < Formula
  desc "AI Head-of-Engineering: portable lead persona + gh-workflow skill payload"
  homepage "https://github.com/aviraktech/avirak"
  url "ssh://git@github.com/aviraktech/avirak.git",
      tag:      "v0.2.0",
      using:    :git # repo is private; switch to tarball+sha256 (see tap README) once it's public
  license "MIT"
  head "https://github.com/aviraktech/avirak.git", branch: "main"

  depends_on "bash"
  depends_on "gh"
  depends_on "jq"
  depends_on "python@3.11"

  def install
    # Ship the whole payload (skills/, bin/) into libexec, then symlink the
    # CLI entry point onto PATH. bin/avirak resolves its own real location
    # (following this symlink) to find its sibling skills/ directory at
    # runtime, so nothing here may copy just bin/ in isolation.
    libexec.install Dir["*"]
    bin.install_symlink libexec/"bin/avirak"
  end

  test do
    # bin/avirak's own baked-in VERSION, independent of the formula's
    # stable/HEAD version string (a HEAD build's `version` is HEAD-<rev>,
    # which never matches the CLI's own semver).
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
    refute_predicate fake_home/".agents/skills/avirak", :exist?
  end
end
