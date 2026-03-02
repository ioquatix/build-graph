# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2015-2026, by Samuel Williams.

require "build/graph/node"
require "build/graph/walker"
require "build/graph/task"
require "build/files/glob"

describe Build::Graph::Task do
	it "should wait for children" do
		node_a = Build::Graph::Node.new(Build::Files::Paths::NONE, Build::Files::Paths::NONE)
		node_b = Build::Graph::Node.new(Build::Files::Paths::NONE, :inherit)
		
		nodes = Set.new([node_a])
		
		sequence = []
		
		walker = Build::Graph::Walker.new do |walker, node|
			task = Build::Graph::Task.new(walker, node)
			
			task.visit do
				sequence << [:entered, node]
				
				if node == node_a
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
