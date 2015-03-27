# Copyright, 2015, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require 'build/files/state'

require_relative 'node'
require_relative 'walker'
require_relative 'controller'

require_relative 'outputs'

require 'process/group'

module Build
	module Graph
		# This is a basic implementation of a proc based build graph:
		module Basic
			# The graph node is created once, so a graph has a fixed number of nodes, which store per-vertex state and connectivity.
			class Node < Build::Graph::Node
				include Build::Files
				
				def initialize(controller, inputs = Paths::NONE, outputs = Paths::NONE, &update)
					@update = update
					
					super(controller, inputs, outputs)
				end
				
				def apply!(scope)
					scope.instance_eval(&@update)
				end
			end
			
			# The task is the context in which a vertex is updated. Because nodes may initially create other nodes, it is also responsible for looking up and creating new nodes.
			class Task < Build::Graph::Task
				include Build::Files
				
				def initialize(controller, walker, node, group = nil)
					super(controller, walker, node)
					
					@group = group
				end
				
				def wet?
					@group and @node.dirty?
				end
				
				def process(inputs, outputs, &block)
					inputs = Build::Files::List.coerce(inputs)
					
					if outputs == :inherit
						outputs = InheritOutputs.new(self)
					else
						outputs = Build::Files::List.coerce(outputs)
					end
					
					child_node = @controller.nodes.fetch([inputs, outputs]) do |key|
						@controller.nodes[key] = Node.new(@controller, inputs, outputs, &block)
					end
					
					@children << child_node
					
					# State saved in update!
					child_node.update!(@walker)
					
					return child_node
				end
				
				def run(*arguments)
					if wet?
						puts "\t[run] #{arguments.join(' ')}"
						status = @group.spawn(*arguments)
						
						if status != 0
							raise CommandError.new(status)
						end
					end
				end
				
				def visit
					super do
						@node.apply!(self)
					end
				end
			end
			
			# The controller contains all graph nodes and is responsible for executing tasks on the graph.
			class Controller < Build::Graph::Controller
				def initialize(&block)
					@top = Node.new(self, &block)
					
					# This calls build_graph to generate all the nodes:
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
					group = Process::Group.new
					
					walker = super do |walker, node|
						Task.new(self, walker, node, group)
					end
					
					group.wait
					
					return walker
				end
			end
		end
	end
end
