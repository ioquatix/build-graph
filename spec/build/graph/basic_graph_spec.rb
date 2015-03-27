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

require 'build/graph/basic'
require 'build/makefile'

require 'fileutils'

module Build::Graph::GraphSpec
	include Build::Graph::Basic
	include Build::Files
	
	describe Build::Graph::Basic do
		it "shouldn't update mtime" do
			test_glob = Glob.new(__dir__, "*.rb")
			listing_output = Paths.directory(__dir__, ["listing.txt"])
			
			FileUtils.rm_f listing_output.to_a
			
			node = nil
			
			controller = Controller.new do
				node = process test_glob, listing_output do
					run("ls", "-la", *inputs, :out => outputs.first.for_writing)
				end
			end
			
			expect(controller.top).to_not be nil
			expect(node).to_not be nil
			
			controller.update!
			
			mtime = listing_output.first.mtime
			
			# Ensure the mtime will change even if the granularity of the filesystem is 1 second:
			sleep(1)
			
			controller.update!
			
			# The output file shouldn't have been changed because already exists and the input files haven't changed either:
			expect(listing_output.first.mtime).to be == mtime
			
			FileUtils.rm_f listing_output.to_a
		end
		
		it "should compile program and respond to changes in source code" do
			program_root = Path.join(__dir__, "program")
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
				
				process program_path, Paths::NONE do
					run("./" + program_path.relative_path, chdir: program_path.root)
				end
			end
			
			walker = controller.update!
			expect(walker).to be_kind_of Build::Graph::Walker
			
			expect(program_path).to be_exist
			expect(code_glob.first.mtime).to be <= program_path.mtime
		end
	end
end
