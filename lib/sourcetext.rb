# frozen_string_literal: true

require 'htmlentities'
require 'date'
require 'slugify'
require './lib/utils.rb'
require './lib/metadata.rb'
require './lib/textmap.rb'

BREAKREGEX = /
                \n#{NEWLINE}#{OCRDIGIT}+\s*\n#{NEWLINE}\n
                #{NEWLINE}CLEVELAND\ NEWSPAPER.+?\n#{NEWLINE}\n
                #{NEWLINE}Abstracts.+?\n#{NEWLINE}\n
                #{NEWLINE}(?:.+Cont[[:punct:]]d\)|PLACEHOLDER)[\s[[:punct:]]]*\n
                #{NEWLINE}\n
              /x.freeze

# TODO: handle page breaks in the other sections (with different headers)

class SourceText

  attr_reader :text, :page_number_list

  def initialize(filename)
    sectionName = 'INTRO'
    @text = {sectionName => ''}
    counter = 1
    File.readlines(filename).each do |line|
      if line.match(/^#START_/)
        sectionName = line.sub('#START_', '').strip
        @text[sectionName] = ''
      end
      @text[sectionName] += "#{counter}|#{line}" # prefix each line with line number
      counter += 1
    end

    coder = HTMLEntities.new
    @text.keys.each { |key| @text[key] = coder.decode(@text[key]) }

    # Identify page breaks so that they can be removed
    breaks = @text['ABSTRACTS'].scan(BREAKREGEX)

    @page_number_list = {}
    @page_map = TextMap.new('pages')
    breaks.each do |brk|
      line_num, page_num = brk.match(/\A\n(\d+)\|(\d+).*\z/m).to_a[1..2]
      @page_number_list[page_num.to_i] = line_num.to_i
      # remove page-break lines from text
      @text['ABSTRACTS'].sub!(brk, "+++ page #{page_num}\n")
      @page_map.add(line_num, page_num: page_num)
    end
    report_list(@page_number_list.keys, 'page')
    File.open('./intermediate/text-without-breaks.txt', 'w') { |f| f.puts @text['ABSTRACTS'] }
  end

  def parse_abstracts(year)
    @year = year

    @abstracts = @text['ABSTRACTS'].scan(
      %r{
        ^(#{NEWLINE}#{OCRDIGIT}+(-1\/2)?\s*#{OCRDASH}\s*.+?\s*
        \(#{OCRDIGIT}+\))\s*$
      }mx
    )

    parsed_abstracts = 0
    @abstract_map = TextMap.new('abstracts')
    @abstract_number_list = []

    # parse metadata from first line of each abstract
    # canonical form:
    # 1234|5 - H July 14:3/1 - Samuel H. Barton, a mason by trade, an^ recently
    @abstracts.each do |abstract|
      lines = abstract.first.split("\n")
      # remove blank lines
      lines.reject! { |line| line.match(/\A#{NEWLINE}\z/) }
      input_line = lines.first
      metadata = Metadata.new(input_line, @year)

      @abstract_map.add(metadata.line_num, metadata)
      @abstract_number_list << metadata.id
      # TODO: store metadata

      parsed_abstracts += 1 if metadata.parsed
      puts "bad line: #{input_line}" unless metadata.parsed
    end

    puts "Parsed: #{parsed_abstracts}/#{@abstracts.count}"

    report_list(@abstract_number_list, 'abstract')

    @page_map.merge_to(@abstract_map)

    @abstracts
  end

  def parse_headings
    # Identify "between" lines, which are either errors or headings

    betweens = []
    @text['ABSTRACTS'].scan(
      %r{(?:\(#{OCRDIGIT}+\)|\#START_ABSTRACTS)\s*$(.+?)^(?:#{NEWLINE}#{OCRDIGIT}+(?:\-1\/2)?
        \s#{OCRDASH}\s|\#END_ABSTRACTS)
      }mx
    ).map { |between| betweens += between[0].split("\n") }

    # empty lines look like: ["\n11968|\n"]
    betweens.reject! do |between|
      between == '' ||
        between.match(/\A#{NEWLINE}\z/) ||
        between.match(/\A#{NEWLINE}\+\+\+/)
    end

    @headings = []
    betweens.each do |between|
      @headings << between.gsub(/#{NEWLINE}\n/, '').strip
    end

    see_alsos = {}
    see_headings = {}

    @heading_map = TextMap.new('headings')
    @sees_map = TextMap.new('sees')
    unclassified = 0

    @headings.each do |heading|
      line_num, text = heading.match(/\A(#{NEWLINE})(.*)/)[1..2]
      # strip closing punctuation from text, leaving one punctuation mark
      # at end of string
      text.sub!(/\A(.+?[[:punct:]]?)[\s■[[:punct:]]]+\z/, '\1')
      line_num = line_num.sub('|', '').to_i
      heading_hash = { start: line_num, text: text }
      if text.match(/^===/)
        # TODO: handle text note
      elsif text.match(/^\+/)
        # text inserted by editor, with prefix of +, ++, or +++
        text = text.gsub(/^\++ /, '')
        type = if text.match(/^\+\+\+ /)
                 'subheading2'
               elsif text.match(/^\+\+ /)
                 'subheading1'
               else
                 'heading'
               end
        heading_hash[:type] = type
        @heading_map.add(line_num, heading_hash)
      elsif text.match(/^[A-Z&',\- ]*[.\- ]*$/)
        # plain heading e.g. "SLAVERY"
        text.gsub!(/[\.\-\ ]*$/, '')
        heading_hash[:type] = 'heading'
        @heading_map.add(line_num, heading_hash)
      elsif text.match(/^[A-Z&',\- ]+[.,] See .*$/)
        # e.g. "ABANDONED CHILDREN. See Children"
        # handles heading and subheading1
        source, target = text.match(/^([A-Z&',\- ]+)[.,] See (.*)$/).to_a[1..2]
        target.split('; ').each do |unit|
          heading, subheading1 = unit.split(/ #{OCRDASH} /)
          heading.upcase!
          see_headings[source] = [] unless see_headings[source]
          reference = { heading: heading }
          reference[:subheading1] = subheading1 if subheading1
          see_headings[source] << reference
        end
      elsif text.match(/^.* #{OCRDASH} See .*$/)
        # TODO: handle see abstract reference
        # e.g. "H Feb. 28:3/3 - See Streets"
        metadata = Metadata.new(heading, @year, false)
        # TODO: find the abstract - maybe save abstracts in hash with normalized metadata as key, pointing to record number
        @sees_map.add(metadata.line_num, metadata)
        # TODO: save metadata
      elsif text.match(/^See [Aa]l[s§][Qo] .*$/)
        # e.g. "See also Farm Products"
        seealso = text.sub('See also ', '')
        seealso.split(';').each do |ref|
          ref.strip!
          if ref[0].match(/[A-Z]/)
            parts = ref.split('-')
            reference = {
              'text' => parts[0].to_s.strip,
              'slug' => parts[0].to_s.strip.slugify.gsub(/-+/, '')
            }
            reference['subheading'] = parts[1].to_s.strip
            see_alsos[line_num] = reference
          else
            # generic abstract like "names of animals"
            see_alsos[line_num] = { generic: ref }
          end
        end
      elsif !text.split(/\s+/)
                 .map { |word| word.match(/\A[A-Za-z&][a-z]*\s*\z/) }
                 .include?(nil)
        # test whether text consists only of words, which may be
        # capitalized but not all caps
        heading_hash.merge!(type: 'subheading1', text: text)
        @heading_map.add(line_num, heading_hash)
      elsif !text.gsub(/\A\((.*)\z/, '\1')
                 .split(/\s+/)
                 .map { |word| word.match(/\A[A-Za-z&][a-z]*\z/) }
                 .include?(nil)
        # test whether text consists only of words which may be
        # capitalized but not all caps, in brackets
        heading_hash.merge!(
          type: 'subheading2',
          text: text.gsub(/\A\((.*)\z/, '\1')
        )
        @heading_map.add(line_num, heading_hash)
      else
        puts "Unclassified: #{line_num}|#{text}"
        unclassified += 1
      end
    end
    puts "Unclassified: #{unclassified}"

    @page_map.merge_to(@heading_map) # add page numbers to headings
    @heading_map.validate_headings
    @heading_map.merge_to(@abstract_map)
    @heading_map.nest_headings

    File.open('./intermediate/abstract.txt', 'w') do |f|
      @abstract_map.hash.keys.each do |key|
        this = @abstract_map.hash[key]
        f.puts "#{key}|#{this.id}|#{this.page_num}|#{this.heading}"
      end
    end

    {
      headings: @heading_map.hash,
      see_alsos: see_alsos,
      see_headings: see_headings
    }
  end

end
