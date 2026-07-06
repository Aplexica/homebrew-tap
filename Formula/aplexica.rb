class Aplexica < Formula
  desc "Cross-agent state portability for AI coding agents"
  homepage "https://aplexica.com"
  url "https://github.com/Aplexica/Aplexica.git",
      tag:      "v0.126.1",
      revision: "d3b6459be1aea24b93a2977bd061db63d13d32e9"
  license "AGPL-3.0-or-later"
  head "https://github.com/Aplexica/Aplexica.git", branch: "main"

  depends_on "go" => :build
  depends_on "node" => :build
  depends_on "pnpm" => :build

  resource "portal" do
    url "https://github.com/Aplexica/aplexica-portal.git", branch: "main"
  end

  def install
    resource("portal").stage buildpath/"portal" do
      system "pnpm", "install", "--frozen-lockfile"
      system "pnpm", "build:local"
    end

    portal_dest = buildpath/"internal/web/embed/dist-local"
    rm_r portal_dest if portal_dest.exist?
    mkdir_p portal_dest
    cp_r (buildpath/"portal/dist-local").children, portal_dest

    ldflags = %W[
      -s -w
      -X github.com/aplexica/aplexica/internal/version.Version=v#{version}
      -X github.com/aplexica/aplexica/internal/version.GitCommit=d3b6459be1aea24b93a2977bd061db63d13d32e9
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
      To complete setup:
        aplexica setup

      User data lives in ~/.aplexica/.
      Open the local web UI from the tray icon or with:
        aplexica web open
    EOS
  end

  test do
    assert_match "v#{version}", shell_output("#{bin}/aplexica --version")
  end
end
