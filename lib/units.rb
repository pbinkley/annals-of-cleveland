# frozen_string_literal: true

# given a section of text, return a hash of units parsed according 
#   to a given regex; optionally remove those units from the text
#   and return metadata extracted from units. 

require './lib/textmap.rb'
require './lib/utils.rb'
require 'byebug'

class Units

  attr_reader :units
  
  def initialize(textblock)
    @textblock = textblock

    @unitregex = /dummy/
    @name = ''
    
  end

  def extractUnits
    # run the regex and populate @units here
    @units = @textblock.scan(@unitregex)
    parseUnits
  end

  def parseUnits
  end

end

class AbstractUnits < Units

  def initialize(textblock)
    @textblock = textblock

    @unitregex = %r{
      ^(#{NEWLINE}#{OCRDIGIT}+(-1\/2)?\s*#{OCRDASH}\s*.+?\s*
      \(#{OCRDIGIT}+\))\s*$
    }mx
    @name = 'ABSTRACTS'
    
    extractUnits
  end

  def parseUnits
    @year = 1845 # TODO: manage issue metadata
    @issues = IssuesTextMap.new('ISSUES') # temporary - needs to be global
    
    parsed_abstracts = 0
    @abstract_map = AbstractsTextMap.new(@name)
    @abstract_number_list = []

    # parse metadata from first line of each abstract
    # canonical form:
    # 1234|5 - H July 14:3/1 - Samuel H. Barton, a mason by trade, an^ recently
    @units.each do |unit|
      lines = unit.first.split("\n")
      # remove blank lines
      lines.reject! { |line| line.match(/\A#{NEWLINE}\z/) }
      input_line = lines.first
      abstract = Abstract.new(lines, @year)

      @abstract_map.add(abstract.line_num, abstract)
      @abstract_number_list << abstract.id
      
      @issues.addAbstract(abstract)

      parsed_abstracts += 1 if abstract.parsed
      puts "bad line: #{input_line}" unless abstract.parsed
    end

    puts "Parsed: #{parsed_abstracts}/#{units.count}"

    report_list(@abstract_number_list, 'abstract')

    #@page_map.merge_to(@abstract_map)
    
    @abstract_map

  end
  
end
