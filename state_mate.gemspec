# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'state_mate/version'

Gem::Specification.new do |spec|
  spec.name          = "state_mate"
  spec.version       = StateMate::VERSION
  spec.authors       = ["nrser"]
  spec.email         = ["neil@ztkae.com"]
  spec.summary       = %q{i heard it's meant to help you with your state, mate!}
  spec.homepage      = "https://github.com/nrser/state_mate"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_dependency 'nrser', '0.0.10'
  spec.add_dependency 'CFPropertyList', '~> 2.3'
end
