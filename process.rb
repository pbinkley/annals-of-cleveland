#!/usr/bin/env ruby

require 'nokogiri'
require 'slugify'
require 'json'
require 'date'
require 'fileutils'

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
year = 1864
volume = '47-1'
newspapers = {
  'L': {title: 'Cleveland Morning Leader', chronam: 'https://chroniclingamerica.loc.gov/lccn/sn83035143/'}
}

# page-level url: https://chroniclingamerica.loc.gov/lccn/sn83035143/1864-01-01/ed-1/seq-2/

doc = File.open("source/view-source_https___babel.hathitrust.org_cgi_ssd_id=iau.31858046133199#seq109.html") { |f| Nokogiri::HTML(f) }

pages = doc.xpath('//div[@class="Page"]')
entries = {}
prev = 0
preventry = nil
linebuffer = []
in_header = false
heading = ''
subheading = ''
breaks = 0
highest = 0

# abstracts pages
pages[24..384].each do |page|
  in_header = true
  seq = page.xpath('./@id').first.text
  lines = page.xpath('./p[@class="Text"]').first.text.split(/\n+/)
  lines.each_with_index do |line, index|
    stripped_line = line.gsub(/^[ -]*/, '').gsub(/[ -]*$/, '')
    next if stripped_line == ''
    
    # detect and ignore page headers
    if in_header
      unless
        stripped_line.match(/^\d*$/) or
        stripped_line.match(/^CLEVELAND NEWSPAPER DIGEST.*/) or
        stripped_line.match(/^Abstracts \d.*/) or
        stripped_line.match(/.*\(Co[nr]t'd\)( -)?/)
        in_header = false
      end
    end
    next if in_header

    # detect headings, see, see also
    is_heading = false
    # ignore dashes at end of line
    if stripped_line.match(/^[A-Z\&\ ]*$/)
      heading = stripped_line
      subheading = ''
      is_heading = true
    end
    if stripped_line.match(/^[A-Z\&\ ]*\. See .*$/)
      # TODO handle see reference
      is_heading = true
    end
    if stripped_line.match(/^See also .*$/)
      # TODO handle see also reference
      is_heading = true
    end
    if linebuffer.count > 0
      if linebuffer.last.match(/.*\((\d+)\)$/) and stripped_line.match(/^[A-Z].*/) and !(is_heading)
        subheading = stripped_line
        is_heading = true
      end
    end
    next if is_heading
    
    # parse line to find start-of-item metadata
    metadata = line.match(/^(\d+) [-–] ([a-zA-Z]+)[\.,]? ((?:Jan.|Feb.|Mar.|Apr.|May|June|July|Aug.|Sept.|Oct.|Nov.|Dec.)) (\d+)[;:,]+\ ?([a-zA-Z]*)[;:,]?\ ?(\d+)\/(\d+)(.*)$/)
    linebuffer << line unless metadata
    next unless metadata
    if preventry
      preventry[:lines] = linebuffer
      inches = preventry[:lines].last.match(/.*\((\d+)\)$/)
      if inches
        preventry[:inches] = inches[1].to_i
      else
        preventry[:inches] = 0
      end
      linebuffer = [line]
    end
    record = {
      id: metadata[1].to_i,
      seq: seq,
      line: index,
      newspaper: metadata[2].to_sym,
      month: months[metadata[3]],
      day: metadata[4].to_i,
      displaydate: Date.new(year, months[metadata[3]], metadata[4].to_i).strftime('%e %B %Y'),
      page: metadata[6].to_i,
      column: metadata[7].to_i,
      type: metadata[5],
      init: metadata[8],
      heading: heading,
      subheading: subheading,
      terms: []
    }
    entries[record[:id]] = record
    
    highest = record[:id] if record[:id] > highest
    breaks += 1 if record[:id] != prev + 1
    prev = record[:id]
    preventry = record
  end
end

puts 'Breaks: ' + breaks.to_s
puts 'Entries: ' + entries.keys.count.to_s
puts 'Highest: ' + highest.to_s
# index pages
pages[398..465].each do |page|
  seq = page.xpath('./@id').first.text
  lines = page.xpath('./p[@class="Text"]').first.text.split(/\n+/)
  lines.each_with_index do |line, index|
    elements = line.match(/^(.*)\, ([0-9\ ]*)$/)
    next unless elements
    term = elements[1]
    ids = elements[2].split
    ids.each do |id|
      entries[id.to_i] = {id: id.to_i, terms: []} unless entries[id.to_i]
      entries[id.to_i][:terms] << term
    end
  end
end

File.open("data.json","w") do |f|
  f.puts JSON.pretty_generate(entries)
end

File.open("data.html","w") do |f|
  entries.keys.each do |key|
    entry = entries[key]
    next unless entry[:month]
    date = Date.new(year, entry[:month], entry[:day])
    newspaper = newspapers[entry[:newspaper]]
    f.puts "<div class='entry'>"
    f.puts "<h3>#{volume}.#{entry[:id]}</h3>"
    if newspaper
      f.puts "<p><a href='#{newspaper[:chronam]}#{date.to_s}/ed-1/seq-#{entry[:page]}'>#{newspaper[:title]}, #{date.strftime('%e %B %Y')}, p.#{entry[:page]}</a>, col.#{entry[:column]} #{entry[:type]} (#{entry[:inches].to_s} inches)</p>"
    else
      f.puts "<p>#{entry[:newspaper]}, #{date.strftime('%e %B %Y')}, p.#{entry[:page]}, col.#{entry[:column]} #{entry[:type]}</p>"
    end
    if entry[:lines]
      f.puts "<p>"
      entry[:lines].each {|line| f.puts "#{line}<br/>"}
      f.puts "</p>"
    end
    f.puts"<ul>"
    f.puts "<li>#{entry[:heading]}#{entry[:subheading] != '' ? ' - ' + entry[:subheading] : ''}</li>"
    entry[:terms].each do |term|
      f.puts "<li>#{term}</li>"
    end
    f.puts"</ul>"
  end
end

missing = 0
File.open("missing.txt","w") do |f|
  (1..highest).each do |key|
    if !entries.keys.include?(key) or !entries[key][:month]
      f.puts key.to_s
      missing += 1
    end
  end
end

puts 'Missing: ' + missing.to_s

# generate Hugo data
hugodata = {}
headings = []
entries.keys.sort.each do |key|
  entry = entries[key]
  hugodata[entry[:heading]] = [] unless hugodata[entry[:heading]]
  hugodata[entry[:heading]] << entry
  headings << entry[:heading] unless headings.include?(entry[:heading])
end

File.open('hugo/data/headings.json','w') do |f|
    f.puts JSON.pretty_generate(headings)
  end
FileUtils.rm_rf('hugo/data/headings')
FileUtils.mkdir_p 'hugo/data/headings'
FileUtils.rm_rf('hugo/content/headings')
FileUtils.mkdir_p 'hugo/content/headings'

headings.each do |heading|
  slug = heading.to_s.gsub('&', 'and').slugify.gsub('-', '')
  
  File.open('hugo/data/headings/' + slug + '.json','w') do |f|
    f.puts JSON.pretty_generate(
      { title: heading, slug: slug, entries: hugodata[heading] }
    )
  end
  File.open('hugo/content/headings/' + slug + '.md','w') do |f|
    f.puts "---\ntitle: '#{heading}'\nslug: '#{slug}'\n---\n\n{{< heading >}}\n"
  end
end

