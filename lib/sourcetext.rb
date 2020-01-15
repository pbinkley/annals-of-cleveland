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

  attr_reader :text, :page_number_list

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

    @page_number_list = {}
    @page_map = TestPagesTextMap.new(@section, 'ABSTRACTS')
  end

  def parse_abstracts(year, issues)
    @abstract_map = TestAbstractsTextMap.new(@section, 'ABSTRACTS')
    @page_map.merge_to(@abstract_map)
    byebug
    @abstract_map
  end

  def parse_headings
    # Identify "between" lines, which are either errors or headings

    # headings code removed here

    @heading_map = TestHeadingsTextMap.new(@section, 'ABSTRACTS')
    
    # handle index terms
    
    inHeader = true
    badCount = 0
    terms = {}
    # TODO: Handle page breaks in TERMS section
    @section['TERMS'].split("\n").each do |line|
      next if line =~ /^#{NEWLINE}$/ # ignore blank line
      inHeader = false
      line.gsub!(/\ [\p{P}\p{S} ]*$/, '')
      line.gsub!(/([0-9])\.\ ?([0-9])/, '\1\2') # remove period between digits
      
      elements = line.match(/^#{NEWLINE}(.*)\, ([#{OCRDIGIT}\ \;\-\/]*)$/)
      seeref = line.match(/^#{NEWLINE}(.+)\. See (.+)$/)
      continuation = line.match(/^#{NEWLINE}[#{OCRDIGIT}\ -\/]*$/)
      puts line unless elements || seeref || continuation
      badCount += 1 unless elements || seeref || continuation
      next unless elements || seeref || continuation
      if elements
        term = elements[1].sub(/^#{NEWLINE}/, '')
        slug = term.slugify.gsub(/\-+/, '')
        ids = elements[2].split.each { |id| convert_ocr_number(id) }
        terms[term] = { slug: slug, ids: ids }
        previd = 0.0
        ids.each do |id|
          parts = id.split('-')
          id = parts[0].to_f
          # handle -1/2 suffix on id
          id += 0.5 if parts.count == 2 && parts[1] == '1/2'
          puts "High: #{term} | #{id}" if id > 2774.0
          thiskey = @abstract_map.hash.keys.select { |key| @abstract_map.hash[key].id == id }.first
          this = @abstract_map.hash[thiskey]
          if this
            this.add_term(term: term, slug: slug)
          else
            puts "No abstract #{id} for term #{term}"
          end
          previd = id
        end
      else
        # TODO: handle seeref and continuation
      end
    end
    puts "Unparsed TERMS lines: #{badCount}"

    File.open('./intermediate/abstract.txt', 'w') do |f|
      @abstract_map.hash.keys.each do |key|
        this = @abstract_map.hash[key]
        f.puts "#{key}|#{this.id}|#{this.source_page}|#{this.heading}|#{this.terms}"
      end
    end

    @heading_map.hash
  end

end
