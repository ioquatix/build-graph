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

require_relative 'process_graph'

module Build::Graph::GraphSpec
	include ProcessGraph
	
	RSpec.describe Build::Graph do
		let(:group) {Process::Group.new}
		
		let(:logger) {Logger.new($stderr).tap{|logger| logger.level = Logger::DEBUG}}
		
		it "shouldn't update mtime" do
			test_glob = Glob.new(__dir__, "*.rb")
			listing_output = Paths.directory(__dir__, ["listing.txt"])
			
			FileUtils.rm_f listing_output.to_a
			
			walker = Walker.for(ProcessTask, group)
			
			top = ProcessNode.top do
				process test_glob, listing_output do
					run("ls", "-la", *inputs, :out => outputs.first.for_writing)
				end
			end
			
			group.wait do
				walker.update(top)
			end
			
			first_modified_time = listing_output.first.modified_time
			
			group.wait do
				walker.update(top)
			end
			
			# The output file shouldn't have been changed because already exists and the input files haven't changed either:
			second_modified_time = listing_output.first.modified_time
			
			# The granularity of mtime on some systems is a bit weird:
			expect(second_modified_time.to_f).to be_within(0.001).of(first_modified_time.to_f)
			
			FileUtils.rm_f listing_output.to_a
			walker.monitor.update(listing_output.roots)
			
			# The granularity of modification times isn't that great, so we use >= below.
			# sleep 1
			
			group.wait do
				walker.update(top)
			end
			
			expect(listing_output.first.modified_time).to be >= first_modified_time
			
			FileUtils.rm_f listing_output.to_a
		end
		
		it "should compile program and respond to changes in source code" do
			program_root = Path.join(__dir__, "program")
			code_glob = Glob.new(program_root, "*.cpp")
			program_path = Path.join(program_root, "dictionary-sort")
			
			walker = Walker.for(ProcessTask, group)
			
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
			
			group.wait do
				walker.update(top)
			end
			
			expect(program_path).to be_exist
			expect(code_glob.first.modified_time).to be <= program_path.modified_time
		end
		
		it "should copy files incrementally" do
			program_root = Path.join(__dir__, "program")
			files = Glob.new(program_root, "*.cpp")
			destination = Path.new(__dir__) + "tmp"
			
			walker = Walker.for(ProcessTask, group)
			
			top = ProcessNode.top files do
				mkpath destination
				
				inputs.each do |source_path|
					destination_path = source_path.rebase(destination)
					
					process source_path, destination_path do
						$stderr.puts "Copying #{inputs.first} -> #{outputs.first}"
						install inputs.first, outputs.first
					end
				end
			end
			
			mutex = Mutex.new
			files_deleted = false
			
			thread = Thread.new do
				sleep 1
				
				mutex.synchronize do
					destination.glob("*.cpp").delete
					
					files_deleted = true
				end
			end
			
			walker.run do
				mutex.synchronize do
					group.wait do
						walker.update(top)
					end
				end
				
				break if files_deleted
			end
			
			thread.join
			
			expect(destination).to be_exist
			# This line failed, may still be a race condition:
			expect(destination.glob("*.cpp").count).to be == 2
			
			destination.delete
		end
	end
end
