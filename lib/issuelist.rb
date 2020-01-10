# frozen_string_literal: true

require 'byebug'

class IssueList

  attr_reader :list

  def initialize
    @list = {}
  end

  def addAbstract (abstract)  
#    @context.maxinches = @inches if @inches > @context.maxinches

    @list[abstract.formatdate] = {} unless @list[abstract.formatdate]
    @list[abstract.formatdate][abstract.page] = {} unless @list[abstract.formatdate][abstract.page]
    @list[abstract.formatdate][abstract.page][abstract.column] = [] unless @list[abstract.formatdate][abstract.page][abstract.column]
    @list[abstract.formatdate][abstract.page][abstract.column] << abstract.id
  end

end
