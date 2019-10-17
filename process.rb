#!/usr/bin/env ruby

require 'nokogiri'
require 'csv'
require 'byebug'

months = {
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

doc = File.open("source/view-source_https___babel.hathitrust.org_cgi_ssd_id=iau.31858046133199#seq109.html") { |f| Nokogiri::HTML(f) }

pages = doc.xpath('//div[@class="Page"]')
entries = []
prev = 0

pages.each do |page|
  seq = page.xpath('./@id').first.text
  lines = page.xpath('./p[@class="Text"]').first.text.split(/\n+/)
  lines.each_with_index do |line, index|
    metadata = line.match(/^(\d+) [-–] L\.? ((?:Jan.|Feb.|Mar.|Apr.|May|June|July|Aug.|Sept.|Oct.|Nov.|Dec.)) (\d+)[;:,]+\ ?([a-zA-Z]*):?\ ?(\d+)\/(\d+)(.*)$/)
    next unless metadata
    record = {
      id: metadata[1].to_i,
      seq: seq,
      line: index,
      month: months[metadata[2]],
      day: metadata[3].to_i,
      page: metadata[5].to_i,
      column: metadata[6].to_i,
      type: metadata[4],
      init: metadata[7]
    }
    entries << record
    if record[:id] != prev + 1
      puts 'break'
    end
    puts record[:id].to_s
    prev = record[:id]
  end
end

CSV.open("data.csv", "wb") do |csv|
  csv << entries.first.keys # adds the attributes name on the first line
  entries.each do |hash|
    csv << hash.values
  end
end
