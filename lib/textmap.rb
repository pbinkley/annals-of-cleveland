# frozen_string_literal: true

require 'deepsort'
require './lib/utils.rb'
require './lib/heading.rb'

# manages a hash of objects parsed from the source text, keyed by line numbers
class TextMap

  attr_reader :units, :hash, :name

  def config
    @unit_regex = nil
    @name = ''
  end

  def initialize(sections, section_name)
    config
    @sections = sections
    @section_name = section_name
    puts "\n#{@name} section"
    @text = @sections[@section_name]
    @hash = {}
    @units = @text.scan(@unit_regex).flatten
    parse_units

    # post_process may modify the text, e.g. removing page breaks
    post_process(@sections[@section_name])
  end

  def add_obj(line_num, obj)
    @hash[line_num.to_i] = obj
  end

  def parse_units
  end

  def post_process(text)
  end

  def merge_to(target)
    # merge objects from hash into objects in another TextMap, using line number ranges
    use = @name == 'TERMS' ? :id : :key

    @hash.keys.each_with_index do |key, index|
      case use
      when :key
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
    target_list = []
    # byebug unless start
    case use
    when :key
      @hash
        .keys
        .select { |key| key >= start && (!start_next.nil? ? key < start_next : true) }
        .each do |target_key|
          @hash[target_key].merge!(obj.dup)
          target_list << @hash[target_key].id if @hash[target_key].is_a? Abstract
        end
    when :id
      @hash
        .keys
        .select { |key| @hash[key].id == start }
        .each { |target_key| @hash[target_key].terms << obj.dup }
    end
    target_list
  end

end

# TextMap that needs to know the year
class YearTextMap < TextMap

  def initialize(sections, section_name, year)
    @year = year
    super(sections, section_name)
  end

end

