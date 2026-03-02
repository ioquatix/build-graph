#!/usr/bin/env rspec
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2015-2019, by Samuel Williams.

require "build/graph/walker"
require "build/graph/task"
require "build/files"

RSpec.describe Build::Graph::Walker do
	it "should inherit children outputs", :focus do
		test_glob = Build::Files::Glob.new(__dir__, "*.rb")
		listing_output = Build::Files::Paths.directory(__dir__, ["listing.txt"])
		
		node_a = Build::Graph::Node.new(Build::Files::Paths::NONE, :inherit)
		node_b = Build::Graph::Node.new(test_glob, listing_output)
		
		walker = Build::Graph::Walker.new do |walker, node|
			task = Build::Graph::Task.new(walker, node)
			
			task.visit do
				if node == node_a
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
