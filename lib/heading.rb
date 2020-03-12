require './lib/utils.rb'
require 'slugify'

class Heading

  attr_reader :text, :type, :start, :slug, :parents, :targets

  def initialize(heading, prev_heading_key, year)
    @year = year
    @see_headings = {}

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
      @slug = @text.slugify.gsub(/\-+/, '')
    elsif text.match(/^[A-Z&',\- ]+[.,] See .*$/)
      # e.g. "ABANDONED CHILDREN. See Children"
      # handles heading and subheading1
      @type = 'see'
      @text, target = @text.match(/^([A-Z&',\- ]+)[.,] See (.*)$/).to_a[1..2]
      @text = titlecase(@text)
      @targets = []

      target.split('; ').each do |unit|
        heading, subheading1 = unit.split(/ #{OCRDASH} /)
        heading = titlecase(heading)
        reference = { heading: heading }
        reference[:subheading1] = subheading1 if subheading1
        @targets << reference
      end
    elsif @text.match(/^.* #{OCRDASH} See .*$/)
      # TODO: handle see abstract reference
      # e.g. "H Feb. 28:3/3 - See Streets"
      type = 'see abstract'
      abstract = Abstract.new(@text, @year, false)
      # TODO: find the abstract - maybe save abstracts in hash with normalized metadata as key, pointing to record number
      # TODO: handle @sees_map
      # @sees_map.add_obj(abstract.line_num, abstract)
      # TODO: save metadata
    elsif @text.match(/^See [Aa]l[s§][Qo] .*$/)
      # e.g. "See also Farm Products"
      @type = 'see also'
      @targets = []
      seealso = @text.sub(/^See [Aa]l[s§][Qo]/, '')
      seealso.split(';').each do |ref|
        ref.strip!
        if ref[0].match(/[A-Z]/)
          parts = ref.split('-')
          reference = {
            text: titlecase(parts[0].to_s.strip),
            slug: parts[0].to_s.strip.slugify.gsub(/-+/, '')
          }
          reference['subheading'] = titlecase(parts[1].to_s.strip)
          @targets << reference
        else
          # generic abstract like "names of animals"
          @targets << { generic: ref }
        end
      end
    elsif !@text.split(/\s+/)
               .map { |word| word.match(/\A[A-Za-z&][a-z']*\s*\z/) }
               .include?(nil)
      # text consists only of words (which may be
      # capitalized but not all caps): subheading1
      # e.g. "Book Stores"
      @type = 'subheading1'
      @text = titlecase(@text)
      @slug = @text.slugify.gsub(/\-+/, '')
    elsif !@text.gsub(/\A\((.*)\)\z/, '\1')
               .split(/\s+/)
               .map { |word| word.match(/\A[A-Za-z&][a-z']*,?\z/) }
               .include?(nil)
      # text consists only of words (which may be
      # capitalized but not all caps), in brackets: subheading2
      # e.g. "(Bandits & Guerrillas)"
      @type = 'subheading2'
      @text = titlecase(@text.gsub(/\A\((.*)\)\z/, '\1'))
      @slug = @text.slugify.gsub(/\-+/, '')
    end
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