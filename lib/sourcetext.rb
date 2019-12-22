# frozen_string_literal: true

require 'htmlentities'
require 'date'
require 'slugify'
require './lib/utils.rb'
require './lib/metadata.rb'

BREAKREGEX = /
                \n#{NEWLINE}#{OCRDIGIT}+\s*\n#{NEWLINE}\n
                #{NEWLINE}CLEVELAND\ NEWSPAPER.+?\n#{NEWLINE}\n
                #{NEWLINE}Abstracts.+?\n#{NEWLINE}\n
                #{NEWLINE}(?:.+Cont[[:punct:]]d\)|PLACEHOLDER)[\s[[:punct:]]]*\n
                #{NEWLINE}\n
              /x.freeze

class SourceText

  attr_reader :text, :page_number_list

  def initialize(filename)
    @text = ''
    counter = 1
    File.readlines(filename).each do |line|
      @text += "#{counter}|#{line}"
      counter += 1
    end

    coder = HTMLEntities.new
    @text = coder.decode(@text) # decode html entities

    # Identify page breaks so that they can be removed
    breaks = @text.scan(BREAKREGEX)

    @page_number_list = []
    breaks.each do |brk|
      entry_num = brk.match(/\A\n#{NEWLINE}(\d+).*\z/m)[1].to_i
      @page_number_list << entry_num.to_i
      # remove page-break lines from text
      @text.sub!(brk, "+++ page #{entry_num}\n")
    end

    report_list(@page_number_list, 'page')
    File.open('text-without-breaks.txt', 'w') { |f| f.puts @text }
  end

  def parse_entries(year)
    @year = year

    @entries = text.scan(
      %r{
        ^(#{NEWLINE}#{OCRDIGIT}+(-1\/2)?\s*#{OCRDASH}\s*.+?\s*
        \(#{OCRDIGIT}+\))\s*$
      }mx
    )

    parsed_entries = 0
    @entry_data = {}
    @entry_number_list = []

    # parse metadata from first line of each entry
    # canonical form:
    # 1234|5 - H July 14:3/1 - Samuel H. Barton, a mason by trade, an^ recently
    @entries.each do |entry|
      lines = entry.first.split("\n")
      # remove blank lines
      lines.reject! { |line| line.match(/\A#{NEWLINE}\z/) }
      input_line = lines.first
      metadata = Metadata.new(input_line, @year)

      @entry_data[metadata.line_num] = metadata
      @entry_number_list << metadata.id
      # TODO: store metadata

      parsed_entries += 1 if metadata.parsed
      puts "bad line: #{input_line}" unless metadata.parsed
    end

    puts "Parsed: #{parsed_entries}/#{@entries.count}"

    report_list(@entry_number_list, 'entry')

    @entries
  end

  def parse_headings
    # Identify "between" lines, which are either errors or headings

    betweens = []
    @text.scan(
      %r{\(#{OCRDIGIT}+\)\s*$(.+?)^#{NEWLINE}#{OCRDIGIT}+(\-1\/2)?
        \s#{OCRDASH}\s
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

    heading_data = {}
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
        heading_data[line_num] = heading_hash
      elsif text.match(/^[A-Z&',\- ]*[.\- ]*$/)
        # plain heading e.g. "SLAVERY"
        text.gsub!(/[\.\-\ ]*$/, '')
        heading_hash[:type] = 'heading'
        heading_data[line_num] = heading_hash
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
        # TODO: handle see entry reference
        # e.g. "H Feb. 28:3/3 - See Streets"
        metadata = Metadata.new(heading, @year, false)
        # TODO: find the entry - maybe save entries in hash with normalized metadata as key, pointing to record number
        @entry_data[metadata.line_num] = metadata
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
            # generic entry like "names of animals"
            see_alsos[line_num] = { generic: ref }
          end
        end
      elsif !text.split(/\s+/)
                 .map { |word| word.match(/\A[A-Za-z&][a-z]*\s*\z/) }
                 .include?(nil)
        # test whether text consists only of words which may be
        # capitalized but not all caps
        heading_data[line_num] = { type: 'subheading1', text: text }
      elsif !text.gsub(/\A\((.*)\z/, '\1')
                 .split(/\s+/)
                 .map { |word| word.match(/\A[A-Za-z&][a-z]*\z/) }
                 .include?(nil)
        # test whether text consists only of words which may be
        # capitalized but not all caps, in brackets
        heading_hash.merge(
          type: 'subheading2',
          text: text.gsub(/\A\((.*)\)\z/, '\1')
        )
        heading_data[line_num] = heading_hash
      else
        puts "Unclassified: #{line_num}|#{text}"
        unclassified += 1
      end
    end
    puts "Unclassified: #{unclassified}"
    @headings
  end

end
