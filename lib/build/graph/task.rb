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
		class Task
			def initialize(walker, node)
				@walker = walker
				
				@walker.tasks[node] = self
				
				@node = node
				
				# If the execution of the node fails, this is where we save the error:
				@error = nil
				
				@children = []
				
				@state = nil
				
				@inputs_failed = false
			end
			
			attr :inputs
			attr :outputs
			
			attr :children
			attr :state
			
			attr :walker
			
			attr :node
			
			# A list of any inputs whose relevant tasks failed:
			attr :inputs_failed
			
			# Derived task should override this function to provide appropriate behaviour.
			def visit
				update_inputs_and_outputs
				
				# Inforn the walker a new task is being generated for this node:
				@walker.enter(self)
				
				@fiber = Fiber.new do
					# If all inputs were good, we can update the node.
					if wait_for_inputs?
						begin
							yield
						rescue TransientError => error
							fail!(error)
						end
					else
						fail!(:inputs)
					end
					
					unless wait_for_children?
						fail!(:children)
					end
					
					update_outputs
					
					@state ||= :complete
					
					@walker.exit(self)
				end
				
				# Schedule the work, hopefully synchronously:
				@fiber.resume
				
				# This allows the child task to be passed back to the parent when it is first invoked.
				return self
			end
			
			def invoke(node)
				child_task = @walker.call(node)
				
				raise ArgumentError.new("Invalid child task") unless child_task
				
				@children << child_task
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
				@outputs.dirty?(@inputs)
			end
			
			def changed!
				@walker.delete(@node) if (@inputs.update! or @outputs.update!)
			end
			
			def directories
				(@inputs.roots + @outputs.roots).collect{|path| path.to_s}
			end
			
			def inspect
				"<#{self.class}:#{'0x%X' % self.object_id} #{@node.inspect} #{@state}>"
			end
			
			attr :error
			attr :state
			
		protected
			def update_inputs_and_outputs
				# If @node.inputs is a glob, this part of the process converts the glob into an actual list of files.
				@inputs = Files::State.new(@node.inputs)
				
				unless @node.inherit_outputs?
					@outputs = Files::State.new(@node.outputs)
				end
			end
			
			def children_outputs
				@children.collect(&:outputs).inject(Files::Paths::NONE, &:+)
			end
			
			def update_outputs
				if @node.inherit_outputs?
					@outputs = Files::State.new(self.children_outputs)
				else
					# After the task has finished, we update the output states:
					@outputs.update!
				end
			end
			
			def fail!(error)
				@error = error
				@state = :failed
			end
			
			# Returns false if any input failed.
			def wait_for_inputs?
				# Wait on any inputs, returns whether any inputs failed:
				@walker.wait_on_paths(@inputs)
			end
			
			# Returns false if any child failed.
			def wait_for_children?
				@walker.wait_for_children(self, @children)
			end
		end
	end
end
