require "pathname"
require "simplecov"
require "tmpdir"
require "coveralls"

Coveralls.wear!

SimpleCov.start do
  add_filter "tests/"
end

$LOAD_PATH << File.expand_path("../../lib", __FILE__)

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
