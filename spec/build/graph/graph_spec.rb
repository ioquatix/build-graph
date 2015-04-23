#!/usr/bin/env rspec
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

require 'build/graph/walker'
require 'build/makefile'

require 'process/group'
require 'fileutils'

module Build::Graph::GraphSpec
	include Build::Graph
	include Build::Files
	
	class ProcessNode < Node
		def initialize(inputs, outputs, block)
			super(inputs, outputs, block.source_location)
			
			@block = block
		end
		
		def evaluate(context)
			context.instance_eval(&@block)
		end
	end
	
	class ProcessTask < Task
		def process(inputs, outputs = :inherit, &block)
			inputs = Build::Files::List.coerce(inputs)
			outputs = Build::Files::List.coerce(outputs) unless outputs.kind_of? Symbol
			
			node = ProcessNode.new(inputs, outputs, block)
			
			self.invoke(node)
		end
		
		def wet?
			@group != nil
		end
		
		def run(*arguments)
			if wet?
				puts "\t[run] #{arguments.join(' ')}"
				status = @group.spawn(*arguments)
				
				if status != 0
					raise CommandError.new(status)
				end
			end
		end
		
		def fs
			if wet?
				FileUtils::Verbose
			else
				FileUtils::Verbose::Dry
			end
		end
		
		# This function is called to finish the invocation of the task within the graph.
		# There are two possible ways this function can generally proceed.
		# 1/ The node this task is running for is clean, and thus no actual processing needs to take place, but children should probably be executed.
		# 2/ The node this task is running for is dirty, and the execution of commands should work as expected.
		def update(group = nil)
			@group = group if @node.dirty?
			
			@node.evaluate(self)
		end
	end
	
	describe Build::Graph do
		it "shouldn't update mtime" do
			test_glob = Glob.new(__dir__, "*.rb")
			listing_output = Paths.directory(__dir__, ["listing.txt"])
			
			FileUtils.rm_f listing_output.to_a
			
			group = Process::Group.new
			
			walker = Walker.new do |walker, node|
				task = ProcessTask.new(walker, node)
				
				task.visit do
					task.update(group)
				end
			end
			
			top = ProcessNode.top do
				process test_glob, listing_output do
					run("ls", "-la", *inputs, :out => outputs.first.for_writing)
				end
			end
			
			walker.update(top)
			group.wait
			
			first_modified_time = listing_output.first.modified_time
			
			walker.update(top)
			group.wait
			
			# The output file shouldn't have been changed because already exists and the input files haven't changed either:
			second_modified_time = listing_output.first.modified_time
			
			# The granularity of mtime on some systems is a bit weird:
			expect(second_modified_time.to_f).to be_within(0.001).of(first_modified_time.to_f)
			
			FileUtils.rm_f listing_output.to_a
			walker.monitor.update(listing_output.roots)
			
			# The granularity of modification times isn't that great, so we use >= below.
			# sleep 1
			
			walker.update(top)
			group.wait
			
			expect(listing_output.first.modified_time).to be >= first_modified_time
			
			FileUtils.rm_f listing_output.to_a
		end
		
		it "should compile program and respond to changes in source code" do
			program_root = Path.join(__dir__, "program")
			code_glob = Glob.new(program_root, "*.cpp")
			program_path = Path.join(program_root, "dictionary-sort")
			
			group = Process::Group.new
			
			walker = Walker.new do |walker, node|
				task = ProcessTask.new(walker, node)
				
				task.visit do
					task.update(group)
				end
			end
			
			#FileUtils.touch(code_glob.first)
			
			top = ProcessNode.top do
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
			
			walker.update(top)
			group.wait
			
			expect(program_path).to be_exist
			expect(code_glob.first.modified_time).to be <= program_path.modified_time
		end
		
		it "should copy files incrementally" do
			program_root = Path.join(__dir__, "program")
			files = Glob.new(program_root, "*.cpp")
			destination = Path.new(__dir__) + "tmp"
			
			group = Process::Group.new
			
			walker = Walker.new(logger: Logger.new($stderr)) do |walker, node|
				task = ProcessTask.new(walker, node)
				
				task.visit do
					task.update(group)
				end
			end
			
			#FileUtils.touch(code_glob.first)
			
			top = ProcessNode.top files do
				fs.mkpath destination
				
				inputs.each do |source_path|
					destination_path = source_path.rebase(destination)
					
					process source_path, destination_path do
						fs.install inputs.first, outputs.first
					end
				end
			end
			
			trashed_files = false
			
			thread = Thread.new do
				sleep 0.1
				
				destination.glob("*.cpp").each{|path| path.delete}
				
				trashed_files = true
			end
			
			walker.run do
				walker.update(top)
				group.wait
				
				break if trashed_files
			end
			
			thread.join
			
			expect(destination).to be_exist
			expect(destination.glob("*.cpp").count).to be == 2
			
			destination.delete
		end
	end
end
