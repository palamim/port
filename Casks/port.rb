cask "port" do
  version "0.2.0"
  # Placeholder -- .github/workflows/release.yml overwrites this with the
  # real digest of Port.zip on every tagged release.
  sha256 "7c04ccc399bb13187f4ef735a5cd46c1a6a470ec90a7bf5a87fc7b42c099548e"

  url "https://github.com/palamim/port/releases/download/v#{version}/Port.zip"
  name "Port"
  desc "Read-only panel showing live Claude Code agent session state" # Cask desc must not include the platform.
  homepage "https://github.com/palamim/port"

  livecheck do
    url :url
    strategy :github_latest
  end

  # Bare symbol means ">= this release". Package.swift pins .macOS(.v13).
  depends_on macos: :ventura

  app "Port.app"

  uninstall quit: "com.port.app"

  zap trash: "~/Library/Logs/Port.log"

  caveats <<~EOS
    Port is ad-hoc signed but not notarized, so macOS blocks the first
    launch. To approve it:

      1. Open Port and click Done on the block dialog.
      2. System Settings -> Privacy & Security -> Open Anyway (next to the
         Port entry), then confirm and enter your password.

    That's the only approval Port asks for -- it requests no other system
    permission, on first launch or on any later upgrade.

    To start Port at login, add it under System Settings -> General ->
    Login Items & Extensions.
  EOS
end
