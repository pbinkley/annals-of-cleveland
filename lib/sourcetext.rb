require 'htmlentities'
require 'date'
require 'slugify'
require './lib/utils.rb'
require './lib/metadata.rb'

class SourceText
  attr_reader :text, :pageNumberList

  BREAKREGEX = /
                  \n#{NEWLINE}#{OCRDIGIT}+\s*\n#{NEWLINE}\n
                  #{NEWLINE}CLEVELAND\ NEWSPAPER.+?\n#{NEWLINE}\n
                  #{NEWLINE}Abstracts.+?\n#{NEWLINE}\n
                  #{NEWLINE}(?:.+Cont[[:punct:]]d\)|PLACEHOLDER)[\s[[:punct:]]]*\n#{NEWLINE}\n
                /x.freeze

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

    @pageNumberList = []
    breaks.each do |brk|
      entryNum = brk.match(/\A\n#{NEWLINE}(\d+).*\z/m)[1].to_i
      @pageNumberList << entryNum.to_i
      # remove page-break lines from text
      @text.sub!(brk, "+++ page #{entryNum}\n")
    end

    pages = @text.scan(/^(#{NEWLINE}\+\+\+.*)$/)

    report_list(@pageNumberList, 'page')

    File.open("text-without-breaks.txt", "w") { |f| f.puts @text }

  end

  def parseEntries(year)
    @year = year

    @entries = text.scan(/^(#{NEWLINE}#{OCRDIGIT}+(-1\/2)?\s*#{OCRDASH}\s*.+?\s*\(#{OCRDIGIT}+\))\s*$/m)
    entryNumberList = []

    parsedEntries = 0

    # parse metadata from first line of each entry
    # canonical form:
    # 1234|5 - H July 14:3/1 - Samuel H. Barton, a mason by trade, an^ recently
    @entries.each do |entry|
      lines = entry.first.split("\n")
      # remove blank lines
      lines.reject! { |line| line.match (/\A#{NEWLINE}\z/) }
      inputLine = lines.first
      metadata = Metadata.new(inputLine, @year, entryNumberList)

      # TODO: store metadata

      parsedEntries += 1 if metadata.parsed
      puts "bad line: #{inputLine}" unless metadata.parsed
    end

    puts "Parsed: #{parsedEntries}/#{@entries.count}"

    report_list(entryNumberList, 'entry')

    @entries
  end

  def parseHeadings
    # Identify "between" lines, which are either errors or headings

    betweens = []
    @text.scan(/\(#{OCRDIGIT}+\)\s*$(.+?)^#{NEWLINE}#{OCRDIGIT}+(\-1\/2)? #{OCRDASH} /m).map { |between| betweens += between[0].split("\n") }

    # empty lines look like: ["\n11968|\n"]
    betweens.reject! { |between| between == '' || between.match(/\A#{NEWLINE}\z/) || between.match(/\A#{NEWLINE}\+\+\+/) }

    @headings = []
    betweens.each do |between|
      @headings << between.gsub(/#{NEWLINE}\n/, '').strip
    end

    seealsos = {}

    headingData = {}
    unclassified = 0

    @headings.each do |heading|
      line_num, text = heading.match(/\A(#{NEWLINE})(.*)/)[1..2]
      # strip closing punctuation from text, leaving one punctuation mark at end of string
      text.sub!(/\A(.+?[[:punct:]]?)[\s■[[:punct:]]]+\z/, '\1')
      line_num = line_num.sub('|', '').to_i
      this_block = { text: text }
      if text.match(/^===/)
        # TODO: handle text note
      elsif text.match(/^\+/)
        # text inserted by editor
        text = text.gsub(/^\++ /, '')
        type = 'subheading2'
        if text.match(/^\+\+ /)
          type = 'subheading1'
        else
          type = 'heading'
        end
        this_block[:type] = type
        headingData[line_num] = this_block
      elsif text.match(/^[A-Z&',\- ]*[.\- ]*$/)
        text.gsub!(/[\.\-\ ]*$/, '')
        headingData[line_num] = { type: 'heading', text: text }
      elsif text.match(/^[A-Z&',\- ]+[.,] See .*$/)
        # TODO: handle see reference
        # e.g. "ABANDONED CHILDREN. See Children"
        #puts 'see: ' + text
      elsif text.match(/^.* #{OCRDASH} See .*$/)
        # TODO: handle see entry reference
        # e.g. "H Feb. 28:3/3 - See Streets"
        #puts 'see entry: ' + text
      elsif text.match(/^See [Aa]l[s§][Qo] .*$/)
        # e.g. "See also Farm Products"
        seealso = text.sub('See also ', '')
        seealso.split(';').each do |text|
          text.strip!
          if text[0].match(/[A-Z]/)
            parts = text.split('-')
            obj = { 'text' => parts[0].to_s.strip, 'slug' => parts[0].to_s.strip.slugify.gsub(/-+/, '') }
            obj['subheading'] = parts[1].to_s.strip
            seealsos[line_num] = obj
          else
            # generic entry like "names of animals"
            seealsos[line_num] = { generic: text }
          end
        end
      elsif !text.split(/\s+/)
                 .map { |word| word.match(/\A[A-Za-z&][a-z]*\s*\z/) }
                 .include?(nil)
        # test whether text consists only of words which may be capitalized but not all caps
        headingData[line_num] = { type: 'subheading1', text: text }
      elsif !text.gsub(/\A\((.*)\z/, '\1')
                 .split(/\s+/)
                 .map { |word| word.match(/\A[A-Za-z&][a-z]*\z/) }
                 .include?(nil)
        # test whether text consists only of words which may be capitalized but not all caps
        headingData[line_num] = { type: 'subheading2', text: text.gsub(/\A\((.*)\)\z/, '\1') }
      else
        puts "Unclassified: #{line_num}|#{text}"
        unclassified += 1
      end
    end
    puts "Unclassified: #{unclassified}"
    @headings
  end
end