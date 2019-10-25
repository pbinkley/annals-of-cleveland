# frozen_string_literal: true

# One entry in the volume
class Entry
  attr_reader :id, :init, :heading

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

  def initialize(context, line = nil, seq = nil, index = nil)
    @context = context
    if line.is_a? String
      metadata = line.match(
        %r{^(\d+)\ [-–]\ ([a-zA-Z]+)[\.,]?\ 
           ((?:Jan.|Feb.|Mar.|Apr.|May|June|July|Aug.|Sept.|Oct.|Nov.|Dec.))\ 
           (\d+)[;:,]+\ ?([a-zA-Z]*)[;:,]?\ ?(\d+)/(\d+)(.*)$}x
      )
      @context.linebuffer << line unless metadata
      if metadata
        if @context.preventry
          @context.preventry.store_lines @context.linebuffer
          @context.linebuffer = [line]
        end
        date = Date.new(@context.year, MONTHS[metadata[3]], metadata[4].to_i)

        @id = metadata[1].to_i
        @seq = seq
        @line = index
        @newspaper = metadata[2].to_sym
        @month = MONTHS[metadata[3]]
        @day = metadata[4].to_i
        @displaydate = date.strftime('%e %B %Y')
        @formatdate = date.to_s
        @page = metadata[6].to_i
        @column = metadata[7].to_i
        @type = metadata[5]
        @init = metadata[8]
        @heading = @context.heading
        @subheading = @context.subheading
        @terms = []

        @context.maxpage = @page if @page > @context.maxpage
        @context.maxcolumn = @column if @column > @context.maxcolumn

        @context.highest = @id if @id > @context.highest
        @context.breaks += 1 if @id != @context.prev + 1

        @context.prev = @id
      end
    else
      # must be an id of an empty entry
      @id = line
      @terms = []
    end
  end

  def store_lines(linebuffer)
    @lines = linebuffer
    inches = @lines.last.match(/.*\((\d+)\)$/)
    @inches = inches ? inches[1].to_i : 0

    @context.maxinches = @inches if @inches > @context.maxinches

    # capture issue for @context.preventry now that it is complete
    @context.issues[@formatdate] = {} unless @context.issues[@formatdate]
    @context.issues[@formatdate][@page] = {} unless @context.issues[@formatdate][@page]
    @context.issues[@formatdate][@page][@column] = [] unless @context.issues[@formatdate][@page][@column]
    @context.issues[@formatdate][@page][@column] << @id
  end

  def add_term(term)
    @terms << term
  end

  def to_html
    inchclass = @inches > 12 ? 'inchmore' : 'inch' + @inches.to_s
    "<div class='entry #{inchclass}'>
      <a title='#{@init.gsub('\"', '\\"')}'
        href='../../headings/#{@heading.gsub('&', 'and').slugify.gsub(/\-+/, '')}/##{@id}'>#{@id}</a>
      #{@type != '' ? ' (' + @type + ')' : ''}</div>"
  end

  def to_hash
    {
      id: @id,
      seq: @seq,
      line: @line,
      newspaper: @newspaper,
      month: @month,
      day: @day,
      displaydate: @displaydate,
      formatdate: @formatdate,
      page: @page,
      column: @column,
      type: @type,
      inches: @inches,
      init: @init,
      heading: @heading,
      subheading: @subheading,
      terms: @terms,
      lines: @lines
    }
  end
end
