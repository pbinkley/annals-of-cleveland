# frozen_string_literal: true

require 'htmlentities'
require 'date'
require 'nokogiri'
require './lib/utils.rb'
require './lib/abstract.rb'
require './lib/textmap.rb'

# TODO: handle page breaks in the other sections (with different headers)

class SourceText

  attr_reader :text, :page_number_count

  def initialize(filename, year)
    @year = year
    section_name = 'INTRO'
    @section = { section_name => '' }
    counter = 1
    lines = []
    # note: we want lines to be stripped of \n
    if filename[-5..-1] == '.html'
      doc = File.open(filename) { |f| Nokogiri::HTML(f) }
      paras = doc.xpath('//p[@class="Text"]')
      paras.each { |para| lines += para.text.split("\n") }
      File.open("intermediate/#{@year}/processed.txt", 'w') { |f| lines.each { |line| f.puts(line) } }
    else
      lines = File.readlines(filename)
    end
    lines.each do |line|
      # objuscate the n-word
      line.gsub!(NWORDREGEX, '\1****r')
      # detect section breaks
      if line.match(/^#START_/)
        section_name = line.sub('#START_', '').strip
        @section[section_name] = ''
      end
      # prefix each line with line number - even blank lines, so that the
      # line numbers can be used to locate source lines in the editor
      @section[section_name] += "#{counter}|#{line.strip}\n" unless line.strip.empty?
      counter += 1
    end

    puts "Sections found: #{@section.keys.join('; ')}"

    coder = HTMLEntities.new
    @section.keys.each do |key|
      @section[key] = coder.decode(@section[key]) # decode html entities
      @section[key].gsub!(/\n\d+\|$/, '') # remove blank lines
    end

    # parse pages of the ABSTRACTS section
    @page_map = PagesTextMap.new(@section, 'ABSTRACTS', @year)
    @page_number_count = @page_map.count
  end

  def parse_abstracts
    @abstract_map = AbstractsTextMap.new(@section, 'ABSTRACTS', @year)
    @page_map.merge_to(@abstract_map)
    @abstract_map
  end

  def parse_headings(abstracts)
    # Identify "between" lines, which are either errors or headings

    # headings code removed here

    @heading_map = HeadingsTextMap.new(@section, 'ABSTRACTS', @year, abstracts)

    @page_map.merge_to(@heading_map) # TODO: merge pages into subheadings too
    @heading_map.merge_to(@abstract_map)

    @heading_map
  end

  def parse_terms
    @termspages_map = TermsPagesTextMap.new(@section, 'TERMS', @year)
    @terms_map = TermsTextMap.new(@section, 'TERMS')
    @termspages_map.merge_to(@terms_map)
    @terms_map.merge_to(@abstract_map)

    @terms_map
  end

end
