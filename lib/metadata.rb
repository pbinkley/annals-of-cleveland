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

class Metadata

  attr_reader :line, :line_num, :id, :half, :newspaper, :month, :day,
              :type, :page, :column, :remainder, :date, :parsed,
              :normalized_line

  def initialize(metadata_string, year, with_id = true)
    @year = year
    @with_id = with_id

    @line, @line_num, @id, @half, @newspaper, @month, @day, @type, @page,
    @column, @remainder = (
      if @with_id then metadata_string.match(METADATA_REGEX_LINE_ID)
      else metadata_string.match(METADATA_REGEX_LINE)
      end
    ).to_a
    @parsed = false
    return unless @line_num

    @day = convert_ocr_number(@day)
    @month = get_month(@month)
    begin
      @date = Date.new(@year, MONTHS[@month], @day)
    rescue StandardError => e
      puts @line
      puts e.message
    end
    return unless @date

    @line_num = @line_num.to_i
    @id = @id.to_f
    # handle -1/2 suffix on id
    @id += 0.5 if @half == '-1/2'
    @newspaper = @newspaper.to_sym
    @month = MONTHS[@month]
    @displaydate = @date.strftime('%e %B %Y')
    @formatdate = @date.to_s
    @page = convert_ocr_number(@page)
    @column = convert_ocr_number(@column)
    @parsed = true
    # save normalized version of first line
    @normalized_line = "#{@line_num}|#{@id} - #{@newspaper} #{@month} #{@day}\
#{('\; ' + @type) unless @type.empty?}:#{@page}/#{@column}#{@remainder}"
  end

end
