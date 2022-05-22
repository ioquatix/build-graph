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
require 'console'
require 'build/files/monitor'

require_relative 'task'
require_relative 'node'
require_relative 'edge'

module Build
	module Graph
		# A walker walks over a graph and applies a task to each node.
		class Walker
			def self.for(task_class, *args, **options)
				self.new(**options) do |walker, node, parent_task = nil|
					task = task_class.new(walker, node, *args)
					
					task.visit do
						task.update
					end
				end
			end
			
			def initialize(logger: Console.logger, &block)
				# Node -> Task mapping.
				@tasks = {}
				
				@update = block
				
				# A list of paths which are currently being generated by tasks:
				@outputs = {}
				
				@parents = Hash.new{|h,k| h[k] = []}
				
				# Failed output paths:
				@failed_tasks = []
				@failed_outputs = Set.new
				
				@logger = logger
				@monitor = Files::Monitor.new(logger: @logger)
			end
			
			# Primarily for debugging from within Task
			attr :logger
			
			# An Array of all instantiated tasks.
			attr :tasks
			
			# An Array of transient outputs which are currently being generated.
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
			
			def call(node, parent_task = nil)
				# We try to fetch the task if it has already been invoked, otherwise we create a new task.
				@tasks.fetch(node) do
					@logger&.debug(self) {"Update: #{node} #{parent_task.class}"}
					
					# This method should add the node
					@update.call(self, node, parent_task)
					
					# This should now be defined:
					return @tasks[node]
				end
			end
			
			def failed?
				@failed_tasks.size > 0
			end
			
			def wait_on_paths(task, paths)
				# If there are no paths, we are done:
				return true if paths.count == 0
				
				# We create a new directed hyper-graph edge which waits for all paths to be ready (or failed):
				edge = Edge.new
				
				paths = paths.collect(&:to_s)
				
				paths.each do |path|
					# Is there a task generating this output?
					if outputs = @outputs[path]
						@logger&.debug(self) {"Task #{task} is waiting on path #{path}"}
						
						# When the output is ready, trigger this edge:
						outputs << edge
						edge.increment!
					elsif !File.exist?(path)
						@logger&.warn(self) {"Task #{task} is waiting on paths which don't exist and are not being generated!"}
						raise RuntimeError, "File #{path} is not being generated by any active task!"
						# What should we do about paths which haven't been registered as outputs?
						# Either they exist - or they don't.
						# If they exist, it means they are probably static inputs of the build graph.
						# If they don't, it might be an error, or it might be deliberate.
					end
				end
				
				failed = paths.any?{|path| @failed_outputs.include?(path)}
				
				return edge.wait && !failed
			end
			
			# A parent task only completes once all it's children are complete.
			def wait_for_children(parent, children)
				# Consider only incomplete/failed children:
				children = children.select{|child| !child.complete?}
				
				# If there are no children like this, then done:
				return true if children.size == 0
				
				@logger&.debug(self) {"Task #{parent} is waiting on #{children.count} children"}
				
				# Otherwise, construct an edge to track state changes:
				edge = Edge.new
				
				children.each do |child|
					if child.failed?
						edge.skip!(child)
					else
						# We are waiting for this child to finish:
						edge.increment!
						
						@parents[child.node] << edge
					end
				end
				
				return edge.wait
			end
			
			def enter(task)
				@logger&.debug(self) {"Walker entering: #{task.node}"}
				
				@tasks[task.node] = task
				
				# In order to wait on outputs, they must be known before entering the task. This might seem odd, but unless we know outputs are being generated, waiting for them to complete is impossible - unless this was somehow specified ahead of time. The implications of this logic is that all tasks must be sequential in terms of output -> input chaning. This is by design and is not a problem in practice.
				
				if outputs = task.outputs
					@logger&.debug(self) do |buffer|
						buffer.puts "Task will generate outputs:"
						Array(outputs).each do |output|
							buffer.puts output.inspect
						end
					end
					
					outputs.each do |path|
						# Tasks which have children tasks may list the same output twice. This is not a bug.
						@outputs[path.to_s] ||= []
					end
				end
			end
			
			def exit(task)
				@logger&.debug(self) {"Walker exiting: #{task.node}, task #{task.failed? ? 'failed' : 'succeeded'}"}
				
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
					
					@logger&.debug(self) {"File #{task.failed? ? 'failed' : 'available'}: #{path}"}
					
					if edges = @outputs.delete(path)
						# @logger&.debug "\tUpdating #{edges.count} edges..."
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
				@logger&.debug(self) {"Delete #{node}"}

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
			
			def inspect
				"\#<#{self.class}:0x#{self.object_id.to_s(16)} #{@tasks.count} tasks, #{@failed_tasks.count} failed>"
			end
		end
	end
end
