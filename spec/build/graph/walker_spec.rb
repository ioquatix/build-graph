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

require 'build/graph/node'
require 'build/graph/walker'
require 'build/graph/task'
require 'build/files/glob'

module Build::Graph::WalkerSpec
	include Build::Graph
	include Build::Files
	
	describe Build::Graph::Walker do
		it "should be unique" do
			test_glob = Glob.new(__dir__, "*.rb")
			listing_output = Paths.directory(__dir__, ["listing.txt"])
			
			node_a = Node.new(test_glob, listing_output, "a")
			node_b = Node.new(listing_output, Paths::NONE, "b")
			
			nodes = Set.new([node_a, node_b])
			
			sequence = []
			
			# A walker runs repeatedly, updating tasks which have been marked as dirty.
			walker = Walker.new(nodes) do |walker, node|
				task = Task.new(walker, node)
				
				task.visit do
					sequence << node.process
				end
			end
			
			walker.update(nodes)
			
			expect(walker.count).to be == 2
			expect(sequence).to be == ['a', 'b']
		end
		
		it "should cascade failure" do
			test_glob = Glob.new(__dir__, "*.rb")
			listing_output = Paths.directory(__dir__, ["listing.txt"])
			summary_output = Paths.directory(__dir__, ["summary.txt"])
			
			node_a = Node.new(test_glob, listing_output, "a")
			node_b = Node.new(listing_output, summary_output, "b")
			
			nodes = Set.new([node_a, node_b])
			
			# A walker runs repeatedly, updating tasks which have been marked as dirty.
			walker = Walker.new(nodes) do |walker, node|
				task = Task.new(walker, node)
				
				task.visit do
					if node.process == 'a'
						raise TransientError.new('Test Failure')
					end
				end
			end
			
			walker.update(nodes)
			
			expect(walker.count).to be == 2
			expect(walker.failures).to be == 2
			expect(listing_output).to be_intersect walker.failed
			expect(summary_output).to be_intersect walker.failed
		end
	end
end
