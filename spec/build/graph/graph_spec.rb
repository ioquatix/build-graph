# Copyright, 2012, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'build/graph'
require 'build/files'
require 'build/makefile'

require 'process/group'
require 'fileutils'
require 'rainbow'

module Build::Graph::GraphSpec
	# The graph node is created once, so a graph has a fixed number of nodes, which store per-vertex state and connectivity.
	class Node < Build::Node
		include Build::Files
		
		def initialize(graph, inputs = Paths::NONE, outputs = Paths::NONE, &update)
			@update = update
			
			super(graph, inputs, outputs)
		end
		
		def apply!(scope)
			scope.instance_eval(&@update)
		end
		
		# This ensures that enclosed nodes are run if they are dirty. The top level node has no inputs or outputs by default, so children who become dirty wouldn't mark it as dirty and thus wouldn't be run.
		def requires_update?
			if outputs.count == 0
				return true
			else
				super
			end
		end
	end
	
	# The task is the context in which a vertex is updated. Because nodes may initially create other nodes, it is also responsible for looking up and creating new nodes.
	class Task < Build::Graph::Task
		include Build::Files
		
		def initialize(graph, walker, node, group = nil)
			super(graph, walker, node)
			
			@group = group
		end
		
		def wet?
			@group and @node.dirty?
		end
		
		def process(inputs, outputs, &block)
			inputs = Build::Files::List.coerce(inputs)
			outputs = Build::Files::List.coerce(outputs)
			
			child_node = @graph.nodes.fetch([inputs, outputs]) do |key|
				@graph.nodes[key] = Node.new(@graph, inputs, outputs, &block)
			end
			
			@children << child_node
			
			# State saved in update!
			child_node.update!(@walker)
			
			return child_node
		end
		
		def run(*arguments)
			if wet?
				puts Rainbow("Wet because : #{@node.state.inspect}").blue
				puts arguments.join(" ")
				
				status = @group.spawn(*arguments)
				
				if status != 0
					raise RuntimeError.new(status)
				end
			end
		end
		
		def visit
			super do
				@node.apply!(self)
			end
		end
	end
	
	class Controller < Build::Graph::Controller
		def initialize(&block)
			@top = Node.new(self, &block)
			
			super()
		end
		
		attr_accessor :top
		
		def traverse!(walker)
			@top.update!(walker)
		end
		
		def build_graph!
			super do |walker, node|
				Task.new(self, walker, node)
			end
		end
		
		def update!
			group = Process::Group.new
			
			super do |walker, node|
				Task.new(self, walker, node, group)
			end
			
			group.wait
		end
	end
	
	include Build::Files
	
	describe Build::Graph do
		it "shouldn't update mtime" do
			test_glob = Glob.new(__dir__, "*.rb")
			output_paths = Paths.directory(__dir__, ["listing.txt"])
			
			FileUtils.rm_f output_paths.to_a
			
			node = nil
			
			controller = Controller.new do
				node = process test_glob, output_paths do
					run("ls", "-la", *test_glob, :out => output_paths.first.for_writing)
				end
			end
			
			expect(node).to_not be nil
			
			controller.update!
			
			mtime = File.mtime(output_paths.first)
			
			# Ensure the mtime will change even if the granularity of the filesystem is 1 second:
			sleep(1)
			
			controller.update!
			
			# The output file shouldn't have been changed because already exists and the input files haven't changed either:
			expect(File.mtime(output_paths.first)).to be == mtime
			
			FileUtils.rm_f output_paths.to_a
		end
		
		it "should compile program and respond to changes in source code" do
			program_root = File.join(__dir__, "program")
			code_glob = Glob.new(program_root, "*.cpp")
			program_path = Path.join(program_root, "dictionary-sort")
		
			# FileUtils.touch(code_glob.first)
		
			controller = Controller.new do
				process code_glob, program_path do
					object_files = inputs.with(extension: ".o") do |input_path, output_path|
						depfile_path = input_path + ".d"
					
						dependencies = Paths.new(input_path)
					
						if File.exist? depfile_path
							depfile = Build::Makefile.load_file(depfile_path)
							
							dependencies = depfile[output_path] || dependencies
						end
					
						process dependencies, output_path do
							# puts "Dependencies for #{output_path.relative_path}: #{dependencies.to_a.inspect}" if wet?
						
							run("clang++", "-MMD", "-O3", "-o", output_path.relative_path, "-c", input_path.relative_path, "-std=c++11", chdir: input_path.root)
						end
					end
				
					process object_files, program_path do
						run("clang++", "-O3", "-o", program_path, *object_files.to_a, "-lm", "-pthread")
					end
				end
			
				process program_path, Paths::NONE do
					run("./" + program_path.relative_path, chdir: program_path.root)
				end
			end
			
			controller.update!
			
			expect(File.exist?(program_path)).to be true
			expect(File.mtime(code_glob.first)).to be <= File.mtime(program_path)
		end
	end
end
