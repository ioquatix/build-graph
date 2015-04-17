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
	
	class ProcessTask < Task
		def process(inputs, outputs, &block)
			inputs = Build::Files::List.coerce(inputs)
			outputs = Build::Files::List.coerce(outputs)
			
			node = Node.new(inputs, outputs, block)
			
			self.invoke(node)
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
		
		def update(group = nil)
			@group = group
			
			self.instance_eval(&@node.process)
		end
	end
	
	describe Build::Graph do
		it "shouldn't update mtime" do
			test_glob = Glob.new(__dir__, "*.rb")
			listing_output = Paths.directory(__dir__, ["listing.txt"])
			
			FileUtils.rm_f listing_output.to_a
			
			node = nil
			group = Process::Group.new
			
			walker = Walker.new do |walker, node|
				task = ProcessTask.new(walker, node)
				
				task.visit do
					task.update(group)
				end
			end
			
			top = Node.top do
				process test_glob, listing_output do
					run("ls", "-la", *inputs, :out => outputs.first.for_writing)
				end
			end
			
			walker.update(top)
			
			mtime = listing_output.first.mtime
			
			# Ensure the mtime will change even if the granularity of the filesystem is 1 second:
			sleep(1)
			
			walker.update(top)
			
			# The output file shouldn't have been changed because already exists and the input files haven't changed either:
			expect(listing_output.first.mtime).to be == mtime
			
			FileUtils.rm_f listing_output.to_a
		end
	end
end
