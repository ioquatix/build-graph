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

require_relative 'error'

module Build
	module Graph
		# A walker walks over a graph and applies a task to each node.
		class Walker
			def initialize(controller, &task)
				@controller = controller
				@task = task
				
				# The number of nodes we have touched:
				@count = 0
				
				@outputs = {}
				@dirty = Set.new
			
				# Generate a list of dirty outputs, possibly a subset, if the build graph might generate additional nodes:
				@controller.nodes.each do |key, node|
					# For a given child, a list of any parents waiting on it.
					if node.dirty?
						@dirty << node
						
						@outputs[node] = []
						
						node.outputs.each do |output|
							@outputs[output] = []
						end
					end
				end
			
				@parents = {}
			
				# Failed output paths:
				@failed = Set.new
				
				# The number of failed nodes:
				@failures = 0
			end
			
			attr :controller
			attr :task
			
			attr :outputs
			
			attr_accessor :count
			attr :dirty
			
			attr :parents
			
			# A list of outputs which have failed to generate:
			attr :failed
			
			def failed?
				@failures > 0
			end
			
			def task(*arguments)
				@task.call(self, *arguments)
			end
			
			def wait_on_paths(paths)
				edge = Edge.new
				failed = false
			
				paths.each do |path|
					if @outputs.include? path
						@outputs[path] << edge
					
						edge.increment!
					end
				
					if !failed and @failed.include?(path)
						failed = true
					end
				end
			
				edge.wait || failed
			end
		
			def wait_for_nodes(children)
				edge = Edge.new
			
				children.each do |child|
					if @dirty.include?(child)
						edge.increment!
					
						@parents[child] ||= []
						@parents[child] << edge
					end
				end
			
				edge.wait
			end
		
			def exit(node)
				@dirty.delete(node)
			
				# Fail outputs if the node failed:
				if node.failed?
					@failed += node.outputs
					@failures += 1
				end
				
				# Clean the node's outputs:
				node.outputs.each do |path|
					if edges = @outputs.delete(path)
						edges.each{|edge| edge.traverse(node)}
					end
				end
		
				# Trigger the parent nodes:
				if parents = @parents.delete(node)
					parents.each{|edge| edge.traverse(node)}
				end
			end
		end
	
		# A task is a specific process and scope applied to a graph node.
		class Task
			def initialize(controller, walker, node)
				@controller = controller
				@node = node
				@walker = walker
			
				# If the execution of the node fails, this is where we save the error:
				@error = nil
			
				@children = []
			end
			
			attr :children
			
			def inputs
				@node.inputs
			end
		
			def outputs
				@node.outputs
			end
		
			def wet?
				@node.dirty?
			end
		
			# Derived task should override this function to provide appropriate behaviour.
			def visit
				wait_for_inputs
			
				# If all inputs were good, we can update the node.
				unless any_inputs_failed?
					begin
						yield
					rescue TransientError => error
						@controller.task_failure!(error, self)
						@error = error
					end
				end
			
				wait_for_children
			end
		
			def exit
				if @error || any_child_failed? || any_inputs_failed?
					@node.fail!
				elsif wet?
					@node.clean!
				end
				
				@walker.exit(@node)
				
				@walker.count += 1
			end
		
		protected
			def wait_for_inputs
				# Wait on any inputs, returns whether any inputs failed:
				@inputs_failed = @walker.wait_on_paths(@node.inputs)
			end
		
			def wait_for_children
				@walker.wait_for_nodes(@children)
			end
		
			def any_child_failed?
				@children.any?{|child| child.failed?}
			end
		
			def any_inputs_failed?
				@inputs_failed
			end
		end
	end
end
