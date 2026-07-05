# pr-watcher

A macOS menu bar tool that watches your favorite GitHub PRs and throws a big
animated party in your browser (with confetti) the moment they merge.

## Install

Copy-paste this. One-time setup, ~1 minute:

```bash
brew install amineaffif/pr-watcher/pr-watcher   # the tool
brew install --cask swiftbar                    # the menu bar host (skip if you have it)
gh auth status || gh auth login                 # connect GitHub only if not already logged in
open -a SwiftBar || open /Applications/SwiftBar.app   # start it (fallback if just installed)
```

**On SwiftBar's first launch** it asks where your plugins live. The installer
already dropped the plugin in the right place — you just need to point SwiftBar
at it. That folder is under the hidden `~/Library`, so:

1. Click **OK**.
2. Press **`⌘ ⇧ G`** (Go to Folder) and paste:
   ```
   ~/Library/Application Support/SwiftBar/Plugins
   ```
3. Hit Enter, then **Open** to confirm.

Done. Click the 👁 icon in your menu bar and paste a GitHub PR URL. 🎉

> Updating later is just `brew upgrade pr-watcher`.

## Features

- **Menu bar UI**: 👁 icon with `open/total` badge, submenus per PR (Copy /
  Remove), one-click add from the clipboard.
- **Automatic polling**: every hour, weekdays 9h–17h local time.
- **Full-screen celebration** in your default browser when a PR merges —
  confetti, gradient, gentle chord.
- **Native macOS notification** as a lightweight backup signal.
- **State persistence** across reboots via `launchd`.

## Files

| Path | Purpose |
| --- | --- |
| `~/.pr-watcher/config.json` | List of watched PR URLs |
| `~/.pr-watcher/state.json` | Last seen state per URL |
| `~/.pr-watcher/logs/pr-watcher.log` | Poll history |
| `~/Library/Application Support/SwiftBar/Plugins/pr-watcher.5m.sh` | Menu bar plugin |
| `~/Library/LaunchAgents/com.prwatcher.plist` | Hourly polling job |

## Uninstall

```bash
brew uninstall pr-watcher
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.prwatcher.plist
rm ~/Library/LaunchAgents/com.prwatcher.plist
rm ~/Library/Application\ Support/SwiftBar/Plugins/pr-watcher.5m.sh
rm -rf ~/.pr-watcher
```

## License

MIT
