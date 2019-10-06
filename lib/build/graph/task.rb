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

module Build
	module Graph
		class TransientError < StandardError
		end
		
		module ChildrenFailed
			def self.to_s
				"Children tasks failed!"
			end
		end
		
		module InputsFailed
			def self.to_s
				"Tasks generating inputs failed!"
			end
		end
		
		class Task
			def initialize(walker, node)
				@walker = walker
				
				@walker.tasks[node] = self
				
				@node = node
				@fiber = nil
				
				@error = nil
				
				# Tasks that must be complete before finishing this task.
				@children = []
				
				@state = nil
				
				@inputs_failed = false
			end
			
			attr :inputs
			attr :outputs
			
			attr :children
			
			# The state of the task, one of nil, :complete or :failed.
			attr :state
			
			# The error, if the execution of the node fails.
			attr :error
			
			attr :walker
			
			attr :node
			
			# A list of any inputs whose relevant tasks failed:
			attr :inputs_failed
			
			# Derived task can override this function to provide appropriate behaviour.
			def visit
				update_inputs_and_outputs
				
				# Inforn the walker a new task is being generated for this node:
				@walker.enter(self)
				
				if @fiber
					raise RuntimeError, "Task is already running!"
				end
				
				@fiber = Fiber.new do
					# If all inputs were good, we can update the node.
					if wait_for_inputs?
						begin
							yield
						rescue TransientError => error
							fail!(error)
						end
					else
						fail!(InputsFailed)
					end
					
					wait_for_children!
					
					update_outputs!
					
					@state ||= :complete
					
					@walker.exit(self)
					
					@fiber = nil
				end
				
				# Schedule the work, hopefully synchronously:
				@fiber.resume
				
				# This allows the child task to be passed back to the parent when it is first invoked.
				return self
			end
			
			# @return [Task] the child task that was created to update the node.
			def invoke(node)
				child_task = @walker.call(node, self)
				
				raise ArgumentError.new("Invalid child task") unless child_task
				
				@children << child_task
				
				return child_task
			end
			
			def failed?
				@state == :failed
			end
			
			def complete?
				@state == :complete
			end
			
			# Returns true if the outputs of the task are out of date w.r.t. the inputs.
			# Currently, does not take into account if the input is a glob and files have been added.
			def dirty?
				if @outputs
					@outputs.dirty?(@inputs)
				else
					true
				end
			end
			
			def changed!
				@walker.delete(@node) if (@inputs.update! or @outputs.update!)
			end
			
			def directories
				(@inputs.roots + @outputs.roots).collect{|path| path.to_s}
			end
			
			def to_s
				"#<#{self.class} #{node_string} #{state_string}>"
			end
			
			def inspect
				"\#<#{self.class}:0x#{self.object_id.to_s(16)} #{node_string} #{state_string}>"
			end
			
			protected
			
			def wait_for_children!
				unless wait_for_children?
					fail!(ChildrenFailed)
					
					return false
				end
				
				return true
			end
			
			def state_string
				if @state
					@state.to_s
				elsif @fiber
					"running"
				else
					"new"
				end
			end
			
			def node_string
				@node.inspect
			end
			
			# If the node inputs is a glob, this part of the process converts the glob into an actual list of files. If we are not inheriting outputs from children tasks, update our outputs now.
			def update_inputs_and_outputs
				@inputs = Files::State.new(@node.inputs)
				
				unless @node.inherit_outputs?
					@outputs = Files::State.new(@node.outputs)
				end
			end
			
			# @return [Build::Files::List] the merged list of all children outputs.
			def children_outputs
				@children.collect(&:outputs).inject(Files::Paths::NONE, &:+)
			end
			
			# If the node's outputs were a glob, this checks the filesystem to figure out what files were actually generated. If it inherits the outputs of the child tasks, merge them into our own outputs.
			def update_outputs!
				if @node.inherit_outputs?
					@outputs = Files::State.new(self.children_outputs)
				else
					# After the task has finished, we update the output states:
					@outputs.update!
				end
			end
			
			# Fail the task with the given error. Any task which is waiting on this task will also fail (eventually).
			def fail!(error)
				@walker.logger&.error(self) {error}
				
				@error = error
				@state = :failed
			end
			
			# @return [Boolean] if all inputs succeeded.
			def wait_for_inputs?
				# Wait on any inputs, returns whether any inputs failed:
				if @inputs&.any?
					unless @walker.wait_on_paths(self, @inputs)
						return false
					end
				end
				
				return true
			end
			
			# @return [Boolean] if all children succeeded.
			def wait_for_children?
				if @children&.any?
					unless @walker.wait_for_children(self, @children)
						return false
					end
				end
				
				return true
			end
		end
	end
end
