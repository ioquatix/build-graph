# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2014-2019, by Samuel Williams.

require "build/files/state"
require "build/files"

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
			
			# @returns [Boolean] whether any input or output file is missing from the filesystem.
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
			
			# @returns [Boolean] whether this node is equal to another by comparing inputs and outputs.
			def == other
				self.equal?(other) or
					self.class == other.class and
					@inputs == other.inputs and
					@outputs == other.outputs
			end
			
			# @returns [Boolean] whether this node is equal to another, for use in Hash and Set.
			def eql?(other)
				self.equal?(other) or self == other
			end
			
			# @returns [Integer] a hash value derived from inputs and outputs.
			def hash
				@inputs.hash ^ @outputs.hash
			end
			
			# @returns [String] a human-readable representation of the node.
			def inspect
				"#<#{self.class} #{@inputs.inspect} => #{@outputs.inspect}>"
			end
			
			# Create a top-level node that inherits its outputs from its children.
			# @parameter inputs [Build::Files::List] the input files for this node.
			# @parameter outputs [Symbol] the output strategy, defaults to `:inherit`.
			# @returns [Node] the constructed top-level node.
			def self.top(inputs = Files::Paths::NONE, outputs = :inherit, **options, &block)
				self.new(inputs, outputs, block, **options)
			end
		end
	end
end
