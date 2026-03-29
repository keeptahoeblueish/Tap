cask "tap" do
  version "0.1.0"
  sha256 "PLACEHOLDER" # Updated on each release

  url "https://github.com/keeptahoeblueish/Tap/releases/download/v#{version}/Tap.dmg"
  name "Tap"
  desc "Native Apple notifications for Claude Code"
  homepage "https://github.com/keeptahoeblueish/Tap"

  depends_on macos: ">= :sonoma"

  app "Tap.app"

  postflight do
    system "open", "#{appdir}/Tap.app"
  end

  zap trash: [
    "~/Library/Application Support/Tap",
  ]
end
