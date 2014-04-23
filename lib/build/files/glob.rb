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

require_relative 'paths'

module Build
	module Files
		class Glob < List
			def initialize(root, pattern)
				@root = root
				@pattern = pattern
			end
			
			attr :root
			attr :pattern
			
			def roots
				[@root]
			end
			
			def full_pattern
				Path.join(@root, @pattern)
			end
		
			# Enumerate all paths matching the pattern.
			def each(&block)
				return to_enum(:each) unless block_given?
				
				Dir.glob(full_pattern) do |path|
					yield Path.new(path, @root)
				end
			end
			
			def eql?(other)
				other.kind_of?(self.class) and @root.eql?(other.root) and @pattern.eql?(other.pattern)
			end
		
			def hash
				[@root, @pattern].hash
			end
		
			def include?(path)
				File.fnmatch(full_pattern, path)
			end
		
			def rebase(root)
				self.class.new(root, @pattern)
			end
		end
	end
end
