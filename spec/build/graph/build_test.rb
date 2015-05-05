#!/usr/bin/env ruby

$LOAD_PATH.unshift File.expand_path('../../../lib', __dir__)

require 'graphviz'
require_relative 'process_graph'

include ProcessGraph

program_root = Path.join(__dir__, "program")
code_glob = Glob.new(program_root, "*.cpp")
program_path = Path.join(program_root, "dictionary-sort")

group = Process::Group.new
logger = Logger.new($stderr)
walker = Walker.for(ProcessTask, group)

top = ProcessNode.top code_glob, title: 'top' do
	process code_glob, program_path, title: 'build' do
		object_files = inputs.with(extension: ".o") do |input_path, output_path|
			depfile_path = input_path + ".d"
			
			dependencies = Paths.new(input_path)
			
			if File.exist? depfile_path
				depfile = Build::Makefile.load_file(depfile_path)
				
				dependencies = depfile[output_path] || dependencies
			end
			
			process dependencies, output_path, title: 'compile' do
				run("clang++", "-MMD", "-O3",
					"-o", output_path.shortest_path(input_path.root),
					"-c", input_path.relative_path, "-std=c++11",
					chdir: input_path.root
				)
			end
		end
		
		process object_files, program_path, title: 'link' do
			run("clang++", "-O3", "-o", program_path, *object_files.to_a, "-lm", "-pthread")
		end
	end
	
	process program_path, title: 'run' do
		run("./" + program_path.relative_path, chdir: program_path.root)
	end
end

interrupted = false

trap(:INT) do
	exit(0)
end

viz = Graphviz::Graph.new
viz.attributes[:rankdir] = 'LR'

walker.run do
	walker.update(top)
	group.wait
	
	walker.tasks.each do |node, task|
		input_nodes = []
		output_nodes = []
		
		task.inputs.each do |path|
			input_nodes << viz.add_node(path.basename)
		end
		
		task.outputs.each do |path|
			output_nodes << viz.add_node(path.basename)
		end
		
		if output_nodes.size == 1
			input_nodes.each do |input_node|
				edge = input_node.connect(output_nodes.first)
				edge.attributes[:label] = node.title
			end
		end
	end
	
	File.write('graph.dot', viz.to_dot)
	`dot -Tpdf graph.dot > graph.pdf && open graph.pdf`
end
