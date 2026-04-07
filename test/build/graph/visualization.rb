# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2015-2026, by Samuel Williams.

require "build/graph/node"
require "build/graph/walker"
require "build/graph/task"
require "build/graph/visualization"
require "build/files/paths"

describe Build::Graph::Visualization do
	let(:visualization) {subject.new}
	let(:source) {Build::Files::Paths.directory("/src", ["main.c"])}
	let(:object) {Build::Files::Paths.directory("/obj", ["main.o"])}
	let(:binary) {Build::Files::Paths.directory("/bin", ["program"])}
	
	# Create a walker, populated with the given nodes, and return it for testing.
	def make_walker(*nodes)
		walker = Build::Graph::Walker.new do |walker, node|
			task = Build::Graph::Task.new(walker, node)
			
			# Traverse the task to populate the walker with all nodes and edges:
			task.traverse
		end
		
		walker.update(nodes)
		walker
	end
	
	it "generates a flowchart header" do
		node = Build::Graph::Node.new(source, object)
		walker = make_walker(node)
		
		output = visualization.generate(walker)
		
		expect(output).to be(:start_with?, "flowchart LR")
	end
	
	it "includes input and output node labels" do
		node = Build::Graph::Node.new(source, object)
		walker = make_walker(node)
		
		output = visualization.generate(walker)
		
		expect(output).to be(:include?, "main.c")
		expect(output).to be(:include?, "main.o")
	end
	
	it "generates an edge between input and output" do
		node = Build::Graph::Node.new(source, object)
		walker = make_walker(node)
		
		output = visualization.generate(walker)
		
		source_id = visualization.sanitize_id(source.first)
		object_id = visualization.sanitize_id(object.first)
		
		expect(output).to be(:include?, "#{source_id} -->")
		expect(output).to be(:include?, object_id)
	end
	
	it "generates edges across multiple nodes" do
		node_a = Build::Graph::Node.new(source, object)
		node_b = Build::Graph::Node.new(object, binary)
		walker = make_walker(node_a, node_b)
		
		output = visualization.generate(walker)
		
		expect(output).to be(:include?, "main.c")
		expect(output).to be(:include?, "main.o")
		expect(output).to be(:include?, "program")
	end
end
