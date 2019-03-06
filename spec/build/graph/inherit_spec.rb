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
require 'build/graph/task'
require 'build/files'

RSpec.describe Build::Graph::Walker do
	it "should inherit children outputs", :focus do
		test_glob = Build::Files::Glob.new(__dir__, "*.rb")
		listing_output = Build::Files::Paths.directory(__dir__, ["listing.txt"])
		
		node_a = Build::Graph::Node.new(Build::Files::Paths::NONE, :inherit, "a")
		node_b = Build::Graph::Node.new(test_glob, listing_output, "b")
		
		walker = Build::Graph::Walker.new do |walker, node|
			task = Build::Graph::Task.new(walker, node)
			
			task.visit do
				if node.process == 'a'
					task.invoke(node_b)
				end
			end
		end
		
		walker.update([node_a])
		
		task_a = walker.tasks[node_a]
		task_b = walker.tasks[node_b]
		
		expect(task_a.outputs.to_a).to be == task_b.outputs.to_a
	end
end
