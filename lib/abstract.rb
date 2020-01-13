# frozen_string_literal: true

require 'date'
require 'damerau-levenshtein'
require './lib/utils.rb'
require 'byebug'

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

METADATA_LINE_ID = "^(\\d+)\\|(\\d+)(-1\/2)?\\s     # '1234|123-1/2 - ' line, id, dash
        #{OCRDASH}+\\s"

METADATA_LINE = "^(\\d+)\\|()()     # '1234|' line"

METADATA_FIELDS = "
        ([a-zA-Z]+)[\.,]?\s       # 'H' newspaper
        (\\S+)\s                                #month
        (#{OCRDIGIT}+)#{OCRCOLON}+\s?          # '2:' day
        ([a-zA-Z]*)#{OCRCOLON}?\s?             # 'ed' type (ed, adv)
        (#{OCRDIGIT}+)[/\"'](#{OCRDIGIT}+)(.*)$ # '2/3' page and column"

METADATA_REGEX_LINE_ID = %r{
  #{METADATA_LINE_ID}
          ([a-zA-Z]+)[\.,]?\s       # 'H' newspaper
        (\S+)\s                                #month
        (#{OCRDIGIT}+)#{OCRCOLON}+\s?          # '2:' day
        ([a-zA-Z]*)#{OCRCOLON}?\s?             # 'ed' type (ed, adv)
        (#{OCRDIGIT}+)[/\"'](#{OCRDIGIT}+)(.*)$ # '2/3' page and column
}x.freeze

METADATA_REGEX_LINE = %r{
  #{METADATA_LINE}
          ([a-zA-Z]+)[\.,]?\s       # 'H' newspaper
        (\S+)\s                                #month
        (#{OCRDIGIT}+)#{OCRCOLON}+\s?          # '2:' day
        ([a-zA-Z]*)#{OCRCOLON}?\s?             # 'ed' type (ed, adv)
        (#{OCRDIGIT}+)[/\"'](#{OCRDIGIT}+)(.*)$ # '2/3' page and column
}x.freeze

def get_month(month)
  # given OCR of month abbreviation, make best guess at true abbreviation
  month.gsub!(',', '.')
  return month if MONTHS[month]

  guess = ''
  guess_distance = 10
  MONTHS.keys.each do |key|
    new_guess_distance = DamerauLevenshtein.distance(month, key, 0)
    if new_guess_distance < guess_distance
      guess = key
      guess_distance = new_guess_distance
    end
  end
  guess
end

class Abstract

  attr_reader :line, :line_num, :id, :half, :newspaper, :month, :day,
              :type, :page, :column, :remainder, :date, :formatdate, :parsed,
              :normalized_line, :page_num, :heading, :terms

  def initialize(lines, year, with_id = true)
    @year = year
    @lines = lines
    @with_id = with_id

    metadata_string = @lines[0]
    
    @line, @line_num, @id, @half, @newspaper, @month, @day, @type, @page,
    @column, @remainder = (
      if @with_id then metadata_string.match(METADATA_REGEX_LINE_ID)
      else metadata_string.match(METADATA_REGEX_LINE)
      end
    ).to_a
    @parsed = false
    return unless @line_num

    @day = convert_ocr_number(@day)
    @month_abbr = get_month(@month)
    @month_number = MONTHS[@month_abbr]
    begin
      @date = Date.new(@year, @month_number, @day)
    rescue StandardError => e
      puts @line
      puts e.message
    end
    return unless @date

    @displaydate = @date.strftime('%e %B %Y').strip
    @formatdate = @date.to_s

    @line_num = @line_num.to_i
    @id = @id.to_f
    # handle -1/2 suffix on id
    @id += 0.5 if @half == '-1/2'
    @newspaper = @newspaper.to_sym
    @page = convert_ocr_number(@page)
    @column = convert_ocr_number(@column)
    @parsed = true
    # save normalized version of first line
    @normalized_line = "#{@line_num}|#{@id} - #{@newspaper} #{@month_abbr} #{@day}\
#{('\; ' + @type) unless @type.empty?}:#{@page}/#{@column}"
    @terms = []
    inches = @lines.last.match(/.*\((\d+)\)$/)
    @inches = inches ? inches[1].to_i : 0
  end
  
  def add_term(term)
    @terms << term
  end

  def merge!(obj)
    if obj[:heading] # it's a heading
      @heading = obj
    else
      @page_num = obj[:page_num]
    end
  end
  
  def displayId
    id.to_i.to_s + (id % 1 == 0.5 ? '-1/2' : '')
  end

  def to_hash
    {
      id: @id,
      displayid: self.displayId,
      metadata: @normalized_line,
      newspaper: @newspaper,
      month: @month_number,
      day: @day,
      displaydate: @displaydate,
      formatdate: @formatdate,
      page: @page,
      column: @column,
      type: @type,
      inches: @inches,
      lines: @lines,
      heading: @heading,
      terms: @terms
    }
  end

end
