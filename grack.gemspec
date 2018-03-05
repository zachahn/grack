Gem::Specification.new do |s|
  s.name = "grack"
  s.version = "0.1.0"
  s.platform = Gem::Platform::RUBY
  s.authors = ["Scott Chacon", "Dawa Ometto", "Jeremy Bopp"]
  s.email =
    ["schacon@gmail.com", "d.ometto@gmail.com", "jeremy@bopp.net"]
  s.homepage = "https://github.com/grackorg/grack"
  s.license = "MIT"
  s.summary =
    "This project aims to replace the builtin git-http-backend CGI handler " \
    "distributed with C Git with a Rack application."
  s.description =
    "This project aims to replace the builtin git-http-backend CGI handler " \
    "distributed with C Git with a Rack application. By default, Grack uses " \
    "calls to git on the system to implement Smart HTTP. Since the " \
    "git-http-backend is really just a simple wrapper for the upload-pack " \
    "and receive-pack processes with the '--stateless-rpc' option, this does " \
    "not actually re-implement very much. However, it is possible to use a " \
    "different backend by specifying a different Adapter."

  s.add_dependency("rack")

  s.add_development_dependency("rake", "~> 10.1", ">= 10.1.1")
  s.add_development_dependency("rack-test", "~> 0.6", ">= 0.6.3")
  s.add_development_dependency("minitest", "~> 5.8", ">= 5.8.0")
  s.add_development_dependency("mocha", "~> 1.1", ">= 1.1.0")
  s.add_development_dependency("yard", "~> 0.8.7", ">= 0.8.7.3")
  s.add_development_dependency("redcarpet", "~> 3.1", ">= 3.1.0")
  s.add_development_dependency("github-markup", "~> 1.0", ">= 1.0.2")
  s.add_development_dependency("pry", "~> 0")
  s.add_development_dependency("rubocop")
  s.add_development_dependency("the_bath_of_zahn")

  # Explicitly list all non-test files that should be included into the gem
  # here.  This and the test_files list will be compared against an
  # automatically generated list by rake to identify files potentially missed by
  # inclusion or exclusion rules.
  s.files = %w[
    .travis.yml
    .yardopts
    LICENSE
    NEWS.md
    README.md
    Rakefile
    lib/git_adapter.rb
    lib/grack.rb
    lib/grack/app.rb
    lib/grack/file_streamer.rb
    lib/grack/git_adapter.rb
    lib/grack/io_streamer.rb
  ]
  # Explicitly list all test files that should be included into the gem here.
  s.test_files = %w[
    test/app_test.rb
    test/example/_git/COMMIT_EDITMSG
    test/example/_git/HEAD
    test/example/_git/config
    test/example/_git/description
    test/example/_git/hooks/applypatch-msg.sample
    test/example/_git/hooks/commit-msg.sample
    test/example/_git/hooks/post-commit.sample
    test/example/_git/hooks/post-receive.sample
    test/example/_git/hooks/post-update.sample
    test/example/_git/hooks/pre-applypatch.sample
    test/example/_git/hooks/pre-commit.sample
    test/example/_git/hooks/pre-rebase.sample
    test/example/_git/hooks/prepare-commit-msg.sample
    test/example/_git/hooks/update.sample
    test/example/_git/index
    test/example/_git/info/exclude
    test/example/_git/info/refs
    test/example/_git/logs/HEAD
    test/example/_git/logs/refs/heads/master
    test/example/_git/objects/31/d73eb4914a8ddb6cb0e4adf250777161118f90
    test/example/_git/objects/cb/067e06bdf6e34d4abebf6cf2de85d65a52c65e
    test/example/_git/objects/ce/013625030ba8dba906f756967f9e9ca394464a
    test/example/_git/objects/info/packs
    test/example/_git/objects/pack/pack-62c9f443d8405cd6da92dcbb4f849cc01a339c06.idx
    test/example/_git/objects/pack/pack-62c9f443d8405cd6da92dcbb4f849cc01a339c06.pack
    test/example/_git/refs/heads/master
    test/file_streamer_test.rb
    test/git_adapter_test.rb
    test/io_streamer_test.rb
    test/test_helper.rb
  ]
end
