require 'damerau-levenshtein'
require './lib/utils.rb'

class Metadata
  attr_reader :line, :lineNum, :id, :half, :newspaper, :month, :day, :type, :page, :column, :remainder, :date, :parsed, :normalized_line

  MONTHS = {
    'Jan.' => 1,
    'Feb.' => 2,
    'Mar.' => 3,
    'Apr.' => 4,
    'May' => 5,
    'June' => 6,
    'July' => 7,
    'Aug.' => 8,
    'Sept.' => 9,
    'Oct.' => 10,
    'Nov.' => 11,
    'Dec.' => 12
  }.freeze

  def initialize(metadata_string, year, entryNumberList)
    @year = year
    @entryNumberList = entryNumberList

    @line, @lineNum, @id, @half, @newspaper, @month, @day, @type, @page, @column, @remainder = metadata_string.match(
      %r{^(\d+)\|(\d+)(-1\/2)?\s       # '1234/123-1/2' line and entry
         #{OCRDASH}+\ ([a-zA-Z]+)[\.,]?\s   # '- H' newspaper
         (\S+)\s                         #month
         (#{OCRDIGIT}+)#{OCRCOLON}+\s?        # '2:' day
         ([a-zA-Z]*)#{OCRCOLON}?\s?        # 'ed' type (ed, adv)
         (#{OCRDIGIT}+)[/"'](#{OCRDIGIT}+)(.*)$         # '2/3' page and column
      }x
    ).to_a

    @parsed = false
    if @lineNum
      @day = convert_OCR_number(@day)
      @month.gsub!(',', '.')
      unless MONTHS[@month]
        guess = ''
        guessdistance = 10
        MONTHS.keys.each do |key|
          newGuessDistance = DamerauLevenshtein.distance(@month, key, 0)
          if newGuessDistance < guessdistance
            guess = key
            guessdistance = newGuessDistance
          end
        end
        # puts "#{lineNum} Guess: #{month} -> #{guess} (#{guessdistance})"
        @month = guess
      end
      begin
        @date = Date.new(@year, MONTHS[@month], @day)
      rescue StandardError => e
        puts @line
        puts e.message  
      end
      if @date
        @lineNum = @lineNum.to_i
        @id = @id.to_f
        # handle -1/2 suffix on id
        @id += 0.5 if @half == '-1/2'
        @entryNumberList << @id
        @newspaper = @newspaper.to_sym
        @month = MONTHS[@month]
        @displaydate = @date.strftime('%e %B %Y')
        @formatdate = @date.to_s
        @page = convert_OCR_number(@page)
        @column = convert_OCR_number(@column)
        @parsed = true
        # save normalized version of first line
        @normalized_line = "#{@lineNum}|#{@id} - #{@newspaper} #{@month} #{@day}#{('\; ' + @type) if !@type.empty?}:#{@page}/#{@column}#{@remainder}"
      end
    end
  end
end