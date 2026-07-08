class Aplexica < Formula
  desc "Cross-agent state portability for AI coding agents"
  homepage "https://aplexica.com"
  url "https://github.com/Aplexica/Aplexica.git",
      revision: "52bcf4fe1d9528da469c1c1f826c13b600d780ae"
  version "1.0.0"
  license "AGPL-3.0-or-later"
  head "https://github.com/Aplexica/Aplexica.git", branch: "main"

  depends_on "go" => :build
  depends_on "node" => :build
  depends_on "pnpm" => :build

  resource "portal" do
    url "https://github.com/Aplexica/aplexica-portal.git",
        revision: "4605b7a021b843706df4a0ec173c3f8d8a221c57"
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
      -X github.com/aplexica/aplexica/internal/version.GitCommit=52bcf4fe1d9528da469c1c1f826c13b600d780ae
      -X github.com/aplexica/aplexica/internal/version.BuildDate=2026-07-06T23:06:51-04:00
    ].join(" ")

    system "go", "build", "-tags", "release", "-trimpath", "-ldflags", ldflags,
           "-o", bin/"aplexica", "./cmd/aplexica"
    system "go", "build", "-tags", "release", "-trimpath", "-ldflags", ldflags,
           "-o", bin/"aplexica-status", "./cmd/aplexica"

    if OS.mac?
      system "go", "build", "-tags", "tray", "-trimpath", "-ldflags", ldflags,
             "-o", bin/"aplexicatray", "./cmd/aplexicatray"
    end
  end

  def caveats
    <<~EOS
      Aplexica installs three binaries:
        aplexica        - CLI + daemon (binds 127.0.0.1 only; no LAN listener)
        aplexica-status - tray status watcher helper
        aplexicatray    - system-tray indicator

      To complete setup and start the daemon + tray:
        aplexica setup --yes --install

      The daemon starts the local web UI and launches the tray when Aplexica runs.
      Local web UI: click the tray icon -> Open Aplexica, or run:
        aplexica web open

      User data lives in ~/.aplexica/. Logs at ~/.aplexica/logs/.
    EOS
  end

  test do
    output = shell_output("#{bin}/aplexica --version")
    assert_match "v#{version}", output
  end
end
