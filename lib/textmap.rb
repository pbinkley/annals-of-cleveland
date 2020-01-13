# frozen_string_literal: true

require 'deepsort'

# manages a hash of objects parsed from the source text, keyed by line numbers
class TextMap

  attr_reader :hash, :name

  def initialize(name)
    @name = name
    @hash = {}
  end

  def add(line_num, obj)
    @hash[line_num.to_i] = obj
  end

  def merge_to(target)
    # merge objects from hash into objects in another TextMap, using line number ranges

    @hash.keys.each_with_index do |key, index|
      start_next = @hash.keys.count > index ? @hash.keys[index + 1] : nil
      target.merge_from(key, start_next, @hash[key])
    end
  end


  def merge_from(start, start_next, obj)
    # select keys between start and start_next, or after start if start_next is nil
    @hash
      .keys
      .select { |key| key >= start && (start_next ? key < start_next : true) }
      .each { |target_key| @hash[target_key].merge!(obj.dup) }
  end

end

class HeadingsTextMap < TextMap
  
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
        puts "Bad heading sequence: #{key}|#{this[:type]}|#{this[:text]} - first must be heading"
      end
      if previous
        # look for invalid sequence, i.e. subheading2 following heading
        if this[:type] == 'subheading2' && previous[:type] == 'heading'
          puts "Bad heading sequence: #{key}|#{this[:type]}|#{this[:text]} - #{this[:type]} follows #{previous[:type]}"
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

class IssuesTextMap < TextMap
  
  attr_reader :name

  def addAbstract (abstract)  
#    @context.maxinches = @inches if @inches > @context.maxinches

    @hash[abstract.formatdate] = {} unless @hash[abstract.formatdate]
    @hash[abstract.formatdate][abstract.page] = {} unless @hash[abstract.formatdate][abstract.page]
    @hash[abstract.formatdate][abstract.page][abstract.column] = [] unless @hash[abstract.formatdate][abstract.page][abstract.column]
    @hash[abstract.formatdate][abstract.page][abstract.column] << abstract.id
  end

  def hash
    # sort keys
    puts 'Sorting hash'
    @hash.deep_sort
  end
  
end

class AbstractsTextMap < TextMap
  
  def data
    abstracts_data = {}
    @hash.keys.sort.each do |key|
      this = @hash[key]
      abstracts_data[this.id] = this.to_hash
    end
    abstracts_data    
  end
  
end