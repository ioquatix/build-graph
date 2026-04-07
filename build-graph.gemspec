# frozen_string_literal: true

require_relative "lib/build/graph/version"

Gem::Specification.new do |spec|
	spec.name = "build-graph"
	spec.version = Build::Graph::VERSION
	
	spec.summary = "Build::Graph is a framework for build systems, with specific functionality for dealing with file based processes."
	spec.authors = ["Samuel Williams"]
	spec.license = "MIT"
	
	spec.cert_chain  = ["release.cert"]
	spec.signing_key = File.expand_path("~/.gem/release.pem")
	
	spec.metadata = {
		"documentation_uri" => "https://ioquatix.github.io/build-graph",
		"funding_uri" => "https://github.com/sponsors/ioquatix",
		"source_code_uri" => "https://github.com/ioquatix/build-graph.git",
	}
	
	spec.files = Dir.glob(["{context,lib}/**/*", "*.md"], File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 3.2"
	
	spec.add_dependency "build-files", "~> 1.8"
	spec.add_dependency "build-files-monitor", "~> 0.4"
	spec.add_dependency "console", "~> 1.1"
end
