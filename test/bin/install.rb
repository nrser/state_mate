#!/usr/bin/env ruby

# build and install gem from current source

require 'pathname'
require 'fileutils'
require 'cmds'

sudo = Cmds("rbenv version").out.start_with?("system") ? 'sudo' : nil

ROOT = Pathname.new(__FILE__).dirname.join("..", "..").expand_path

Cmds.stream "%{sudo?} gem uninstall -a state_mate", sudo: sudo

Dir.chdir ROOT do
  Dir["./*.gem"].each {|fn| FileUtils.rm fn}
  Cmds.stream "gem build state_mate.gemspec"
end

Cmds.stream "%{sudo?} gem install %{path}",
  path: Dir[ROOT + "*.gem"].first,
  sudo: sudo
