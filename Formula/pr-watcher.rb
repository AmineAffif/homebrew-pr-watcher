class PrWatcher < Formula
  desc "Menu bar watcher that notifies when GitHub PRs get merged"
  homepage "https://github.com/amineaffif/homebrew-pr-watcher"
  url "https://github.com/amineaffif/homebrew-pr-watcher/archive/refs/tags/v0.1.3.tar.gz"
  sha256 "62a87cd6cab67835cba1d49c8cf163607cd711e9921880409cecf2b8a9e4a990"
  license "MIT"
  version "0.1.3"

  depends_on "gh"
  depends_on "jq"
  # NOTE: a formula cannot declare a cask dependency, so SwiftBar is installed
  # by the user via the caveats (`brew install --cask swiftbar`).

  def install
    # Bin scripts land in $HOMEBREW_PREFIX/bin so they're on PATH.
    bin.install Dir["bin/pr-watcher*"]

    # Runtime assets (SwiftBar plugin + notification template + launchd template)
    # live under $HOMEBREW_PREFIX/share/pr-watcher.
    (share/"pr-watcher").install "plugin/pr-watcher.5m.sh"
    (share/"pr-watcher").install "templates/notify.template.html"
    (share/"pr-watcher").install "launchd/com.prwatcher.plist.template"
  end

  def post_install
    home        = ENV["HOME"]
    plugin_dir  = "#{home}/Library/Application Support/SwiftBar/Plugins"
    launch_dir  = "#{home}/Library/LaunchAgents"
    log_dir     = "#{home}/.pr-watcher/logs"
    plist_path  = "#{launch_dir}/com.prwatcher.plist"
    share_dir   = "#{share}/pr-watcher"

    FileUtils.mkdir_p([plugin_dir, launch_dir, log_dir])

    # Copy the SwiftBar plugin into the user's plugin directory. Users can
    # delete/replace it later — we only touch it if missing to avoid clobbering
    # a hand-edited local version.
    plugin_src = "#{share_dir}/pr-watcher.5m.sh"
    plugin_dst = "#{plugin_dir}/pr-watcher.5m.sh"
    unless File.exist?(plugin_dst)
      FileUtils.cp(plugin_src, plugin_dst)
      FileUtils.chmod(0755, plugin_dst)
    end

    # Render the launchd plist with the real user paths substituted in.
    plist_template = File.read("#{share_dir}/com.prwatcher.plist.template")
    plist_template.gsub!("__PRWATCHER_BIN__", "#{bin}/pr-watcher")
    plist_template.gsub!("__HOME__", home)
    plist_template.gsub!("__LOG_DIR__", log_dir)
    plist_template.gsub!("__HOMEBREW_BIN__", "#{HOMEBREW_PREFIX}/bin")
    plist_template.gsub!("__SHARE_DIR__", share_dir)
    File.write(plist_path, plist_template)

    # Try to bootstrap the launchd job. quiet_system (not system) so a failed
    # bootout on a fresh install — expected, the job isn't loaded yet — doesn't
    # raise and abort post_install. The caveats cover loading it manually.
    quiet_system "launchctl", "bootout", "gui/#{Process.uid}", plist_path
    quiet_system "launchctl", "bootstrap", "gui/#{Process.uid}", plist_path
  end

  def caveats
    <<~EOS
      pr-watcher installed 🎉

      ── One-time setup ────────────────────────────────────────
      1. Install SwiftBar (the menu bar host) if you don't have it:
           brew install --cask swiftbar

      2. Authenticate GitHub CLI (needed to read PR state):
           gh auth login

      3. Launch SwiftBar (once — it starts at login afterwards):
           open -a SwiftBar

      4. Look for the 👁 icon in your menu bar. Click it, paste a
         GitHub PR URL to your clipboard, then use "✨ Add from
         clipboard".

      ── Background poller ─────────────────────────────────────
        A launchd job checks your PRs hourly. It loads automatically
        at your next login. To start it right now:
          launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.prwatcher.plist

      ── Config / State ────────────────────────────────────────
        Config:  ~/.pr-watcher/config.json
        State:   ~/.pr-watcher/state.json
        Logs:    ~/.pr-watcher/logs/pr-watcher.log

      ── Uninstall cleanly ─────────────────────────────────────
        brew uninstall pr-watcher
        launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.prwatcher.plist
        rm ~/Library/LaunchAgents/com.prwatcher.plist
        rm ~/Library/Application\\ Support/SwiftBar/Plugins/pr-watcher.5m.sh
        rm -rf ~/.pr-watcher
    EOS
  end

  test do
    system "#{bin}/pr-watcher-copy", "https://github.com/octocat/Hello-World/pull/1"
  end
end
