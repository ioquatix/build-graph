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
require 'build/files/glob'
require 'build/files/system'

module Build::Graph::NodeSpec
	include Build::Graph
	include Build::Files
	
	describe Build::Graph::Node do
		it "should be unique" do
			test_glob = Glob.new(__dir__, "*.rb")
			listing_output = Paths.directory(__dir__, ["listing.txt"])
			
			node_a = Node.new(test_glob, listing_output, "a")
			node_b = Node.new(listing_output, Paths::NONE, "b")
			
			expect(node_a).to be_eql node_a
			expect(node_a).to_not be_eql node_b
			
			node_c = Node.new(test_glob, listing_output, "a")
			
			expect(node_a).to be_eql node_c
		end
		
		it "should be dirty" do
			test_glob = Glob.new(__dir__, "*.rb")
			listing_output = Paths.directory(__dir__, ["listing.txt"])
			
			node_a = Node.new(test_glob, listing_output, "a")
			
			expect(node_a.dirty?).to be true
		end
		
		it "should be clean" do
			test_glob = Glob.new(__dir__, "*.rb")
			listing_output = Paths.directory(__dir__, ["listing.txt"])
			
			listing_output.first.touch
			
			node_a = Node.new(test_glob, listing_output, "a")
			
			expect(node_a.dirty?).to be false
			
			listing_output.first.delete
		end
	end
end
