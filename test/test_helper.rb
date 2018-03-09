$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "grack"

require "fileutils"
require "minitest/autorun"
require "mocha/setup"
require "stringio"
require "pathname"
require "tmpdir"

require "digest/sha1"
require "rack/test"
require "tempfile"
require "zlib"

require "pry"

class Minitest::Test
  def git_path
    ENV.fetch("GIT_PATH", "git") # Path to git on test system
  end

  def stock_repo
    File.expand_path("../example/_git", __FILE__)
  end

  attr_reader :repositories_root

  attr_reader :example_repo

  def init_example_repository
    @repositories_root = Pathname.new(Dir.mktmpdir("grack-testing"))
    @example_repo = @repositories_root + "example_repo.git"

    FileUtils.cp_r(stock_repo, example_repo)
  end

  def remove_example_repository
    FileUtils.remove_entry_secure(repositories_root)
  end
end
