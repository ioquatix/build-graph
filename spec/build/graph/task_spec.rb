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

require_relative 'process_graph'

RSpec.describe Build::Graph::Task do
	it "should wait for children" do
		node_a = Build::Graph::Node.new(Build::Files::Paths::NONE, Build::Files::Paths::NONE)
		node_b = Build::Graph::Node.new(Build::Files::Paths::NONE, :inherit)
		
		nodes = Set.new([node_a])
		
		sequence = []
		
		# A walker runs repeatedly, updating tasks which have been marked as dirty.
		walker = Build::Graph::Walker.new do |walker, node|
			task = Build::Graph::Task.new(walker, node)
			
			task.visit do
				sequence << [:entered, node]
				
				if node == node_a
					# This will invoke node_b concurrently, but as it is a child, task.visit won't finish until node_b is done.
					task.invoke(node_b)
				end
			end
			
			sequence << [:exited, node]
		end
		
		walker.update(nodes)
		
		expect(walker.tasks.count).to be == 2
		expect(walker.failed_tasks.count).to be == 0
		
		task_b = walker.tasks[node_b]
		expect(walker.tasks[node_a].children).to be == [task_b]
		
		expect(sequence).to be == [
			[:entered, node_a],
			[:entered, node_b],
			[:exited, node_b],
			[:exited, node_a]
		]
	end
end
