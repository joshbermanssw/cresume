class Cresume < Formula
  desc "Cross-directory session resume picker for Claude Code"
  homepage "https://github.com/joshbermanssw/cresume"
  url "https://github.com/joshbermanssw/cresume/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "65079592374c92767def0e33da68f9002f486fdfaa3df6a3066add9fbc910a66"
  license "MIT"

  depends_on "fzf"
  depends_on "jq"

  def install
    (prefix/"share/cresume").install "cresume.sh"
  end

  def caveats
    <<~EOS
      Add the following to your shell configuration (~/.zshrc or ~/.bashrc):

        [ -f "#{opt_prefix}/share/cresume/cresume.sh" ] && source "#{opt_prefix}/share/cresume/cresume.sh"

      Then restart your terminal or run:
        source ~/.zshrc
    EOS
  end

  test do
    assert_match "cresume()", shell_output("cat #{prefix}/share/cresume/cresume.sh")
  end
end
