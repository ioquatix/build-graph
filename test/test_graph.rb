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

require 'test/unit'

require 'build/graph'
require 'build/files'
require 'build/system/pool'

class TestGraph < Test::Unit::TestCase
	# The graph node is created once, so a graph has a fixed number of nodes, which store per-vertex state and connectivity.
	class Node < Build::Node
		def initialize(graph, inputs, outputs, &update)
			@update = update
			
			super(graph, inputs, outputs)
		end
		
		def apply!(scope)
			scope.instance_eval(&@update)
		end
		
		# This ensures that enclosed nodes are run if they are dirty. The top level node has no inputs or outputs by default, so children who become dirty wouldn't mark it as dirty and thus wouldn't be run.
		def requires_update?
			if outputs.count == 0
				return true
			else
				super
			end
		end
	end
	
	# The task is the context in which a vertex is updated. Because nodes may initially create other nodes, it is also responsible for looking up and creating new nodes.
	class Task < Build::Task
		def initialize(graph, walker, node, pool = nil)
			super(graph, walker, node)
			
			@pool = pool
		end
		
		def wet?
			@pool# and @node.dirty?
		end
		
		def process(inputs, outputs, &block)
			child_node = @graph.nodes.fetch([inputs, outputs]) do |key|
				@graph.nodes[key] = Node.new(@graph, inputs, outputs, &block)
			end
		
			@children << child_node
		
			# State saved in update!
			child_node.update!(@walker)
		end
		
		def run(*arguments)
			if wet?
				status = @pool.run(*arguments)
				
				if status != 0
					raise CommandFailure.new(arguments, status)
				end
			end
		end
		
		def visit
			super do
				@node.apply!(self)
			end
		end
	end
	
	class Graph < Build::Graph
		def initialize(&block)
			@top = Node.new(self, Build::Files::NONE, Build::Files::NONE, &block)
			
			super()
		end
		
		attr_accessor :top
		
		def traverse!(walker)
			@top.update!(walker)
		end
		
		def build_graph!
			super do |walker, node|
				Task.new(self, walker, node)
			end
		end
		
		def update!
			pool = Build::System::Pool.new
			
			super do |walker, node|
				Task.new(self, walker, node, pool)
			end
			
			pool.wait
		end
	end
	
	def test_minimal_graph
		test_glob = Build::Files::Glob.new(__dir__, "*.rb")
		output_paths = Build::Files::Paths.new(__dir__, ["listing.txt"])
		
		FileUtils.rm_f output_paths.to_a
		
		graph = Graph.new do
			process test_glob, output_paths do
				run("ls", "-la", *test_glob, :out => output_paths.first)
			end
		end
		
		graph.update!
		
		mtime = File.mtime(output_paths.first)
		
		graph.update!
		
		assert_equal mtime, File.mtime(output_paths.first)
		
		FileUtils.rm_f output_paths.to_a
		
		#graph.nodes.each do |key, node|
		#	puts "#{node.status} #{node.inspect}"
		#end
	end
end
