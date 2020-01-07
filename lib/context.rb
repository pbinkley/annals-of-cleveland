# frozen_string_literal: true

# Container for working context, to be passed to Entry objects
class Context
  attr_accessor :year, :prevabstract, :linebuffer, :heading, :subheading1, :subheading2,
                :breaks, :highest, :issues, :maxinches, :maxpage,
                :maxcolumn, :prev

  def initialize
    @year = 1864
    @prevabstract = nil
    @linebuffer = []
    @heading = ''
    @subheading1 = ''
    @subheading2 = ''
    @breaks = 0
    @highest = 0
    @issues = {}
    @maxinches = 0
    @maxpage = 0
    @maxcolumn = 0
    @prev = 0
  end
end
