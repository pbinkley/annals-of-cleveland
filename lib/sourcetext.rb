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
    entry_number_list = []

    parsed_entries = 0

    # parse metadata from first line of each entry
    # canonical form:
    # 1234|5 - H July 14:3/1 - Samuel H. Barton, a mason by trade, an^ recently
    @entries.each do |entry|
      lines = entry.first.split("\n")
      # remove blank lines
      lines.reject! { |line| line.match(/\A#{NEWLINE}\z/) }
      input_line = lines.first
      metadata = Metadata.new(input_line, @year, entry_number_list)

      # TODO: store metadata

      parsed_entries += 1 if metadata.parsed
      puts "bad line: #{input_line}" unless metadata.parsed
    end

    puts "Parsed: #{parsed_entries}/#{@entries.count}"

    report_list(entry_number_list, 'entry')

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

    heading_data = {}
    unclassified = 0

    @headings.each do |heading|
      line_num, text = heading.match(/\A(#{NEWLINE})(.*)/)[1..2]
      # strip closing punctuation from text, leaving one punctuation mark
      # at end of string
      text.sub!(/\A(.+?[[:punct:]]?)[\s■[[:punct:]]]+\z/, '\1')
      line_num = line_num.sub('|', '').to_i
      this_block = { text: text }
      if text.match(/^===/)
        # TODO: handle text note
      elsif text.match(/^\+/)
        # text inserted by editor
        text = text.gsub(/^\++ /, '')
        type = if text.match(/^\+\+\+ /)
                 'subheading2'
               elsif text.match(/^\+\+ /)
                 'subheading1'
               else
                 'heading'
               end
        this_block[:type] = type
        heading_data[line_num] = this_block
      elsif text.match(/^[A-Z&',\- ]*[.\- ]*$/)
        text.gsub!(/[\.\-\ ]*$/, '')
        heading_data[line_num] = { type: 'heading', text: text }
      elsif text.match(/^[A-Z&',\- ]+[.,] See .*$/)
        # TODO: handle see reference
        # e.g. "ABANDONED CHILDREN. See Children"
      elsif text.match(/^.* #{OCRDASH} See .*$/)
        # TODO: handle see entry reference
        # e.g. "H Feb. 28:3/3 - See Streets"
      elsif text.match(/^See [Aa]l[s§][Qo] .*$/)
        # e.g. "See also Farm Products"
        seealso = text.sub('See also ', '')
        seealso.split(';').each do |ref|
          ref.strip!
          if ref[0].match(/[A-Z]/)
            parts = ref.split('-')
            obj = {
              'text' => parts[0].to_s.strip,
              'slug' => parts[0].to_s.strip.slugify.gsub(/-+/, '')
            }
            obj['subheading'] = parts[1].to_s.strip
            see_alsos[line_num] = obj
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
        # capitalized but not all caps
        heading_data[line_num] = {
          type: 'subheading2',
          text: text.gsub(/\A\((.*)\)\z/, '\1')
        }
      else
        puts "Unclassified: #{line_num}|#{text}"
        unclassified += 1
      end
    end
    puts "Unclassified: #{unclassified}"
    @headings
  end

end
