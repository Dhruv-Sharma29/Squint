class Squint < Formula
  desc "Screen OCR for code that keeps indentation, blank lines and brackets"
  homepage "https://github.com/Dhruv-Sharma29/Squint"
  url "https://github.com/Dhruv-Sharma29/Squint/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "REPLACE_WITH_SHA256_OF_THE_RELEASE_TARBALL"
  license "MIT"
  head "https://github.com/Dhruv-Sharma29/Squint.git", branch: "main"

  depends_on macos: :sonoma
  uses_from_macos "swift" => :build

  # Built from source: a locally built app is not quarantined, so no Developer ID or notarization is needed.
  def install
    system "./bundle.sh", "--disable-sandbox"
    prefix.install "build/Squint.app"
    bin.install_symlink prefix/"Squint.app/Contents/MacOS/Squint" => "squint"
  end

  def caveats
    <<~EOS
      Start Squint now and at every login:
        brew services start squint
      Or open it once:
        open #{opt_prefix}/Squint.app

      The first capture asks for Screen Recording permission
      (System Settings > Privacy & Security > Screen Recording).
    EOS
  end

  service do
    run opt_prefix/"Squint.app/Contents/MacOS/Squint"
  end

  test do
    assert_match "usage: squint", shell_output("#{bin}/squint --help")
    assert_match "CER", shell_output("#{bin}/squint eval #{testpath}")
  end
end
