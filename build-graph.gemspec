# frozen_string_literal: true

require_relative "lib/build/graph/version"

Gem::Specification.new do |spec|
	spec.name = "build-graph"
	spec.version = Build::Graph::VERSION
	
	spec.summary = "Build::Graph is a framework for build systems, with specific functionality for dealing with file based processes."
	spec.authors = ["Samuel Williams"]
	spec.license = "MIT"
	
	spec.cert_chain  = ['release.cert']
	spec.signing_key = File.expand_path('~/.gem/release.pem')
	
	spec.files = Dir.glob('{lib,spec}/**/*', File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 2.0"
	
	spec.add_dependency "build-files", "~> 1.8"
	spec.add_dependency "build-files-monitor", "~> 0.2"
	spec.add_dependency "console", "~> 1.1"
	spec.add_dependency "process-group", "~> 1.1"
	
	spec.add_development_dependency "build-makefile", "~> 1.0"
	spec.add_development_dependency "bundler"
	spec.add_development_dependency "covered"
	spec.add_development_dependency "rake"
	spec.add_development_dependency "rspec", "~> 3.4"
end
