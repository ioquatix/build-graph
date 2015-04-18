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

require_relative 'task'
require_relative 'node'
require_relative 'edge'
require_relative 'error'

module Build
	module Graph
		# A walker walks over a graph and applies a task to each node.
		class Walker
			def initialize(&block)
				# Node -> Task mapping.
				@tasks = {}
				
				@update = block
				
				@outputs = {}
				@dirty = Set.new
				
				@parents = {}
				
				# Failed output paths:
				@failed_tasks = []
				@failed_outputs = Set.new
			end
			
			attr :tasks # {Node => Task}
			
			attr :outputs
			
			attr :failed_tasks
			attr :failed_outputs
			
			attr :count
			attr :dirty
			
			attr :parents
			
			def update(nodes)
				Array(nodes).each do |node|
					@update.call(self, node)
				end
			end
			
			def call(node)
				# We try to fetch the task if it has already been invoked, otherwise we create a new task.
				@tasks.fetch(node) do
					@update.call(self, node)
					
					# This should now be defined:
					@tasks[node]
				end
			end
			
			def failed?
				@failed_tasks.size > 0
			end
			
			def wait_on_paths(paths)
				# We create a new directed hyper-graph edge which waits for all paths to be ready (or failed):
				edge = Edge.new
				
				paths.each do |path|
					# Is there a task generating this output?
					if outputs = @outputs[path]
						# When the output is ready, trigger this edge:
						outputs << edge
						edge.increment!
					end
				end
				
				failed = paths.any?{|path| @failed_outputs.include? path}
				
				edge.wait || failed
			end
		
			def wait_for_tasks(children)
				edge = Edge.new
				
				children.each do |child|
					if @dirty.include?(child.node)
						edge.increment!
					
						@parents[child.node] ||= []
						@parents[child.node] << edge
					end
				end
			
				edge.wait
			end
			
			def enter(task)
				#puts "--> #{task.node.process}"
				@tasks[task.node] = task
			end
			
			def exit(task)
				#puts "<-- #{task.node.process}"
				@dirty.delete(task.node)
				
				# Fail outputs if the node failed:
				if task.failed?
					@failed_tasks << task
					
					if task.outputs
						@failed_outputs += task.outputs
					end
				end
				
				# Clean the node's outputs:
				task.outputs.each do |path|
					if edges = @outputs.delete(path)
						edges.each{|edge| edge.traverse(task)}
					end
				end
				
				# Trigger the parent nodes:
				if parents = @parents.delete(task.node)
					parents.each{|edge| edge.traverse(task)}
				end
			end
			
			def clear_failed
				@failed_tasks.each do |task|
					@tasks.delete(task.node)
				end if @failed_tasks
				
				@failed_tasks = []
				@failed_outputs = Set.new
			end
		end
	end
end
