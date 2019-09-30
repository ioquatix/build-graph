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
require 'build/files'

module Build
	module Graph
		# This is essentialy a immutable key:
		class Node
			# @param process [Object] Represents an abstract process, e.g. a name or a function.
			def initialize(inputs, outputs)
				@inputs = inputs
				@outputs = outputs
			end
			
			attr :inputs
			attr :outputs
			
			# Nodes that inherit outputs are special in the sense that outputs are not available until all child nodes have been evaluated.
			def inherit_outputs?
				@outputs == :inherit
			end
			
			# This computes the most recent modified time for all inputs.
			def modified_time
				@inputs.map{|path| path.modified_time}.max
			end
			
			def missing?
				@outputs.any?{|path| !path.exist?} || @inputs.any?{|path| !path.exist?}
			end
			
			# This is a canonical dirty function. All outputs must exist and must be newer than all inputs. This function is not efficient, in the sense that it must query all files on disk for last modified time.
			def dirty?
				if inherit_outputs?
					return true
				elsif @inputs.count == 0 or @outputs.count == 0
					# If there are no inputs or no outputs we are always dirty:
					return true
					
					# I'm not entirely sure this is the correct approach. If input is a glob that matched zero items, but might match items that are older than outputs, what is the correct output from this function?
				else
					# Dirty if any inputs or outputs missing:
					return true if missing?
					
					# Dirty if input modified after any output:
					if input_modified_time = self.modified_time
						# Outputs should always be more recent than their inputs:
						return true if @outputs.any?{|output_path| output_path.modified_time < input_modified_time}
					else
						# None of the inputs exist:
						true
					end
				end
				
				return false
			end
			
			def == other
				self.equal?(other) or
					self.class == other.class and
					@inputs == other.inputs and
					@outputs == other.outputs
			end
			
			def eql?(other)
				self.equal?(other) or self == other
			end
			
			def hash
				@inputs.hash ^ @outputs.hash
			end
			
			def inspect
				"#<#{self.class} #{@inputs.inspect} => #{@outputs.inspect}>"
			end
			
			def self.top(inputs = Files::Paths::NONE, outputs = :inherit, **options, &block)
				self.new(inputs, outputs, block, **options)
			end
		end
	end
end
