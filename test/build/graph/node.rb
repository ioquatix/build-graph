# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2015-2019, by Samuel Williams.

require "build/graph/node"
require "build/files/glob"
require "build/files/system"

describe Build::Graph::Node do
	let(:test_glob) {Build::Files::Glob.new(__dir__, "*.rb")}
	let(:listing_output) {Build::Files::Paths.directory(__dir__, ["listing.txt"])}
	
	it "should be unique" do
		node_a = Build::Graph::Node.new(test_glob, listing_output)
		node_b = Build::Graph::Node.new(listing_output, Build::Files::Paths::NONE)
		
		expect(node_a).to be == node_a
		expect(node_a).not.to be == node_b
		
		node_c = Build::Graph::Node.new(test_glob, listing_output)
		
		expect(node_a).to be == node_c
	end
	
	it "should be dirty" do
		node_a = Build::Graph::Node.new(test_glob, listing_output)
		
		expect(node_a.dirty?).to be == true
	end
	
	it "should be clean" do
		listing_output.first.touch
		
		node_a = Build::Graph::Node.new(test_glob, listing_output)
		
		expect(node_a.dirty?).to be == false
		
		listing_output.first.delete
	end
	
	it "should be dirty if input files are missing" do
		input = Build::Files::Paths.directory(__dir__, ["missing-input.txt"])
		output = Build::Files::Glob.new(__dir__, "*.rb")
		
		node = Build::Graph::Node.new(input, output)
		
		expect(node.missing?).to be == true
		expect(node.dirty?).to be == true
	end
	
	it "should be dirty if output files are missing" do
		input = Build::Files::Glob.new(__dir__, "*.rb")
		output = Build::Files::Paths.directory(__dir__, ["missing-output.txt"])
		
		node = Build::Graph::Node.new(input, output)
		
		expect(node.missing?).to be == true
		expect(node.dirty?).to be == true
	end
end
