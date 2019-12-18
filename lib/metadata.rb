# frozen_string_literal: true

require 'damerau-levenshtein'
require './lib/utils.rb'

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

  attr_reader :line, :lineNum, :id, :half, :newspaper, :month, :day,
              :type, :page, :column, :remainder, :date, :parsed,
              :normalized_line

  def initialize(metadata_string, year, entry_number_list)
    @year = year
    @entry_number_list = entry_number_list

    @line, @line_num, @id, @half, @newspaper, @month, @day, @type, @page,
    @column, @remainder = metadata_string.match(
      %r{^(\d+)\|(\d+)(-1\/2)?\s       # '1234/123-1/2' line and entry
         #{OCRDASH}+\ ([a-zA-Z]+)[\.,]?\s   # '- H' newspaper
         (\S+)\s                         #month
         (#{OCRDIGIT}+)#{OCRCOLON}+\s?        # '2:' day
         ([a-zA-Z]*)#{OCRCOLON}?\s?        # 'ed' type (ed, adv)
         (#{OCRDIGIT}+)[/"'](#{OCRDIGIT}+)(.*)$         # '2/3' page and column
      }x
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
    @entry_number_list << @id
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
