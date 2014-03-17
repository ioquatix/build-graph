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
require 'pathname'

module Build
	module Files
		class List
			include Enumerable
			
			def +(list)
				Composite.new([self, list])
			end
			
			def intersects? other
				other.any?{|path| include?(path)}
			end
			
			def match(pattern)
				all? {|path| path.match(pattern)}
			end
		end
		
		class RelativePath < String
			# Both paths must be full absolute paths, and path must have root as an prefix.
			def initialize(path, root)
				raise ArgumentError.new("#{root} is not a prefix of #{path}") unless path.start_with?(root)
			
				super path
			
				@root = root
			end
		
			attr :root
		
			def relative_path
				self.slice(@root.length..-1)
			end
		end
	
		# A list which has a single root directory.
		class DirectoryList < List
			def initialize(root)
				@root = root.to_s
			end
			
			attr :root
			
			def roots
				[@root]
			end
			
			def rebase(root)
				raise NotImplementedError
			end
			
			def to_paths(root=@root)
				relative_paths = self.each do |path|
					path.relative_path
				end
			
				return Paths.new(root, relative_paths)
			end
			
			def process(root=@root)
				self.collect do |path|
					basename, _, filename = path.relative_path.rpartition(File::SEPARATOR)
					
					File.join(basename, yield(filename))
				end
				
				Paths.new(root, self.collect)
			end
		end
	
		class Directory < DirectoryList
			def initialize(root, path = "")
				super(root)
				
				@path = path
			end
		
			attr :path
		
			def full_path
				File.join(@root, @path)
			end
		
			def each(&block)
				Dir.glob(full_path + "**/*") do |path|
					yield RelativePath.new(path, @root)
				end
			end
		
			def eql?(other)
				other.kind_of?(self.class) and @root.eql?(other.root) and @path.eql?(other.path)
			end
		
			def hash
				[@root, @path].hash
			end
		
			def include?(path)
				# Would be true if path is a descendant of full_path.
				path.start_with?(full_path)
			end
		
			def rebase(root)
				self.class.new(root, @path)
			end
		end
	
		class Glob < DirectoryList
			def initialize(root, pattern)
				super(root)
				
				@pattern = pattern
			end
	
			attr :root
			attr :pattern
		
			def full_pattern
				File.join(@root, @pattern)
			end
		
			# Enumerate all paths matching the pattern.
			def each(&block)
				Dir.glob(full_pattern) do |path|
					yield RelativePath.new(path, @root)
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
	
		class Paths < DirectoryList
			def initialize(root, paths)
				super(root)
				
				@paths = Array(paths)
			end
	
			attr :paths
	
			def each(&block)
				@paths.each do |path|
					full_path = File.join(@root, path)
					yield RelativePath.new(full_path, @root)
				end
			end
	
			def eql? other
				other.kind_of?(self.class) and @paths.eql?(other.paths)
			end
		
			def hash
				@paths.hash
			end
		
			def include?(path)
				# Compute a full relative path:
				full_path = File.absolute_path(path, @root)
				
				# If the full path starts with @root, test it for inclusion:
				if full_path.start_with? @root
					# Compute the relative component:
					relative_path = full_path[@root.length..-1]
					
					# Does this list of paths include it?
					return @paths.include?(relative_path)
				else
					return false
				end
			end
		
			def rebase(root)
				self.class.new(root, @paths)
			end
		
			def to_paths
				return self
			end
		end
	
		class Composite < List
			def initialize(files = Set.new)
				@files = files
			end
		
			attr :files
		
			def each(&block)
				@files.each do |files|
					files.each &block
				end
			end
		
			def roots
				@files.collect(&:roots).flatten.uniq
			end
		
			def eql?(other)
				other.kind_of?(self.class) and @files.eql?(other.files)
			end
		
			def hash
				@files.hash
			end
		
			def merge(list)
				if list.kind_of? Composite
					@files += list.files
				elsif list.kind_of? List
					@files << list
				else
					raise ArgumentError.new("Cannot merge non-list of file paths.")
				end
			end
		
			def +(list)
				if list.kind_of? Composite
					Composite.new(@files + list.files)
				else
					Composite.new(@files + [list])
				end
			end
		
			def include?(path)
				@files.any? {|list| list.include?(path)}
			end
		
			def rebase(root)
				self.class.new(@files.collect{|list| list.rebase(root)})
			end
		
			def to_paths
				Composite.new(@files.collect(&:to_paths))
			end
		
			def self.[](files)
				if files.size == 0
					return None
				elsif files.size == 1
					files.first
				else
					self.class.new(files)
				end
			end
		end
	
		NONE = Composite.new
	end
end
