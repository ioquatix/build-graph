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

require 'minitest/autorun'

require 'build/files/paths'
require 'build/files/glob'

class TestPaths < MiniTest::Test
	include Build::Files
	
	def setup
		@path = Path.new("/foo/bar/baz", "/foo")
	end
	
	def test_path_conversions
		# The to_str method should return the full path (i.e. the same as to_s):
		assert_equal @path.to_s, @path.to_str
		
		# Checkt the equality operator:
		assert_equal @path, @path.dup
		
		# The length should be reported correctly:
		assert_equal @path.length, @path.to_s.length
	end
	
	def test_path_parts
		assert_equal ["", "foo", "bar", "baz"], @path.parts
		
		assert_equal "/foo", @path.root
		
		assert_equal "bar/baz", @path.relative_path
		
		assert_equal ["bar", "baz"], @path.relative_parts
	end
	
	def test_path_with
		path = @path.with(root: '/tmp', extension: '.txt')
		
		assert_equal '/tmp', path.root
		
		assert_equal 'bar/baz.txt', path.relative_path
	end
	
	def test_path_class
		assert_instance_of Path, @path
		assert_instance_of String, @path.root
		assert_instance_of String, @path.relative_path
	end
	
	def test_path_manipulation
		object_path = @path + ".o"
		
		assert_equal "/foo", object_path.root
		assert_equal "bar/baz.o", object_path.relative_path
	end
	
	def test_paths
		paths = Paths.new([
			Path.join('/foo/bar', 'alice'),
			Path.join('/foo/bar', 'bob'),
			Path.join('/foo/bar', 'charles'),
			@path
		])
		
		assert_includes paths, @path
		
		assert paths.intersects?(paths)
		refute paths.intersects?(NONE)
		
		mapped_paths = paths.map {|path| path + ".o"}
		
		assert_instance_of Paths, mapped_paths
		assert_equal paths.roots, mapped_paths.roots
	end
	
	def test_glob
		glob = Glob.new(File.join(__dir__, 'program'), '*.cpp')
		
		assert_equal 2, glob.count
		
		mapped_paths = glob.map {|path| path + ".o"}
		
		assert_equal glob.roots, mapped_paths.roots
	end
	
	def test_hashing
		cache = {}
		
		cache[Paths.new(@path)] = true
		
		assert cache[Paths.new(@path)]
	end
end
