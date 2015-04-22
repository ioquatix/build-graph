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

require 'set'
require 'logger'

require_relative 'task'
require_relative 'node'
require_relative 'edge'
require_relative 'error'

module Build
	module Graph
		# A walker walks over a graph and applies a task to each node.
		class Walker
			def initialize(logger: nil, &block)
				# Node -> Task mapping.
				@tasks = {}
				
				@update = block
				
				@outputs = {}
				
				@parents = {}
				
				# Failed output paths:
				@failed_tasks = []
				@failed_outputs = Set.new
				
				@logger = logger || Logger.new(nil)
				@monitor = Files::Monitor.new(logger: @logger)
			end
			
			attr :tasks # {Node => Task}
			
			attr :outputs
			
			attr :failed_tasks
			attr :failed_outputs
			
			attr :count
			attr :dirty
			
			attr :parents
			
			attr :monitor
			
			def update(nodes)
				Array(nodes).each do |node|
					self.call(node)
				end
			end
			
			def call(node)
				# We try to fetch the task if it has already been invoked, otherwise we create a new task.
				@tasks.fetch(node) do
					@logger.debug{"Update: #{node}"}
					
					@update.call(self, node)
					
					# This should now be defined:
					@tasks[node]
				end
			end
			
			def failed?
				@failed_tasks.size > 0
			end
			
			def wait_on_paths(paths)
				# If there are no paths, we are done:
				return true if paths.count == 0
				
				# We create a new directed hyper-graph edge which waits for all paths to be ready (or failed):
				edge = Edge.new
				
				paths = paths.collect(&:to_s)
				
				paths.each do |path|
					# Is there a task generating this output?
					if outputs = @outputs[path]
						# When the output is ready, trigger this edge:
						outputs << edge
						edge.increment!
					end
				end
				
				failed = paths.any?{|path| @failed_outputs.include? path}
				
				return edge.wait && !failed
			end
			
			# A parent task only completes once all it's children are complete.
			def wait_for_children(parent, children)
				# Consider only incomplete/failed children:
				children = children.select{|child| !child.complete?}
				
				# If there are no children like this, then done:
				return true if children.size == 0
				
				# Otherwise, construct an edge to track state changes:
				edge = Edge.new
				
				children.each do |child|
					if child.failed?
						edge.skip!(child)
					else
						# We are waiting for this child to finish:
						edge.increment!
						
						@parents[child.node] ||= []
						@parents[child.node] << edge
					end
				end
				
				return edge.wait
			end
			
			def enter(task)
				@logger.debug{"--> #{task.node.process}"}
				
				@tasks[task.node] = task
				
				# In order to wait on outputs, they must be known before entering the task. This might seem odd, but unless we know outputs are being generated, waiting for them to complete is impossible - unless this was somehow specified ahead of time. The implications of this logic is that all tasks must be sequential in terms of output -> input chaning. This is not a problem in practice.
				if outputs = task.outputs
					outputs.each do |path|
						@outputs[path.to_s] = []
					end
				end
			end
			
			def exit(task)
				@logger.debug{"<-- #{task.node.process}"}
				
				# Fail outputs if the node failed:
				if task.failed?
					@failed_tasks << task
					
					if task.outputs
						@failed_outputs += task.outputs.collect{|path| path.to_s}
					end
				end
				
				# Clean the node's outputs:
				task.outputs.each do |path|
					path = path.to_s
					
					if edges = @outputs.delete(path)
						edges.each{|edge| edge.traverse(task)}
					end
				end
				
				# Notify the parent nodes that the child is done:
				if parents = @parents.delete(task.node)
					parents.each{|edge| edge.traverse(task)}
				end
				
				@monitor.add(task)
			end
			
			def delete(node)
				@logger.debug{">-< #{node.process}"}

				if task = @tasks.delete(node)
					@monitor.delete(task)
				end
			end
			
			def clear_failed
				@failed_tasks.each do |task|
					self.delete(task.node)
				end if @failed_tasks
				
				@failed_tasks = []
				@failed_outputs = Set.new
			end
			
			def run(**options)
				yield
				
				monitor.run(**options) do
					yield
				end
			end
		end
	end
end
