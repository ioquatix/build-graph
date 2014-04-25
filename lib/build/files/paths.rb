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

module Build
	module Files
		# Represents a file path with an absolute root and a relative offset:
		class Path
			def self.relative_path(root, full_path)
				relative_offset = root.length
				
				# Deal with the case where the root may or may not end with the path separator:
				relative_offset += 1 unless root.end_with?(File::SEPARATOR)
				
				return full_path.slice(relative_offset..-1)
			end
			
			# Both paths must be full absolute paths, and path must have root as an prefix.
			def initialize(full_path, root = nil)
				# This is the object identity:
				@full_path = full_path
				
				if root
					@root = root
					@relative_path = nil
				else
					# Effectively dirname and basename:
					@root, @relative_path = File.split(full_path)
				end
			end
			
			attr :root
			
			def to_str
				@full_path
			end
			
			def to_path
				@full_path
			end
			
			def length
				@full_path.length
			end
			
			def parts
				@parts ||= @full_path.split(File::SEPARATOR)
			end
			
			def relative_path
				@relative_path ||= Path.relative_path(@root, @full_path)
			end
			
			def relative_parts
				basename, _, filename = self.relative_path.rpartition(File::SEPARATOR)
				
				return basename, filename
			end
			
			def +(extension)
				self.class.new(@full_path + extension, @root)
			end
			
			def rebase(root)
				self.class.new(File.join(root, relative_path), root)
			end
			
			def with(root: @root, extension: nil)
				self.class.new(File.join(root, extension ? relative_path + extension : relative_path), root)
			end
			
			def self.join(root, relative_path)
				self.new(File.join(root, relative_path), root)
			end
			
			def shortest_path(working_directory = Dir.pwd)
				if start_with? working_directory
					Path.new(working_directory, @full_path)
				else
					self
				end
			end
			
			def to_s
				@full_path
			end
			
			def inspect
				"<Path #{@full_path}>"
			end
			
			def hash
				@full_path.hash
			end
			
			def eql?(other)
				@full_path.eql?(other.to_s)
			end
			
			def ==(other)
				self.to_s == other.to_s
			end
			
			def for_reading
				[@full_path, File::RDONLY]
			end
			
			def for_writing
				[@full_path, File::CREAT|File::TRUNC|File::WRONLY]
			end
			
			def for_appending
				[@full_path, File::CREAT|File::APPEND|File::WRONLY]
			end
		end
		
		def self.Path(*args)
			if Path === args[0]
				args[0]
			else
				Path.new(*args)
			end
		end
		
		# A list of paths, where #each yields instances of Path.
		class List
			include Enumerable
			
			def roots
				collect{|path| path.root}.sort.uniq
			end
			
			# Create a composite list out of two other lists:
			def +(list)
				Composite.new([self, list])
			end
			
			# Does this list of files include the path of any other?
			def intersects? other
				other.any?{|path| include?(path)}
			end
			
			def with(**args)
				return to_enum(:with, **args) unless block_given?
				
				paths = []
				
				each do |path|
					updated_path = path.with(args)
					
					yield path, updated_path
					
					paths << updated_path
				end
				
				return Paths.new(paths)
			end
			
			def rebase(root)
				Paths.new(self.collect{|path| path.rebase(root)}, [root])
			end
			
			def to_paths
				Paths.new(each.to_a)
			end
			
			def map
				Paths.new(super)
			end
			
			def self.coerce(arg)
				if arg.kind_of? self
					arg
				else
					Paths.new(arg)
				end
			end
		end
		
		class Paths < List
			def initialize(list, roots = nil)
				@list = Array(list).freeze
				@roots = roots
			end
			
			attr :list
			
			# The list of roots for a given list of immutable files is also immutable, so we cache it for performance:
			def roots
				@roots ||= super
			end
			
			def count
				@list.count
			end
			
			def each
				return to_enum(:each) unless block_given?
				
				@list.each{|path| yield path}
			end
			
			def eql?(other)
				other.kind_of?(self.class) and @list.eql?(other.list)
			end
		
			def hash
				@list.hash
			end
			
			def to_paths
				self
			end
			
			def inspect
				"<Paths #{@list.inspect}>"
			end
			
			def self.directory(root, relative_paths)
				paths = relative_paths.collect do |path|
					Path.join(root, path)
				end
				
				self.new(paths, [root])
			end
		end
		
		class Composite < List
			def initialize(files, roots = nil)
				@files = []
				
				files.each do |list|
					if list.kind_of? Composite
						@files += list.files
					elsif List.kind_of? List
						@files << list
					else
						# Try to convert into a explicit paths list:
						@files << Paths.new(list)
					end
				end
				
				@files.freeze
				@roots = roots
			end
			
			attr :files
			
			def each
				return to_enum(:each) unless block_given?
				
				@files.each do |files|
					files.each{|path| yield path}
				end
			end
			
			def roots
				@roots ||= @files.collect(&:roots).flatten.uniq
			end
			
			def eql?(other)
				other.kind_of?(self.class) and @files.eql?(other.files)
			end
		
			def hash
				@files.hash
			end
			
			def +(list)
				if list.kind_of? Composite
					self.class.new(@files + list.files)
				else
					self.class.new(@files + [list])
				end
			end
		
			def include?(path)
				@files.any? {|list| list.include?(path)}
			end
		
			def rebase(root)
				self.class.new(@files.collect{|list| list.rebase(root)}, [root])
			end
		
			def to_paths
				self.class.new(@files.collect(&:to_paths), roots: @roots)
			end
			
			def inspect
				"<Composite #{@files.inspect}>"
			end
		end
	
		NONE = Composite.new([]).freeze
	end
end
