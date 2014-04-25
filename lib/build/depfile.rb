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

require 'strscan'

require_relative 'files/paths'

module Build
	class Depfile
		def initialize(rules)
			@rules = rules
		end
		
		attr :rules
		
		def self.load_file(path)
			input = File.read(path)
			
			self.parse(input)
		end
		
		module Parser
			SOURCE_PATH = /(\\\s|[^\s])+/
			SOURCE_SEPARATOR = /((:?\\\n|\s|\n)+)/
			
			def self.parse_rule(scanner)
				if scanner.scan(/(.*):/)
					rule = [:rule]
					
					target = scanner[1].strip
					rule << target
					
					# Parse dependencies:
					dependencies = []
					until scanner.scan(/\s*\n/) or scanner.eos?
						scanner.scan(/(\s|\\\n)*/)
						
						scanner.scan(SOURCE_PATH)
						dependencies << scanner[0].gsub(/\\ /, ' ')
					end
					rule << dependencies
					
					return rule
				end
			end
			
			def self.parse_statement(scanner)
				parse_rule(scanner)
			end
			
			def self.parse(scanner)
				while definition = parse_statement(scanner)
					yield definition
				end
			end
		end
		
		def self.parse(string)
			scanner = StringScanner.new(string)
			
			dependencies = {}
			Parser::parse(scanner) do |statement|
				if statement[0] == :rule
					dependencies[statement[1]] = statement[2]
				end
			end
			
			self.new(dependencies)
		end
	end
end
