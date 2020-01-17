# frozen_string_literal: true

require 'deepsort'
require './lib/utils.rb'

# manages a hash of objects parsed from the source text, keyed by line numbers
class TextMap

  attr_reader :units, :hash, :name

  def config  
    @unit_regex = nil
    @name = ''
  end
  
  def initialize(sections, section_name)
    self.config
    @sections = sections
    @section_name = section_name
    puts "#{@name} initialize"
    @text = @sections[@section_name]
    @hash = {}
    @units = @text.scan(@unit_regex).flatten
    self.parseUnits
    
    # postProcess may modify the text, e.g. removing page breaks
    self.postProcess(@sections[@section_name])
  end
  
  def add(line_num, obj)
    @hash[line_num.to_i] = obj
  end

  def parseUnits
  end
  
  def postProcess(text)
  end
  
  def merge_to(target)
    # merge objects from hash into objects in another TextMap, using line number ranges
    use = @name == 'TERMS' ? :id : :key

    @hash.keys.each_with_index do |key, index|
      case use
        when :key
          start = key
          start_next = @hash.keys.count > index ? @hash.keys[index + 1] : nil
          target.merge_from(key, start_next, @hash[key], use)
        when :id
          @hash[key][:ids].each do |id|
            target.merge_from(id, start_next, @hash[key], use)
          end
      end
    end
  end


  def merge_from(start, start_next, obj, use = :key)
    # select keys between start and start_next, or after start if start_next is nil
    case use
      when :key
        @hash
          .keys
          .select { |key| key >= start && (start_next ? key < start_next : true) }
          .each { |target_key| @hash[target_key].merge!(obj.dup) }

      when :id
        @hash
          .keys
          .select { |key| @hash[key].id == start }
          .each { |target_key| @hash[target_key].terms << obj.dup }
    end
  end

end

class PagesTextMap < TextMap

  def config
    @unit_regex = /
                \n#{NEWLINE}#{OCRDIGIT}+\s*\n
                #{NEWLINE}CLEVELAND\ NEWSPAPER.+?\n
                #{NEWLINE}Abstracts.+?\n
                #{NEWLINE}(?:.+Cont[[:punct:]]d\)|PLACEHOLDER)[\s[[:punct:]]]*\n
              /x
    @name = 'PAGES'
  end
  
  def parseUnits
    puts "#{@name} parsing pages"
    # Identify page breaks so that they can be removed
    @page_number_list = {}
    @units.each do |unit|
      next if unit == "\n"
      line_num, source_page = unit.match(/\A\n(\d+)\|(\d+).*\z/m).to_a[1..2]
      @page_number_list[source_page.to_i] = line_num.to_i
      self.add(line_num, source_page: source_page)
    end
    report_list(@page_number_list.keys, 'page')
  end

  def postProcess(text)
    # remove page-break lines from text
    @units.each do |unit|
      text.sub!(unit, "\n")
    end
    File.open('./intermediate/text-without-breaks.txt', 'w') { |f| f.puts text }
  end
  
  def count
    @page_number_list.keys.count
  end
  
end

class TermsPagesTextMap < TextMap

  def config
    @unit_regex = /
                \n#{NEWLINE}#{OCRDIGIT}+\s*\n
                #{NEWLINE}INDEX\ #{OCRDIGIT}+?\s*\n
              /x
    @name = 'TERMS PAGES'
  end
  
  def parseUnits
    puts "#{@name} parsing pages"
    # Identify page breaks so that they can be removed
    @page_number_list = {}
    @units.each do |unit|
      next if unit == "\n"
      line_num, source_page = unit.match(/\A\n(\d+)\|(\d+).*\z/m).to_a[1..2]
      @page_number_list[source_page.to_i] = line_num.to_i
      self.add(line_num, source_page: source_page)
    end
    report_list(@page_number_list.keys, 'page')
  end

  def postProcess(text)
    # remove page-break lines from text
    @units.each do |unit|
      text.sub!(unit, "\n")
    end
    File.open('./intermediate/text-without-terms-breaks.txt', 'w') { |f| f.puts text }
  end
  
  def count
    @page_number_list.keys.count
  end
  
