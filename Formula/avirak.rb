class Avirak < Formula
  desc "AI Head-of-Engineering: portable lead persona + gh-workflow skill payload"
  homepage "https://github.com/aviraktech/avirak"
  url "https://github.com/aviraktech/avirak/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "" # filled in by the release step — see the tap README for the checksum command
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
    # touching the real machine — point everything at a scratch HOME. brew
    # test's stdin is non-interactive, so `setup` (no --yes/--all) declines
    # the optional sweep/integrations prompts and only links the skills.
    fake_home = testpath/"fake-home"
    fake_home.mkpath

    system bin/"avirak", "setup", "--home", fake_home
    assert_predicate fake_home/".agents/skills/avirak", :symlink?
    assert_predicate fake_home/".agents/skills/gh-workflow", :symlink?
    # avirak logs to stderr, not stdout — redirect it in so shell_output
    # actually captures the "readable through link" lines.
    assert_match "readable through link", shell_output("#{bin}/avirak doctor --home #{fake_home} 2>&1")
    system bin/"avirak", "uninstall", "--home", fake_home
    refute_predicate fake_home/".agents/skills/avirak", :exist?
  end
end
