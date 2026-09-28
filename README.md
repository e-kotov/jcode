# jcode — stripped macOS arm64 and Linux x86_64 builds

> **Unofficial.** This repository republishes releases of
> [1jehuang/jcode](https://github.com/1jehuang/jcode) for **macOS arm64 and
> Linux x86_64**, with a few behaviours removed. It is not affiliated
> with or endorsed by the upstream project. Report bugs in jcode itself upstream,
> and bugs in this build (patches, installer, release workflow) here.

## What is changed

Each release here is the upstream release of the same version, built from the
upstream tag with the patches in [`patches/`](patches/). The changes are
hardcoded, so no config setting or environment variable is needed:

| Patch | Effect |
|---|---|
| [`0001-telemetry-off`](patches/0001-telemetry-off.patch) | Usage telemetry is permanently off. Nothing is sent to `telemetry.jcode.sh`: no events, transcripts, `/feedback` or `maintainer_feedback` reports. `jcode telemetry enable` does nothing. |
| [`0002-update-from-fork`](patches/0002-update-from-fork.patch) | The built-in updater checks and downloads **only from this repository's releases**, with SHA-256 verification. The `main` update channel, which builds from upstream source, falls back to stable releases. |
| [`0003-no-macos-extras`](patches/0003-no-macos-extras.patch) | On macOS: no `~/.jcode/notifications/macos/Jcode Notifications.app`, no `~/Library/LaunchAgents/com.jcode.hotkey.plist` hotkey daemon, no auto-started menu bar helper, and no terminal-switching nudges. A hotkey LaunchAgent left by an upstream install is removed on the next launch. `jcode setup-hotkey` and `jcode setup-launcher` report that they are disabled. Turn notifications still work through the terminal or `osascript`. |
| [`0004-discovery-off`](patches/0004-discovery-off.patch) | The sponsored integration-discovery tool (`discover_tools`, `api.jcode.sh`) is never registered or contacted, whatever `[sponsors]` says in the config. |
| [`0005-no-background-key-probes`](patches/0005-no-background-key-probes.patch) | No background sweep that calls `/models` on every provider whose key is in the environment. MiniMax never falls back to `OPENAI_API_KEY`, which often holds another provider's key. The provider you actually use still refreshes its own model list. |

The installer ([`install.sh`](install.sh)) is also stripped down. It sends no
telemetry, uses no `jcode.sh` mirrors and does not edit shell rc files. It does
not install a notification helper or a hotkey. The Linux archive retains its
launcher, binary and required shared libraries together.

Anything you enable yourself still works, such as provider logins, MCP servers,
`jcode account` and cloud features. Those contact the services you configure.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/e-kotov/jcode/ek/install.sh | bash
```

This installs the platform build to `~/.jcode/builds/versions/<version>/jcode` and links
it through `~/.jcode/builds/stable/jcode` to `~/.local/bin/jcode`. This is the
same layout the updater uses. If `~/.local/bin` is not on your `PATH`, the
installer tells you. It does not change your shell config.

If you already have an upstream install, run the same command. It replaces the
binary in place, and your config, sessions and logins in `~/.jcode` are kept.

Pin a version with `JCODE_VERSION=v0.89.0`. Disable automatic updates with
`JCODE_NO_AUTO_UPDATE=1`.

## Uninstall

```sh
rm -f ~/.local/bin/jcode
rm -rf ~/.jcode/builds
# Optional: also remove config, sessions and credentials
rm -rf ~/.jcode
```

## How releases track upstream

A [daily workflow](.github/workflows/sync-release.yml) checks for the latest
upstream release. When it finds a new one, it checks out that tag, applies the
patches and builds on GitHub macOS arm64 and Linux x86_64 runners. The Linux
build uses upstream's manylinux2014 recipe for a glibc 2.17 baseline. It then
publishes `jcode-macos-aarch64.tar.gz`, `jcode-linux-x86_64.tar.gz` and a
combined `SHA256SUMS` under **the same tag** (for example `v0.89.0`). jcode's
updater only understands plain `vX.Y.Z` versions, so tags carry no suffix.
[`UPSTREAM_RELEASE`](UPSTREAM_RELEASE) records the last
upstream version built.

When a patch no longer applies to a new upstream release, the workflow fails
and no release is published until the patch is updated. Installs stay on the
previous version in the meantime.

The default branch `ek` holds only these files. Upstream history is never
merged here, so upstream's own workflows never run in this repository.

## License

jcode is © 2025 Jeremy Huang and released under the [MIT License](LICENSE).
This repository redistributes builds of it under the same license. The patches,
installer and workflow here are also MIT-licensed. All credit for jcode goes to
its upstream author.
