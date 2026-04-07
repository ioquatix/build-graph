# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "sus/shared"
require "build/files"
require "sus/fixtures/temporary_directory_context"

module Build
	module Graph
		# Scratch directory used by clone integration tests.
		# The test deletes and recreates this directory during the run.
		ProgramContext = Sus::Shared("program context") do
			include Sus::Fixtures::TemporaryDirectoryContext
			
			let(:program_root) {::Build::Files::Path.new(File.expand_path("program", root))}
			
			before do
				FileUtils.cp_r File.join(__dir__, "program"), program_root.to_s
			end
		end
	end
end
