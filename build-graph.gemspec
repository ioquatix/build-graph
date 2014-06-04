# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'build/graph/version'

Gem::Specification.new do |spec|
	spec.name          = "build-graph"
	spec.version       = Build::Graph::VERSION
	spec.authors       = ["Samuel Williams"]
	spec.email         = ["samuel.williams@oriontransfer.co.nz"]
	spec.summary       = %q{Build::Graph is a framework for build systems, with specific functionality for dealing with file based processes.}
	spec.description   = <<-EOF
	Build::Graph is a framework for managing file-system based build processes. It provides graph based build functionality which monitors the file-system for changes. Because of this, it can efficiently manage large and complex process based builds.
	EOF
	spec.homepage      = ""
	spec.license       = "MIT"

	spec.files         = `git ls-files`.split($/)
	spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
	spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
	spec.require_paths = ["lib"]

	spec.add_dependency "process-group", "~> 0.2.1"
	spec.add_dependency "build-files", "~> 0.2.0"
	
	spec.add_dependency "system"
	spec.add_dependency "rainbow", "~> 2.0.0"

	spec.add_development_dependency "bundler", "~> 1.3"
	spec.add_development_dependency "rspec", "~> 3.0.0"
	spec.add_development_dependency "build-makefile", "~> 0.2.0"
	spec.add_development_dependency "rake"
end