end

class AbstractsTextMap < TextMap
  
  def config
    # returns array: ["full abstract", "-1/2" or nil] 
    @unit_regex = %r{
      ^(#{NEWLINE}#{OCRDIGIT}+(?:-1\/2)?\s*#{OCRDASH}\s*.+?\s*
      \(#{OCRDIGIT}+\))\s*$
    }mx
    @name = 'ABSTRACTS'
  end

  def parseUnits
    @year = 1845 # TODO: manage issue metadata
    @issues = {}
    
    parsed_abstracts = 0
    @abstract_number_list = []

    # parse metadata from first line of each abstract
    # canonical form:
    # 1234|5 - H July 14:3/1 - Samuel H. Barton, a mason by trade, an^ recently
    @units.each do |unit|
      lines = unit.split("\n")
      input_line = lines.first
      abstract = Abstract.new(lines, @year)
      self.add(abstract.line_num, abstract)
      @abstract_number_list << abstract.id
      
      self.addIssue(abstract)

      parsed_abstracts += 1 if abstract.parsed
      puts "#{@name} bad line: #{input_line}" unless abstract.parsed
    end

    puts "#{@name} Parsed: #{parsed_abstracts}/#{units.count}"

    report_list(@abstract_number_list, 'abstract')
    
    nil
  end

  def addIssue(abstract)
    @issues[abstract.formatdate] = {} unless @issues[abstract.formatdate]
    @issues[abstract.formatdate][abstract.page] = {} unless @issues[abstract.formatdate][abstract.page]
    @issues[abstract.formatdate][abstract.page][abstract.column] = [] unless @issues[abstract.formatdate][abstract.page][abstract.column]
    @issues[abstract.formatdate][abstract.page][abstract.column] << abstract.id
  end

  def abstractsData
    # sort keys
    abstracts_data = {}
    @hash.keys.sort.each do |key|
      this = @hash[key]
      abstracts_data[this.id] = this.to_hash
    end
    abstracts_data    
  end
  
  def issuesData
    # sort keys
    puts '#{@name} Sorting issues'
    @issues.deep_sort
  end
  
  def issuesCount
    @issues.count
  end
end

class HeadingsTextMap < TextMap
  
  def config
    @unit_regex = %r{(?:\(#{OCRDIGIT}+\)|\#START_ABSTRACTS)\s*$(.+?)^(?:#{NEWLINE}#{OCRDIGIT}+(?:\-1\/2)?
          \s#{OCRDASH}\s|\#END_ABSTRACTS)
        }mx
    @name = 'HEADINGS'
  end

  def parseUnits

    # empty lines look like: ["\n11968|\n"]
    units.reject! do |unit|
      unit.strip!
      unit == '' ||
        unit.match(/\A#{NEWLINE}\z/) ||
        unit.match(/\A#{NEWLINE}\+\+\+/)
    end

    @headings = []
    units.each do |unit|
      @headings << unit.gsub(/#{NEWLINE}\n/, '').strip
    end

    see_alsos = {}
    see_headings = {}
    unclassified = 0

    @headings.each do |heading|
      line_num, text = heading.match(/\A(#{NEWLINE})(.*)/)[1..2]
      # strip closing punctuation from text, leaving one punctuation mark
      # at end of string
      text.sub!(/\A(.+?[[:punct:]]?)[\s■[[:punct:]]]+\z/, '\1')
      line_num = line_num.sub('|', '').to_i
      heading_hash = { start: line_num, text: text }
      if text.match(/^===/)
        # TODO: handle text note
      elsif text.match(/^\+/)
        # text inserted by editor, with prefix of +, ++, or +++
        type = if text.match(/^\+\+\+ /)
                 'subheading2'
               elsif text.match(/^\+\+ /)
                 'subheading1'
               else
                 'heading'
               end
        text.gsub!(/^\++ /, '')
        heading_hash[:type] = type
        heading_hash[:text] = titlecase(heading_hash[:text])
        self.add(line_num, heading_hash)
      elsif text.match(/^[A-Z&',\- ]*[.\- ]*$/)
        # plain heading e.g. "SLAVERY"
        heading_hash[:text] = titlecase(heading_hash[:text].gsub(/[\.\-\ ]*$/, ''))
        heading_hash[:type] = 'heading'
        self.add(line_num, heading_hash)
      elsif text.match(/^[A-Z&',\- ]+[.,] See .*$/)
        # e.g. "ABANDONED CHILDREN. See Children"
        # handles heading and subheading1
        source, target = text.match(/^([A-Z&',\- ]+)[.,] See (.*)$/).to_a[1..2]
        target.split('; ').each do |unit|
          heading, subheading1 = unit.split(/ #{OCRDASH} /)
          heading = titlecase(heading)
          see_headings[source] = [] unless see_headings[source]
          reference = { heading: heading }
          reference[:subheading1] = subheading1 if subheading1
          see_headings[source] << reference
        end
      elsif text.match(/^.* #{OCRDASH} See .*$/)
        # TODO: handle see abstract reference
        # e.g. "H Feb. 28:3/3 - See Streets"
        abstract = Abstract.new(heading, @year, false)
        # TODO: find the abstract - maybe save abstracts in hash with normalized metadata as key, pointing to record number
        # TODO: handle @sees_map
        # @sees_map.add(abstract.line_num, abstract)
        # TODO: save metadata
      elsif text.match(/^See [Aa]l[s§][Qo] .*$/)
        # e.g. "See also Farm Products"
        seealso = text.sub('See also ', '')
        seealso.split(';').each do |ref|
          ref.strip!
          if ref[0].match(/[A-Z]/)
            parts = ref.split('-')
            reference = {
              'text' => titlecase = (parts[0].to_s.strip),
              'slug' => parts[0].to_s.strip.slugify.gsub(/-+/, '')
            }
            reference['subheading'] = titlecase(parts[1].to_s.strip)
            see_alsos[line_num] = reference
          else
            # generic abstract like "names of animals"
            see_alsos[line_num] = { generic: ref }
          end
        end
      elsif !text.split(/\s+/)
                 .map { |word| word.match(/\A[A-Za-z&][a-z]*\s*\z/) }
                 .include?(nil)
        # test whether text consists only of words, which may be
        # capitalized but not all caps
        heading_hash.merge!(type: 'subheading1', text: titlecase(text))
        self.add(line_num, heading_hash)
      elsif !text.gsub(/\A\((.*)\z/, '\1')
                 .split(/\s+/)
                 .map { |word| word.match(/\A[A-Za-z&][a-z]*\z/) }
                 .include?(nil)
        # test whether text consists only of words which may be
        # capitalized but not all caps, in brackets
        heading_hash.merge!(
          type: 'subheading2',
          text: titlecase(text.gsub(/\A\((.*)\z/, '\1'))
        )
        self.add(line_num, heading_hash)
      else
        puts "#{@name} Unclassified: #{line_num}|#{text}"
        unclassified += 1
      end
    end
    puts "#{@name} Unclassified: #{unclassified}"

    #@page_map.merge_to(@heading_map) # add page numbers to headings
    self.validate_headings
    #@heading_map.merge_to(@abstract_map)
    self.nest_headings
  end
  
  def merge_to(target)
    # heading objects are like { type: 'subheading2', text:'Finance' }
    @obj = { heading: 'dummy' }
    @hash.keys.sort.each_with_index do |key, index|
      this = @hash[key]
      case this[:type]
      when 'heading'
        @obj[:heading] = this[:text]
        @obj.delete(:subheading1)
        @obj.delete(:subheading2)
      when 'subheading1'
        @obj[:subheading1] = this[:text]
        @obj.delete(:subheading2)
      when 'subheading2'
        @obj[:subheading2] = this[:text]
      end
      # start_next = start of next item, if any
      start_next = @hash.keys.count > index ? @hash.keys[index + 1] : nil
      target.merge_from(key, start_next, @obj)
    end
  end

  def validate_headings
    # validate and nest headings

    # validation
    previous = nil
    @hash.keys.each_with_index do |key, index|
      this = @hash[key]
      if (index == 0) && (this[:type] != 'heading')
        puts "#{@name} Bad heading sequence: #{key}|#{this[:type]}|#{this[:text]} - first must be heading"
      end
      if previous
        # look for invalid sequence, i.e. subheading2 following heading
        if this[:type] == 'subheading2' && previous[:type] == 'heading'
          puts "#{@name} Bad heading sequence: #{key}|#{this[:type]}|#{this[:text]} - #{this[:type]} follows #{previous[:type]}"
        end
      end
      previous = this
    end
  end

  def nest_headings
    # nesting: roll up from the end
    # if subheading2: add it to the subheading2 array, remove from hash
    # if subheading1: add subheading2 array (if any) and clear it; add this to subheading1 array, remove from hash
    # if heading: add subheading1 array and clear it
    subheading1s = []
    subheading2s = []
    @hash.keys.reverse.each do |key|
      this = @hash[key]
      case this[:type]
      when 'subheading2'
        subheading2s << this
        @hash[key] = nil
      when 'subheading1'
        this[:subheading2] = subheading2s.reverse if subheading2s.count > 0
        subheading2s = []
        subheading1s << this
        @hash[key] = nil
      when 'heading'
        this[:subheading1] = subheading1s.reverse if subheading1s.count > 0
        subheading1s = []
      end
      @hash.compact! # remove nils
    end
  end

end

class TermsTextMap < TextMap
  
  def config
    # returns array: ["full abstract", "-1/2" or nil] 
    @unit_regex = /^(.*)$/
    @name = 'TERMS'
  end

  def parseUnits

    # handle index terms
    
    badCount = 0
    terms = {}
    units.each do |unit|
      next if unit =~ /^#{NEWLINE}$/ # ignore blank line
      line_num = unit.match(/^(\d*)\|.*/)[1].to_i
      unit.gsub!(/\ [\p{P}\p{S} ]*$/, '')
      unit.gsub!(/([0-9])\.\ ?([0-9])/, '\1\2') # remove period between digits
      
      elements = unit.match(/^#{NEWLINE}(.*)\, ([#{OCRDIGIT}\ \;\-\/]*)$/)
      seeref = unit.match(/^#{NEWLINE}(.+)\. See (.+)$/)
      continuation = unit.match(/^#{NEWLINE}[#{OCRDIGIT}\ -\/]*$/)
      ok = elements || seeref || continuation

      puts unit unless ok
      badCount += 1 unless ok
      next unless ok
      
      if elements
        term = elements[1].sub(/^#{NEWLINE}/, '')
        slug = term.slugify.gsub(/\-+/, '')
        ids = elements[2].split.each { |id| convert_ocr_number(id) }
        terms[term] = { slug: slug, ids: ids }
        previd = 0.0
        ids.each do |id|
          parts = id.split('-')
          id = parts[0].to_f
          # handle -1/2 suffix on id
          id += 0.5 if parts.count == 2 && parts[1] == '1/2'
          @hash[line_num] = { term: term, ids: [] } unless @hash[line_num]
          @hash[line_num][:ids] << id
          previd = id
        end
      else
        # TODO: handle seeref and continuation
      end
    end
    puts "Unparsed TERMS lines: #{badCount}"
  end
  
end