class PagesTextMap < YearTextMap

  def config
    @unit_regex = /
                \n#{NEWLINE}[\s[[:punct:]]]*#{OCRDIGIT}+[\s[[:punct:]]]*\n
                #{NEWLINE}[cC]LEVELAND\ NEWSPAPER.+?\n
                #{NEWLINE}Abstract.*\n
                (?:#{NEWLINE}(?:.+\(Co[rn]t[[:punct:]]d\)|PLACEHOLDER)[\s[[:punct:]]]*\n)?
              /x
    @name = 'PAGES'
  end

  def parse_units
    puts "#{@name} parsing pages"
    # Identify page breaks so that they can be removed
    @page_number_list = {}
    @units.each do |unit|
      next if unit == "\n"

      line_num, source_page = unit.match(/\A\n(\d+)\|[^\d]*(\d+).*\z/m).to_a[1..2]
      @page_number_list[source_page.to_i] = line_num.to_i
      add_obj(line_num, source_page: source_page)
    end
    puts "Page breaks found: #{@units.length}"
    report_list(@page_number_list.keys, 'page')
  end

  def post_process(text)
    # remove page-break lines from text
    before_length = text.length
    @units.each do |unit|
      text.sub!(unit, "\n")
    end
    lines_deleted = before_length - text.length
    puts("Lines deleted: #{lines_deleted}")

    File.open("./intermediate/#{@year}/text-without-breaks.txt", 'w') { |f| f.puts text }
  end

  def count
    @page_number_list.keys.count
  end

end

class TermsPagesTextMap < YearTextMap

  def config
    @unit_regex = /
                \n#{NEWLINE}#{OCRDIGIT}+\s*\n
                #{NEWLINE}INDEX\ #{OCRDIGIT}+?\s*\n
              /x
    @name = 'TERMS PAGES'
  end

  def parse_units
    puts "#{@name} parsing pages"
    # Identify page breaks so that they can be removed
    @page_number_list = {}
    @units.each do |unit|
      next if unit == "\n"

      line_num, source_page = unit.match(/\A\n(\d+)\|(\d+).*\z/m).to_a[1..2]
      @page_number_list[source_page.to_i] = line_num.to_i
      add_obj(line_num, source_page: source_page)
    end
    report_list(@page_number_list.keys, 'page')
  end

  def post_process(text)
    # remove page-break lines from text
    @units.each do |unit|
      text.sub!(unit, "\n")
    end
    File.open("./intermediate/#{@year}/text-without-terms-breaks.txt", 'w') { |f| f.puts text }
  end

  def count
    @page_number_list.keys.count
  end

end

class AbstractsTextMap < YearTextMap

  def config
    # returns array: ["full abstract", "-1/2" or nil]
    @unit_regex = %r{
      ^(#{NEWLINE}#{OCRDIGIT}+(?:-1\/2)?\s*#{OCRDASH}+\s*.+?\s*
      \(#{OCRDIGIT}+\))[\s[[:punct:]]]*$
    }mx
    @name = 'ABSTRACTS'
  end

  def parse_units
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
      add_obj(abstract.line_num, abstract)
      @abstract_number_list << abstract.id

      add_issue(abstract)

      parsed_abstracts += 1 if abstract.parsed
      puts "#{@name} bad line: #{input_line}" unless abstract.parsed
    end

    puts "#{@name} Parsed: #{parsed_abstracts}/#{units.count}"

    report_list(@abstract_number_list, 'abstract')

    nil
  end

  def add_issue(abstract)
    @issues[abstract.formatdate] ||= {}
    abstract.blocks.keys.each do |page|
      thispage = abstract.blocks[page]
      @issues[abstract.formatdate][page] ||= {}
      thispage.each do |column|
        @issues[abstract.formatdate][page][column] ||= []
        @issues[abstract.formatdate][page][column] << abstract.id
      end
    end
  end

  def abstracts_data
    # sort keys
    abstracts_data = {}
    @hash.keys.sort.each do |key|
      this = @hash[key]
      abstracts_data[this.id] = this.to_hash
    end
    abstracts_data
  end

  def issues_data
    # sort keys
    puts "#{@name} Sorting issues"
    @issues.deep_sort
  end

  def issuesCount
    @issues.count
  end

end

class HeadingsTextMap < YearTextMap

  def config
    @unit_regex = %r{
      (?:\(#{OCRDIGIT}+\)|\#START_ABSTRACTS)\s*$  # (1)\n: end of prev abstract
      (.+?)                                       # content of heading
      ^(?:#{NEWLINE}#{OCRDIGIT}+(?:\-1\/2)?
          \s#{OCRDASH}+\s|\#END_ABSTRACTS)         # start of next heading
      }mx
    @name = 'HEADINGS'
  end

  def parse_units
    # empty lines look like: ["\n11968|\n"]
    units.reject! do |unit|
      unit.strip!
      unit == '' ||
        unit.match(/\A#{NEWLINE}\z/) ||
        unit.match(/\A#{NEWLINE}\+\+\+/)
    end

    @headings = []
    units.each do |unit|
      @headings += unit.split("\n")
    end

    see_alsos = []
    see_headings = []
    unclassified = 0
    prev_heading_key = nil

    most_recent = {}

    # TODO: handle crossrefs like L July 1: 1/2-7 - CLEVELAND MORNING LEADER July 1, 1864 (9)
    @headings.each do |heading_text|
      heading = Heading.new(heading_text, prev_heading_key, @year)

      if !heading.type
        puts "#{@name} Unclassified: #{heading.start}|#{heading_text}"
        unclassified += 1
      elsif heading.type == 'see abstract'
        # target_abstract = @abstracts.select { |abstract| abstract.normalized_metadata = heading.abstract.normalized_metadata }
        # TODO: this seems to be where I left it
        puts "see abstract: #{heading.abstract.normalized_metadata} | #{heading.targets}"
      else
        # now we add properties that derive from the context and not from within this heading
        @hash[prev_heading_key][:end] = heading.start if prev_heading_key

        if heading.type == 'subheading2'
          heading.set_parents([most_recent['heading'], most_recent['subheading1']])
        elsif heading.type == 'subheading1'
          heading.set_parents([most_recent['heading']])
        end

        if heading.slug
          path = ''
          heading.parents.to_a.each { |x| path += filenamify(x) + '/' }
          path += filenamify(heading.text)
          heading.set_path(path)
         # byebug if heading.parents.to_a.count > 1
        end

        most_recent[heading.type] = heading.text
        add_obj(heading.start, heading.to_hash)
        prev_heading_key = heading.start
      end
    end
    puts "#{@name} Unclassified: #{unclassified}"
    validate_headings
    nest_headings
  end

  def merge_heading(target, heading)
    # like {:start=>372, :text=>"Alcoholic Liquors", :type=>"heading", :children=>[{:start=>376, :text=>"Taxation", :type=>"subheading1", :slug=>"taxation", :parents=>["Alcoholic Liquors"]}], :source_page=>"1", :abstracts=>[6.0, 7.0, 8.0, 9.0, 10.0]}
    heading_end = heading[:end] || nil
    target_list = target.merge_from(heading[:start], heading_end, heading.dup)
    heading[:abstracts] = target_list
    # apply merge_to to children
    heading[:children].to_a.each do |child|
      merge_heading(target, child)
    end
  end

  def merge_to(target)
    # only merge headings, not see or see also etc.
    @hash.keys.sort.each do |key|
      merge_heading(target, @hash[key]) if @hash[key][:type] == 'heading'
    end
  end

  def validate_headings
    # validation
    previous = nil
    @hash.keys.each_with_index do |key, index|
      this = @hash[key]
      if (index == 0) && !(this[:type].match(/heading|see/))
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
        this[:children] = subheading2s.reverse if subheading2s.count > 0
        subheading2s = []
        subheading1s << this
        @hash[key] = nil
      when 'heading'
        this[:children] = subheading1s.reverse if subheading1s.count > 0
        subheading1s = []
      end
      @hash.compact! # remove nils
    end
  end

  def headings_data
    # sort keys
    headings_data = {}
    @hash.keys.sort.each do |key|
      this = @hash[key]
      headings_data[this[:text]] = this.to_hash
    end
    headings_data
  end

end

class TermsTextMap < TextMap

  def config
    # returns array: ["full abstract", "-1/2" or nil]
    @unit_regex = /^(.*)$/
    @name = 'TERMS'
  end

  def parse_units
    # handle index terms

    bad_count = 0
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
      bad_count += 1 unless ok
      next unless ok

      if elements
        term = elements[1].sub(/^#{NEWLINE}/, '')
        slug = filenamify(term)
        ids = elements[2].split.each { |id| convert_ocr_number(id) }
        terms[term] = { slug: slug, ids: ids }
        previd = 0.0
        ids.each do |id|
          parts = id.split('-')
          id = parts[0].to_f
          # handle -1/2 suffix on id
          id += 0.5 if parts.count == 2 && parts[1] == '1/2'
          @hash[line_num] = { term: term, slug: slug, ids: [] } unless @hash[line_num]
          @hash[line_num][:ids] << id
          previd = id
        end
      else
        # TODO: handle seeref and continuation
      end
    end
    puts "Unparsed TERMS lines: #{bad_count}"
  end

  def terms_data
    # sort keys
    terms_data = {}
    @hash.keys.sort.each do |key|
      this = @hash[key]
      terms_data[this[:term]] = this.to_hash
    end
    terms_data
  end

end
