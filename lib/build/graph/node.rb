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

require 'rainbow'

module Build
	module Graph
		# This is essentialy a immutable key:
		class Node
			def initialize(inputs, outputs, process)
				# These are immutable - rather than change them, create a new node:
				@inputs = inputs
				@outputs = outputs
				
				# Represents an abstract process, e.g. a name or a function.
				@process = process
			end
			
			attr :inputs
			attr :outputs
			attr :process
			
			# Nodes that inherit outputs are special in the sense that outputs are not available until all child nodes have been evaluated.
			def inherit_outputs?
				@outputs == :inherit
			end
			
			# This computes the most recent modified time for all inputs.
			def modified_time
				modified_time = @inputs.map{|path| path.modified_time}.max
			end
			
			# This is a canonical dirty function. All outputs must exist and must be newer than all inputs. This function is not efficient, in the sense that it must query all files on disk for last modified time.
			def dirty?
				if inherit_outputs?
					return true
				else
					# Dirty if any outputs don't exist:
					return true if @outputs.any?{|path| !path.exist?}
					
					# Dirty if input modified after any output:
					input_modified_time = self.modified_time
					
					# Outputs should always be more recent than their inputs:
					return true if @outputs.any?{|output_path| output_path.modified_time < input_modified_time}
				end
				
				return false
			end
			
			def eql?(other)
				other.kind_of?(self.class) and @inputs.eql?(other.inputs) and @outputs.eql?(other.outputs) and @process.eql?(other.process)
			end
			
			def hash
				[@inputs, @outputs, @process].hash
			end
			
			def inspect
				"<#{self.class.name} #{@inputs.inspect} => #{@outputs.inspect} by #{@process.inspect}>"
			end
			
			def self.top(inputs = Files::Paths::NONE, outputs = :inherit, **options, &block)
				self.new(inputs, outputs, block, **options)
			end
		end
	end
end
