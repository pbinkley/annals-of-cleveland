# frozen_string_literal: true

require 'htmlentities'
require 'date'
require 'slugify'
require './lib/utils.rb'
require './lib/abstract.rb'
require './lib/textmap.rb'
#require './lib/units.rb'

# TODO: handle page breaks in the other sections (with different headers)

class SourceText

  attr_reader :text, :page_number_count

  def initialize(filename)
    sectionName = 'INTRO'
    @section = {sectionName => ''}
    counter = 1
    File.readlines(filename).each do |line|
      line.gsub!(NWORDREGEX, '\1****r')
      if line.match(/^#START_/)
        sectionName = line.sub('#START_', '').strip
        @section[sectionName] = ''
      end
      @section[sectionName] += "#{counter}|#{ line }" unless line.empty? # prefix each line with line number
      counter += 1
    end

    coder = HTMLEntities.new
    @section.keys.each do |key| 
      @section[key] = coder.decode(@section[key])
      @section[key].gsub!(/\n\d+\|$/, "") # remove blank lines
    end

    @page_map = TestPagesTextMap.new(@section, 'ABSTRACTS')
    @page_number_count = @page_map.count
  end

  def parse_abstracts(year, issues)
    @abstract_map = TestAbstractsTextMap.new(@section, 'ABSTRACTS')
    @page_map.merge_to(@abstract_map)
    @abstract_map
  end

  def parse_headings
    # Identify "between" lines, which are either errors or headings

    # headings code removed here

    @heading_map = TestHeadingsTextMap.new(@section, 'ABSTRACTS')
    
    @terms_map = TestTermsTextMap.new(@section, 'TERMS')

    File.open('./intermediate/abstract.txt', 'w') do |f|
      @abstract_map.hash.keys.each do |key|
        this = @abstract_map.hash[key]
        f.puts "#{key}|#{this.id}|#{this.source_page}|#{this.heading}|#{this.terms}"
      end
    end

    @heading_map.hash
  end

end
