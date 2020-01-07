# frozen_string_literal: true

# One abstract in the volume
class Entry
  attr_reader :id, :init, :heading, :subheading1, :subheading2, :inches

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
        %r{^(\d+)(-1/2)?\ [-–.]+\ ([a-zA-Z]+)[\.,]?\s
           ((?:Jan.|Feb.|Mar.|Apr.|May|June|July|Aug.|Sept.|Oct.|Nov.|Dec.))\s
           (\d+)[;:,.]+\ ?([a-zA-Z]*)[;:,.]?\ ?(\d+)[/"'](\d+)(.*)$}x
      )
      @context.linebuffer << line unless metadata
      if metadata
        if @context.prevabstract
          @context.prevabstract.store_lines @context.linebuffer
          @context.linebuffer = [line]
        end
        date = Date.new(@context.year, MONTHS[metadata[4]], metadata[5].to_i)

        @id = metadata[1].to_f
        # handle -1/2 suffix on id
        @id += 0.5 if metadata[2] == '-1/2'

        @seq = seq
        @line = index
        @newspaper = metadata[3].to_sym
        @month = MONTHS[metadata[4]]
        @day = metadata[5].to_i
        @displaydate = date.strftime('%e %B %Y')
        @formatdate = date.to_s
        @page = metadata[7].to_i
        @column = metadata[8].to_i
        @type = metadata[6]
        @init = metadata[9]
        @heading = @context.heading
        @subheading1 = @context.subheading1
        @subheading2 = @context.subheading2
        @terms = []

        @context.maxpage = @page if @page > @context.maxpage
        @context.maxcolumn = @column if @column > @context.maxcolumn

        @context.highest = @id if @id > @context.highest
        # TODO: make sure the half items don't mess this up
        @context.breaks += 1 if (@id - @context.prev) > 1.0

        @context.prev = @id
      end
    else
      # note: this is never being called
      # must be an id of an empty abstract
      @id = line
      # TODO: handle half items
      @terms = []
    end
  end

  def store_lines(linebuffer)
    @lines = linebuffer

    # last line might be a subheading: line of text with no digits TODO: tighter definition
    if @lines.last.match(/^[a-zA-Z\ \(\)\-]+$/)
      @context.subheading1 = @lines.last
      @lines.pop # remove last line
    end

    inches = @lines.last.match(/.*\((\d+)\)$/)
    @inches = inches ? inches[1].to_i : 0

    @context.maxinches = @inches if @inches > @context.maxinches

    # capture issue for @context.prevabstract now that it is complete
    @context.issues[@formatdate] = {} unless @context.issues[@formatdate]
    @context.issues[@formatdate][@page] = {} unless @context.issues[@formatdate][@page]
    @context.issues[@formatdate][@page][@column] = [] unless @context.issues[@formatdate][@page][@column]
    @context.issues[@formatdate][@page][@column] << @id
  end

  def add_term(term)
    @terms << term
  end

  def displayId
    id.to_i.to_s + (id % 1 == 0.5 ? '-1/2' : '')
  end
  
  def to_html
    display_id = displayId
    inchclass = @inches > 12 ? 'inchmore' : 'inch' + @inches.to_s
    "<div class='abstract #{inchclass}'>
      <a title='#{@init.gsub('\"', '\\"')}'
        href='../../headings/#{@heading.gsub('&', 'and').slugify.gsub(/\-+/, '')}/##{display_id}'>#{display_id}</a>
      #{@type != '' ? ' (' + @type + ')' : ''}</div>"
  end

  def to_hash
    {
      id: @id,
      displayid: self.displayId,
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
      terms: @terms,
      lines: @lines
    }
  end
end
