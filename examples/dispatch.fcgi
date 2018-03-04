#! /usr/bin/env ruby

$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__) + "/../lib")
require "grack/app"
require "grack/git_adapter"

config = {
  root: "/opt",
  allow_pull: true,
  allow_push: false,
}
Rack::Handler::FastCGI.run(Grack::App.new(config))
