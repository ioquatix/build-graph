#!/usr/bin/env ruby

$LOAD_PATH.unshift File.expand_path('../../../lib', __dir__)

require_relative 'process_graph'

include ProcessGraph

program_root = Path.join(__dir__, "program")
code_glob = Glob.new(program_root, "*.cpp")
program_path = Path.join(program_root, "dictionary-sort")

group = Process::Group.new
logger = Logger.new($stderr)
walker = Walker.for(ProcessTask, group)

top = ProcessNode.top code_glob do
	process code_glob, program_path do
		object_files = inputs.with(extension: ".o") do |input_path, output_path|
			depfile_path = input_path + ".d"
			
			dependencies = Paths.new(input_path)
			
			if File.exist? depfile_path
				depfile = Build::Makefile.load_file(depfile_path)
				
				dependencies = depfile[output_path] || dependencies
			end
			
			process dependencies, output_path do
				run("clang++", "-MMD", "-O3",
					"-o", output_path.shortest_path(input_path.root),
					"-c", input_path.relative_path, "-std=c++11",
					chdir: input_path.root
				)
			end
		end
		
		process object_files, program_path do
			run("clang++", "-O3", "-o", program_path, *object_files.to_a, "-lm", "-pthread")
		end
	end
	
	process program_path do
		run("./" + program_path.relative_path, chdir: program_path.root)
	end
end

interrupted = false

trap(:INT) do
	exit(0)
end

walker.run do
	walker.update(top)
	group.wait
end
