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
  spec.description   = <<-END
helps manage state on OSX by wrapping system commands like `defaults`, `nvram`,
`lanuchctl`, `scutil` and more.
END
  spec.homepage      = "https://github.com/nrser/state_mate"
  spec.license       = "MIT"
  
  spec.required_ruby_version = '>= 2.3.0'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "yard"
  spec.add_development_dependency "redcarpet"

  spec.add_dependency 'nrser', '~> 0.3.1'
  spec.add_dependency 'CFPropertyList', '~> 2.3'
  spec.add_dependency "cmds", '~> 0.2.7'
  spec.add_dependency 'diffable_yaml', '~> 0.0', '>= 0.0.2'
end
