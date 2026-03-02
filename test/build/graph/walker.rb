# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2015-2026, by Samuel Williams.

require "build/graph/node"
require "build/graph/walker"
require "build/graph/task"
require "build/files/glob"
require "build/files"

describe Build::Graph::Walker do
	it "can generate the same output from multiple tasks" do
		test_glob = Build::Files::Glob.new(__dir__, "*.rb")
		listing_output = Build::Files::Paths.directory(__dir__, ["listing.txt"])
		
		node_a = Build::Graph::Node.new(test_glob, listing_output)
		node_b = Build::Graph::Node.new(Build::Files::Paths::NONE, listing_output)
		
		sequence = []
		
		walker = Build::Graph::Walker.new do |walker, node|
			task = Build::Graph::Task.new(walker, node)
			
			task.visit do
				if node == node_a
					task.invoke(node_b)
				end
				
				node.outputs.each do |output|
					output.touch
				end
				
				sequence << node
			end
		end
		
		edge = Object.new
		def edge.traverse(task) = nil
		walker.outputs[listing_output.first.to_s] ||= [edge]
		expect(edge).to receive(:traverse)
		
		walker.update([node_a, node_a])
		
		expect(walker.tasks.count).to be == 2
		expect(walker.failed_tasks.count).to be == 0
		expect(sequence).to be == [node_b, node_a]
	end
	
	it "should be unique" do
		test_glob = Build::Files::Glob.new(__dir__, "*.rb")
		listing_output = Build::Files::Paths.directory(__dir__, ["listing.txt"])
		
		node_a = Build::Graph::Node.new(test_glob, listing_output)
		node_b = Build::Graph::Node.new(listing_output, Build::Files::Paths::NONE)
		
		sequence = []
		
		walker = Build::Graph::Walker.new do |walker, node|
			task = Build::Graph::Task.new(walker, node)
			
			task.visit do
				node.outputs.each do |output|
					output.touch
				end
				
				sequence << node
			end
		end
		
		walker.update([node_a, node_b])
		
		expect(walker.tasks.count).to be == 2
		expect(walker.failed_tasks.count).to be == 0
		expect(sequence).to be == [node_a, node_b]
	end
	
	it "should cascade failure" do
		test_glob = Build::Files::Glob.new(__dir__, "*.rb")
		listing_output = Build::Files::Paths.directory(__dir__, ["listing.txt"])
		summary_output = Build::Files::Paths.directory(__dir__, ["summary.txt"])
		
		node_a = Build::Graph::Node.new(test_glob, listing_output)
		node_b = Build::Graph::Node.new(listing_output, summary_output)
		
		walker = Build::Graph::Walker.new do |walker, node|
			task = Build::Graph::Task.new(walker, node)
			
			task.visit do
				if node == node_a
					raise Build::Graph::TransientError.new("Test Failure")
				end
			end
		end
		
		walker.update([node_a, node_b])
		
		expect(walker.tasks.count).to be == 2
		expect(walker.failed_tasks.count).to be == 2
		expect(listing_output.any?{|path| walker.failed_outputs.include?(path.to_s)}).to be == true
		expect(summary_output.any?{|path| walker.failed_outputs.include?(path.to_s)}).to be == true
		
		walker.clear_failed
		
		expect(walker.tasks.count).to be == 0
		expect(walker.failed_tasks.count).to be == 0
	end
	
	it "should inherit children outputs" do
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
