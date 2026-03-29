# Homebrew Formula for Tap
# Install with: brew install --tap=keeptahoeblueish/tap keeptahoeblueish/tap/tap
# Or if added to a tap repo: brew install tap

class Tap < Formula
  desc "Claude Command Notification System - macOS menu bar app for permission requests"
  homepage "https://github.com/keeptahoeblueish/Tap"
  url "https://github.com/keeptahoeblueish/Tap/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"

  depends_on xcode: ["15.0", :build]
  depends_on :macos => :sonoma

  def install
    # Build the release version
    system "swift", "build", "-c", "release"

    # Install the binary
    bin.install ".build/release/Tap"

    # Create the menu bar app bundle
    app_path = "#{prefix}/Applications/Tap.app"
    mkdir_p app_path
    mkdir_p "#{app_path}/Contents/MacOS"
    mkdir_p "#{app_path}/Contents/Resources"

    # Copy the executable
    cp ".build/release/Tap", "#{app_path}/Contents/MacOS/Tap"

    # Create Info.plist
    plist_content = <<~PLIST
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>CFBundleDevelopmentRegion</key>
        <string>en</string>
        <key>CFBundleExecutable</key>
        <string>Tap</string>
        <key>CFBundleIdentifier</key>
        <string>com.claude.tap</string>
        <key>CFBundleInfoDictionaryVersion</key>
        <string>6.0</string>
        <key>CFBundleName</key>
        <string>Tap</string>
        <key>CFBundlePackageType</key>
        <string>APPL</string>
        <key>CFBundleShortVersionString</key>
        <string>1.0.0</string>
        <key>CFBundleVersion</key>
        <string>1</string>
        <key>NSMainStoryboardFile</key>
        <string>Main</string>
        <key>NSPrincipalClass</key>
        <string>NSApplication</string>
        <key>NSUserNotificationAlertStyle</key>
        <string>alert</string>
        <key>LSUIElement</key>
        <true/>
      </dict>
      </plist>
    PLIST

    File.write("#{app_path}/Contents/Info.plist", plist_content)

    # Make executable
    chmod 0755, "#{app_path}/Contents/MacOS/Tap"
  end

  def post_install
    puts "Tap installed successfully!"
    puts "To run Tap as a menu bar app, use: open #{prefix}/Applications/Tap.app"
    puts "Or run the binary directly: #{bin}/Tap"
  end

  test do
    # Simple test to verify the binary exists and is executable
    assert_predicate bin/"Tap", :exist?
    assert_predicate bin/"Tap", :executable?
  end
end
