# Copyright, 2012, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require 'test/unit'

require 'build/files'

class TestFiles < Test::Unit::TestCase
	def test_inclusion
		# Glob all test files:
		glob = Build::Files::Glob.new(__dir__, "*.rb")
		
		assert glob.count > 0
		
		# Should include this file:
		assert glob.include?(__FILE__)
		
		# Glob should intersect self:
		assert glob.intersects?(glob)
	end
	
	def test_composites
		lib = File.join(__dir__, "../lib")
		
		test_glob = Build::Files::Glob.new(__dir__, "*.rb")
		lib_glob = Build::Files::Glob.new(lib, "*.rb")
		
		both = test_glob + lib_glob
		
		# List#roots is the generic accessor for Lists
		assert both.roots.include? test_glob.root
		
		# The composite should include both:
		assert both.include?(__FILE__)
	end
	
	def test_roots
		test_glob = Build::Files::Glob.new(__dir__, "*.rb")
		
		# Despite returning a String:
		assert test_glob.first.kind_of? String
		
		# We actually return a subclass which includes the root portion:
		assert_equal __dir__, test_glob.first.root
	end
	
	def test_renaming
		program_root = File.join(__dir__, "program")
		program_glob = Build::Files::Glob.new(program_root, "*.cpp")
		
		paths = program_glob.collect do |path|
			path + ".o"
		end
		
		puts "object paths: #{paths} from program paths: #{program_glob.to_a}"
	end
end
