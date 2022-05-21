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
        ([a-zA-Z]+)[\\.,]?\\s             # 'H' newspaper
        (\\S+)\\s                         # 'Dec.': month
        (#{OCRDIGIT}+)#{OCRCOLON}+\\s?    # '2:' day
        ([a-zA-Z]*)#{OCRCOLON}?\\s?       # 'ed' type (ed, adv)
        (
          (?:
            #{OCRDIGIT}+[/\"']#{OCRDIGIT}+   # '2/3' page/column
            (?:[,-]#{OCRDIGIT}+)?
            (?:,\\s)?
          )+
        )
        (.*)$           # ',2' or '-3': sequence or range
"

METADATA_REGEX_LINE_ID = %r{
  #{METADATA_LINE_ID}
  #{METADATA_FIELDS}
}x.freeze

METADATA_REGEX_LINE = %r{
  #{METADATA_LINE}
  #{METADATA_FIELDS}
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

  attr_reader :line, :line_num, :id, :half, :inches, :newspaper, :month, :day,
              :type, :blocks, :blocksarray, :remainder, :date, :formatdate, :parsed,
              :normalized_metadata, :source_page, :heading, :terms, :init, :xref_heading

  def initialize(lines, year, with_id = true)
    @year = year
    @lines = lines
    @with_id = with_id

    metadata_string = @lines[0]

    @line, @line_num, @id, @half, @newspaper, @month, @day, @type, @blocks,
    @remainder = (
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
    @display_id = id.to_i.to_s + (id % 1 == 0.5 ? '-1/2' : '')
    @newspaper = @newspaper.to_sym
    @x = @blocks.dup
    @xref_heading = nil
    @blocks = parse_blocks(@blocks)
    @blocksarray = []
    @blocks.keys.sort.each do |page|
      @blocksarray << { page: page, columns: @blocks[page] }
    end
    @parsed = true
    # save normalized version of first line
    normalized_blocks = []
    @blocksarray.each do |page|
      normalized_blocks << "#{page[:page]}/#{page[:columns].map(&:to_s).join(',')}"
    end
    @normalized_metadata = "#{@newspaper} #{@month_abbr} #{@day}\
#{('\; ' + @type) unless @type.empty?}:#{normalized_blocks.join(';')}"
    @init = @remainder.sub(/^ - /, '')
    # 1845: if not @with_id, @init is an xref e.g. "See Streets"
      # might have subheading e.g. "See Organizations - Cultural"
    @xref_heading = @init.sub(/^See /, '').strip.split(' - ') if @init.start_with?('See ')

    @terms = []
    inches = @lines.last.match(/.*\((\d+)\)[\s[[:punct:]]]*$/)
    @inches = inches ? inches[1].to_i : 0
    # strip line numbers
    @lines.map! { |line| line.sub(/^\d+\|/, '') }
    # byebug if @xref_heading
  end

  def parse_blocks(blocks)
    output = {}
    @column_count = 0
    blocks.split(', ').each do |block|
      page, column, range_type, range_end =
        block.match(/(#{OCRDIGIT}+)[\/\\\'\"](#{OCRDIGIT}+)([,-])?(#{OCRDIGIT}+)?/).to_a[1..4]
      page = convert_ocr_number(page)
      column = convert_ocr_number(column)
      columns = [column]
      case range_type
      when ','
        columns << convert_ocr_number(range_end)
      when '-'
        range_end = convert_ocr_number(range_end)
        columns += (column + 1..range_end).to_a
      end
      @column_count += columns.count
      output[page] = columns
    end
    output
  end

  def add_term(term)
    @terms << term
  end

  def merge!(obj)
    if obj[:type].to_s.match(/heading|subheading1|subheading2/) # it's a heading
      @heading = obj
    else
      @source_page = obj[:source_page]
    end
  end

  def to_hash
    {
      id: @id,
      displayid: @display_id,
      line_num: @line_num,
      metadata: @normalized_metadata,
      newspaper: @newspaper,
      month: @month_number,
      day: @day,
      displaydate: @displaydate,
      formatdate: @formatdate,
      blocks: @blocks,
      blocksarray: @blocksarray,
      type: @type,
      inches: @inches,
      init: @init,
      lines: @lines,
      heading: @heading,
      terms: @terms,
      source_page: @source_page,
      xref_heading: @xref_heading
    }
  end

  def to_html
    inches_per_column = (@inches / @column_count).round
    inchclass = inches_per_column > 12 ? 'inchmore' : 'inch' + inches_per_column.to_s
    @heading ||= { heading: 'dummy' } # TODO: make sure all abstracts get heading

    "<div class='abstract #{inchclass}'>
      <a title='#{@init.gsub('\"', '\\"')}'
        href='/headings/#{@heading[:path]}/##{@display_id}'>#{@display_id}</a>
      #{@type != '' ? ' (' + @type + ')' : ''}</div>"
  end

end
