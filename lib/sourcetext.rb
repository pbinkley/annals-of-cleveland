# frozen_string_literal: true

require 'htmlentities'
require 'date'
require 'slugify'
require './lib/utils.rb'
require './lib/abstract.rb'
require './lib/textmap.rb'

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

    @page_map = PagesTextMap.new(@section, 'ABSTRACTS')
    @page_number_count = @page_map.count
  end

  def parse_abstracts(year)
    @abstract_map = AbstractsTextMap.new(@section, 'ABSTRACTS')
    @page_map.merge_to(@abstract_map)
    @abstract_map
  end

  def parse_headings
    # Identify "between" lines, which are either errors or headings

    # headings code removed here

    @heading_map = HeadingsTextMap.new(@section, 'ABSTRACTS')
    
    @termspages_map = TermsPagesTextMap.new(@section, 'TERMS')
    @terms_map = TermsTextMap.new(@section, 'TERMS')
    @termspages_map.merge_to(@terms_map)
    @terms_map.merge_to(@abstract_map)

    File.open('./intermediate/abstract.txt', 'w') do |f|
      @abstract_map.hash.keys.each do |key|
        this = @abstract_map.hash[key]
        f.puts "#{key}|#{this.id}|#{this.source_page}|#{this.heading}|#{this.terms}"
      end
    end

    @heading_map.hash
  end

end
