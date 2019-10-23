class Entry
  attr_reader :id, :init, :heading

  @@months = {
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
  }
  @@prev = 0

  def initialize(line = nil, seq = nil, index = nil)
    if line.is_a? String
      metadata = line.match(/^(\d+) [-–] ([a-zA-Z]+)[\.,]? ((?:Jan.|Feb.|Mar.|Apr.|May|June|July|Aug.|Sept.|Oct.|Nov.|Dec.)) (\d+)[;:,]+\ ?([a-zA-Z]*)[;:,]?\ ?(\d+)\/(\d+)(.*)$/)
      $linebuffer << line unless metadata
      return nil unless metadata
      if $preventry
        $preventry.setLines $linebuffer
        
        $linebuffer = [line]
      end
      date = Date.new($year, @@months[metadata[3]], metadata[4].to_i)
      
      @id = metadata[1].to_i
      @seq = seq
      @line = index
      @newspaper = metadata[2].to_sym
      @month = @@months[metadata[3]]
      @day = metadata[4].to_i
      @displaydate = date.strftime('%e %B %Y')
      @formatdate = date.to_s
      @page = metadata[6].to_i
      @column = metadata[7].to_i
      @type = metadata[5]
      @init = metadata[8]
      @heading = $heading
      @subheading = $subheading
      @terms = []

      $maxpage = @page if @page > $maxpage
      $maxcolumn = @column if @column > $maxcolumn

      $highest = @id if @id > $highest
      $breaks += 1 if @id != @@prev + 1

      @@prev = @id
    else
      # must be an id of an empty entry
      @id = line
      @terms = []
    end
  end

  def setLines(linebuffer)
    @lines = linebuffer
    inches = @lines.last.match(/.*\((\d+)\)$/)
    if inches
      @inches = inches[1].to_i
    else
      @inches = 0
    end
    
    $maxinches = @inches if @inches > $maxinches

    # capture issue for $preventry now that it is complete
    $issues[@formatdate]= {} unless $issues[@formatdate]
    $issues[@formatdate][@page] = {} unless $issues[@formatdate][@page]
    $issues[@formatdate][@page][@column] = [] unless $issues[@formatdate][@page][@column]
    $issues[@formatdate][@page][@column] << @id

  end

  def addTerm(term)
    @terms << term
  end

  def to_html
    inchclass = @inches > 12 ? 'inchmore' : 'inch' + @inches.to_s
    "<div class='entry #{inchclass}'>
      <a title='#{ @init.gsub('\"', '\\"') }' href='../../headings/#{@heading.slugify.gsub(/\-+/, '')}/##{@id.to_s}''>#{@id.to_s}</a>
      #{@type != '' ? ' (' + @type + ')' : ''}
    </div>"
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

