# Copyright, 2014, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require 'build/files/monitor'

require_relative 'error'
require_relative 'node'
require_relative 'walker'
require_relative 'edge'

module Build
	module Graph
		# The top level graph controller is responsible for managing build graph state.
		class Controller < Files::Monitor
			def initialize
				super
			
				@nodes = {}
			
				build_graph!
			end
			
			attr :nodes
			
			# Override this to traverse the top nodes as required.
			def traverse!(walker)
				#Array(top).each do |node|
				#	node.update!(walker)
				#end
			end
			
			# Walk the graph with the given callback.
			def walk(&block)
				Walker.new(self, &block)
			end
			
			# Build the initial graph structure.
			def build_graph!
				# We build the graph without doing any actual execution:
				nodes = []
				
				walker = walk do |walker, node|
					nodes << node
				
					yield walker, node
				end
				
				traverse! walker
				
				# We should update the status of all nodes in the graph once we've traversed the graph.
				nodes.each do |node|
					node.update_status!
				end
			end
			
			# Update the graph and print out timing information.
			def update_with_log
				puts Rainbow("*** Graph update traversal ***").green
				
				start_time = Time.now
				
				walker = update!
			ensure
				end_time = Time.now
				elapsed_time = end_time - start_time
			
				$stdout.flush
				$stderr.puts Rainbow("Graph Update Time: %0.3fs" % elapsed_time).magenta
			end
			
			# Update the graph.
			def update!
				walker = walk do |walker, node|
					yield walker, node
				end
				
				traverse! walker
				
				return walker
			end
		end
	end
end
