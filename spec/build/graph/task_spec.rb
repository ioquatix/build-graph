#!/usr/bin/env rspec
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2015-2019, by Samuel Williams.

require "build/graph/node"
require "build/graph/walker"
require "build/graph/task"
require "build/files/glob"

require_relative "process_graph"

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
