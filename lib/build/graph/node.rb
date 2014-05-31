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

require 'build/files/state'

module Build
	class Node
		def initialize(controller, inputs, outputs)
			@controller = controller
			
			@state = Files::IOState.new(inputs, outputs)
			
			@status = :unknown
			@fiber = nil
			
			# These are immutable - rather than change them, create a new node:
			@inputs = inputs
			@outputs = outputs
			
			@controller.add(self)
		end
		
		def eql?(other)
			other.kind_of?(self.class) and @inputs.eql?(other.inputs) and @outputs.eql?(other.outputs)
		end
		
		def hash
			[@inputs, @outputs].hash
		end
		
		def directories
			@state.files.roots
		end
		
		def remove!
			@controller.delete(self)
		end
		
		# It is possible this function is called unnecessarily. The state check confirms whether a change occurred or not.
		def changed!(outputs = [])
			# Don't do anything if we are already dirty.
			return if dirty?
		
			if @state.intersects?(outputs) || @state.update!
				# puts "** Dirty: #{@inputs.to_a.inspect} -> #{@outputs.to_a.inspect}"
			
				# Could possibly use unknown status here.
				@status = :dirty
			
				# If this node changes, we force all other nodes which depend on this node to be dirty.
				@controller.update(directories, @outputs)
			end
		end
		
		attr :inputs
		attr :outputs
		
		attr :state
		attr :status
		
		def unknown?
			@status == :unknown
		end
		
		def dirty?
			@status == :dirty
		end
		
		def clean?
			@status == :clean
		end
		
		def clean!
			@status = :clean
		end
		
		def fail!
			@status = :failed
		end
		
		def failed?
			@status == :failed
		end
		
		def updating?
			@fiber != nil
		end
		
		# If we are in the initial state, we need to check if the outputs are fresh.
		def update_status!
			#puts "Update status: #{@inputs.inspect} -> #{@outputs.inspect} (status=#{@status} @fiber=#{@fiber.inspect}) @status=#{@status} @state.fresh?=#{@state.fresh?}"
			
			if @status == :unknown
				# This could be improved - only stale files should be reported, instead we report all.
				unless @state.fresh?
					changed!(self.inputs)
				else
					@status = :clean
				end
			end
		end
		
		def inspect
			"<#{dirty? ? '*' : ''}inputs=#{inputs.inspect} outputs=#{outputs.inspect} fiber=#{@fiber.inspect} fresh=#{@state.fresh?}>"
		end
		
		def requires_update?
			not clean?
		end
		
		# Perform some actions to update this node, returns when completed, and the node is no longer dirty.
		def update!(walker)
			#puts "Walking #{@inputs.to_a.inspect} -> #{@outputs.to_a.inspect} (dirty=#{dirty?} @fiber=#{@fiber.inspect})"
			
			# If a fiber already exists, this node is in the process of updating.
			if requires_update? and @fiber == nil
				# puts "Beginning: #{@inputs.to_a.inspect} -> #{@outputs.to_a.inspect}"
				
				@fiber = Fiber.new do
					task = walker.task(self)
					
					task.visit
					
					# Commit changes:
					# puts "** Committing: #{@inputs.to_a.inspect} -> #{@outputs.to_a.inspect}"
					
					@state.update!
					@fiber = nil
					
					task.exit
				end
			
				@fiber.resume
			end
		end
	end
end
