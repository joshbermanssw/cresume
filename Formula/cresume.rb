class Cresume < Formula
  desc "Cross-directory session resume picker for Claude Code"
  homepage "https://github.com/joshbermanssw/cresume"
  url "https://github.com/joshbermanssw/cresume/archive/refs/tags/v0.2.5.tar.gz"
  sha256 "7baedc57424fe097a3ffd5179d03de2426b61078b15ba41e75a42321858b6a55"
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
