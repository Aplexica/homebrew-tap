class Aplexica < Formula
  desc "Cross-agent state portability for AI coding agents"
  homepage "https://aplexica.com"
  url "https://github.com/Aplexica/Aplexica.git",
      revision: "5b3df06f6e0c143329929bf9b03efbe4f9c32c0a"
  version "1.0.2"
  license "AGPL-3.0-or-later"
  head "https://github.com/Aplexica/Aplexica.git", branch: "main"

  depends_on "go" => :build
  depends_on "node" => :build
  depends_on "pnpm" => :build

  # aplexica-portal is versioned independently (v0.1.x), not in lockstep with
  # the daemon. The v1.0.1 daemon release embedded the latest portal available
  # at build time: v0.1.10.
  resource "portal" do
    url "https://github.com/Aplexica/aplexica-portal.git",
        revision: "d0d0d62c795fa2a008874917f346697b5c1d91d1"
  end

  def install
    portal_dest = buildpath/"internal/web/embed/dist-local"

    resource("portal").stage do
      system "pnpm", "install", "--frozen-lockfile"
      system "pnpm", "build:local"

      dist_local = Pathname.pwd/"dist-local"
      odie "portal build did not create #{dist_local}" unless dist_local.directory?

      rm_r portal_dest if portal_dest.exist?
      mkdir_p portal_dest
      cp_r dist_local.children, portal_dest
    end

    ldflags = %W[
      -s -w
      -X github.com/aplexica/aplexica/internal/version.Version=v#{version}
      -X github.com/aplexica/aplexica/internal/version.GitCommit=5b3df06f6e0c143329929bf9b03efbe4f9c32c0a
      -X github.com/aplexica/aplexica/internal/version.BuildDate=2026-07-10T13:46:56-04:00
    ].join(" ")

    system "go", "build", "-tags", "release", "-trimpath", "-ldflags", ldflags,
           "-o", bin/"aplexica", "./cmd/aplexica"
    system "go", "build", "-tags", "release", "-trimpath", "-ldflags", ldflags,
           "-o", bin/"aplexica-status", "./cmd/aplexica"

    # Tray indicator — now built on Linux too, not just macOS. The systray
    # library (fyne.io/systray) uses Cocoa on macOS and pure-Go DBus
    # (StatusNotifierItem) on Linux, so the Linux build needs no GTK /
    # AppIndicator dev libraries and no cgo — just `-tags tray`.
    system "go", "build", "-tags", "tray", "-trimpath", "-ldflags", ldflags,
           "-o", bin/"aplexicatray", "./cmd/aplexicatray"
  end

  def caveats
    <<~EOS
      Aplexica installs three binaries:
        aplexica        - CLI + daemon (binds 127.0.0.1 only; no LAN listener)
        aplexica-status - tray status watcher helper
        aplexicatray    - system-tray indicator

      One-time setup — configure and start the daemon + tray (no sudo needed):
        aplexica setup --yes --install

      That installs the per-user service (systemd --user on Linux, launchd on
      macOS) and the tray autostart entry, then starts them; both come back
      automatically at each login. This is a separate step because Homebrew
      runs post_install in a sandbox with a temporary HOME, so autostart can't
      be wired during `brew install` itself.

      Open the local web UI from the tray (Open Aplexica), or run:
        aplexica web open

      User data lives in ~/.aplexica/. Logs at ~/.aplexica/logs/.
    EOS
  end

  test do
    output = shell_output("#{bin}/aplexica --version")
    assert_match "v#{version}", output
  end
end
