require './lib/utils.rb'
require './lib/abstract.rb'

class Heading

  attr_reader :text, :type, :start, :slug, :parents, :targets, :abstract, :target_abstracts

  def initialize(heading, prev_heading_key, year, abstracts)
    @year = year
    @see_headings = []
    @target_abstracts = []
    line_num, text = heading.match(/\A(#{NEWLINE})(.*)/)[1..2]
    @start = line_num.sub('|', '').to_i
    # strip closing punctuation from text, leaving one punctuation mark
    # at end of string
    text += ' '
    @text = text.sub!(/\A(.+?[[:punct:]]?)[\s■\º[[:punct:]]]+\z/, '\1')

    if @text.match(/^===/)
      # TODO: handle text note
    elsif @text.match(/^\+/)
      # text inserted by editor, with prefix of +, ++, or +++
      @type = if @text.match(/^\+\+\+ /)
               'subheading2'
             elsif @text.match(/^\+\+ /)
               'subheading1'
             else
               'heading'
             end
      @text = titlecase(@text.gsub!(/^\++ /, ''))
    elsif @text.match(/^[A-Z&',\- ]*[.\- ]*$/)
      # plain heading e.g. "SLAVERY"
      @type = 'heading'
      @text = titlecase(@text.gsub(/[\.\-\ ]*$/, ''))
      @slug = filenamify(@text)
    elsif text.match(/^[A-Z&',\- ]+[.,] See .*$/)
      # e.g. "ABANDONED CHILDREN. See Children"
      # handles heading and subheading1
      @type = 'see'
      @text, target = @text.match(/^([A-Z&',\- ]+)[.,] See (.*)$/).to_a[1..2]
      @text = titlecase(@text)
      @targets = parse_targets(target)
    elsif @text.match(/^.* #{OCRDASH} See .*$/)
      # e.g. "H Feb. 28:3/3 - See Streets" in 1845
      # this needs to be treated as an unnumbered abstract
      # it points to two abstracts under Streets, 1916 and 1917
      @type = 'see abstract'
      @abstract = Abstract.new([heading], @year) # full abstract with normalized metadata
      # insert abstract using insertion id
      @abstract.set_id(id_for_insertion(abstracts.hash))
      abstracts.hash[@abstract.line_num] = @abstract
      @targets = parse_targets(@text.sub(/^.* See /, '')) # array of heading/subheadings
      # TODO: will use @normalized_metadata to look up abstract
    elsif @text.match(/^See [Aa]l[s§][Qo] .*$/)
      # e.g. "See also Farm Products"
      # e.g. "See also Iron &amp; Steel - Labor; Labor Unions: Newspapers - Labor"
      @type = 'see also'
      @text = @text.sub(/^See [Aa]l[s§][Qo]/, '').strip
      @targets = parse_targets(@text)
    elsif !@text.split(/\s+/)
               .map { |word| word.match(/\A[A-Za-z&][a-z']*\s*\z/) }
               .include?(nil)
      # text consists only of words (which may be
      # capitalized but not all caps): subheading1
      # e.g. "Book Stores"
      @type = 'subheading1'
      @text = titlecase(@text)
      @slug = filenamify(@text)
    elsif !@text.gsub(/\A\((.*)\)\z/, '\1')
               .split(/\s+/)
               .map { |word| word.match(/\A[A-Za-z&][a-z']*,?\z/) }
               .include?(nil)
      # text consists only of words (which may be
      # capitalized but not all caps), in brackets: subheading2
      # e.g. "(Bandits & Guerrillas)"
      @type = 'subheading2'
      @text = titlecase(@text.gsub(/\A\((.*)\)\z/, '\1'))
      @slug = filenamify(@text)
    end
  end
  
  def parse_targets(target)
    target = target.gsub(/\s+/, ' ').strip.gsub('&', 'and')
    targets = []
    if target.match(/[A-Z]/)
      target.split(/[;:]\ /).each do |unit|
        heading, subheading1 = unit.split(/ #{OCRDASH} /)
        heading = titlecase(heading)
        reference = {
          'text' => unit,
          'path' => filenamify(heading),
          'heading' => titlecase(heading),
          'slug' => filenamify(heading)
        }
        if subheading1
          reference['subheading1'] = subheading1 
          reference['path'] += "/#{filenamify(subheading1)}"
        end
        targets << reference
      end
    else
      # generic abstract like "names of animals"
      targets << { generic: target }
    end
    targets
  end

  def set_parents(parents)
    @parents = parents
  end

  def set_slug(slug)
    @slug = slug
  end

  def set_path(path)
    @path = path
  end

  def add_see_heading(see)
    @see_headings << see
  end

  def add_target_abstract(abstract)
    @target_abstracts << abstract
  end
  
  def set_target_abstracts(ta)
    @target_abstracts = ta
  end

  def id_for_insertion(abstract_hash)
    keys = abstract_hash.keys.sort + [9999999] # integer line numbers
    index = keys.bsearch_index { |key| key > @start }
    id = (index == 0) ? 0 : abstract_hash[keys[index-1]].id
    str = "%.4f" % id
    whole, fraction, insertion = str.match(/(\d+)\.(\d{2})(\d{2})/).to_a[1,3]
      .map { |i| i.to_i }
    whole + fraction/100.0 + (insertion + 1)/10000.0
  end

  def to_hash
    h = {
      type: @type,
      text: @text,
      start: @start,
      end: @end,
      slug: @slug,
      path: @path,
      see_headings: @see_headings,
      targets: @targets
    }
    
    h[:parents] = @parents if @parents

    h
  end

end