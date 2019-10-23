#!/usr/bin/env ruby

require 'nokogiri'
require 'slugify'
require 'json'
require 'yaml'
require 'date'
require 'fileutils'

require './lib/entry.rb'

require 'byebug'

$year = 1864
volume = '47-1'
newspapers = {
  'L': {title: 'Cleveland Morning Leader', chronam: 'https://chroniclingamerica.loc.gov/lccn/sn83035143/'}
}

# page-level url: https://chroniclingamerica.loc.gov/lccn/sn83035143/1864-01-01/ed-1/seq-2/

doc = File.open("source/1864.html") { |f| Nokogiri::HTML(f) }

FileUtils.mkdir_p './output'

pages = doc.xpath('//div[@class="Page"]')
entries = {}
prev = 0
$preventry = nil
$linebuffer = []
in_header = false
$heading = ''
$subheading = ''
$breaks = 0
$highest = 0
$issues = {}
$maxinches = 0
$maxpage = 0
$maxcolumn = 0

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
      $heading = stripped_line
      $subheading = ''
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
    if $linebuffer.count > 0
      if $linebuffer.last.match(/.*\((\d+)\)$/) and stripped_line.match(/^[A-Z].*/) and !(is_heading)
        $subheading = stripped_line
        is_heading = true
      end
    end
    next if is_heading
    
    # returns a populated record if the line can be parsed, or an empty one if it can't
    record = Entry.new(line, seq, index)

    if record.id
      entries[record.id] = record
      $preventry = record
    end
  end
end

puts 'Breaks: ' + $breaks.to_s
puts 'Entries: ' + entries.keys.count.to_s
puts 'Highest: ' + $highest.to_s
puts 'Longest: ' + $maxinches.to_s
puts 'Max page: ' + $maxpage.to_s
puts 'Max column: ' + $maxcolumn.to_s

terms = {}

# index pages - discover index terms matched to entry numbers
pages[398..465].each do |page|
  seq = page.xpath('./@id').first.text
  lines = page.xpath('./p[@class="Text"]').first.text.split(/\n+/)
  lines.each_with_index do |line, index|
    elements = line.match(/^(.*)\, ([0-9\ ]*)$/)
    next unless elements
    term = elements[1]
    slug = term.slugify.gsub(/\-+/, '')
    ids = elements[2].split
    terms[term] = {slug: slug, ids: ids}
    ids.each do |id|
      entries[id.to_i] = Entry.new(id.to_i) unless entries[id.to_i]
      entries[id.to_i].addTerm({term: term, slug: slug})
    end
  end
end

# output full data dump
File.open("output/data.json","w") do |f|
  f.puts JSON.pretty_generate(
    {
      "entries": entries,
      "terms": terms,
      "issues": $issues
    })
end

# output list of missing ids
missing = 0
File.open("output/missing.txt","w") do |f|
  (1..$highest).each do |key|
    if !entries.keys.include?(key) or !entries[key].init
      f.puts key.to_s
      missing += 1
    end
  end
end
puts 'Missing: ' + missing.to_s

# generate Hugo data
hugodata = {}
headings = []
entries.keys.each do |key|
  byebug if key == nil
end
entries.keys.sort.each do |key|
  entry = entries[key]
  hugodata[entry.heading] = [] unless hugodata[entry.heading]
  hugodata[entry.heading] << entry.to_hash
  headings << entry.heading unless headings.include?(entry.heading)
end

FileUtils.rm_rf('hugo/data/headings')
FileUtils.mkdir_p 'hugo/data/headings'

FileUtils.rm_rf('hugo/content/headings')
FileUtils.mkdir_p 'hugo/content/headings'

FileUtils.rm_rf 'hugo/data/terms'
FileUtils.mkdir_p 'hugo/data/terms'

FileUtils.rm_rf 'hugo/content/terms'
FileUtils.mkdir_p 'hugo/content/terms'

FileUtils.rm_rf 'hugo/data/issues'
FileUtils.mkdir_p 'hugo/data/issues'

FileUtils.rm_rf 'hugo/content/issues'
FileUtils.mkdir_p 'hugo/content/issues'

File.open('hugo/data/headings.json','w') do |f|
  f.puts JSON.pretty_generate(headings)
end

headings.each do |heading|
  slug = heading.to_s.gsub('&', 'and').slugify.gsub('-', '')
  
  File.open('hugo/data/headings/' + slug + '.json','w') do |f|
    f.puts JSON.pretty_generate(
      { title: heading, slug: slug, entries: hugodata[heading] }
    )
  end
  yaml = {"title" => heading, "slug" => slug, "count" => hugodata[heading].count}.to_yaml
  File.open('hugo/content/headings/' + slug + '.md','w') do |f|
    f.puts yaml + "\n---\n\n{{< heading >}}\n"
  end
end

terms.keys.each do |term|
  slug = term.to_s.gsub('&', 'and').slugify.gsub(/-+/, '')
  termentries = []
  terms[term][:ids].each do |id|
    termentries << entries[id.to_i].to_hash
  end
  File.open('hugo/data/terms/' + slug + '.json','w') do |f|
    f.puts JSON.pretty_generate(
      { title: term, slug: slug, entries: termentries }
    )
  end
  yaml = {"title" => term, "slug" => slug, "count" => termentries.count}.to_yaml
  File.open('hugo/content/terms/' + slug + '.md','w') do |f|
    f.puts yaml + "\n---\n\n{{< term >}}\n"
  end
end

$issues.keys.each do |key|
  issue = $issues[key]
#  File.open('hugo/data/$issues/' + key + '.json','w') do |f|
#    f.puts JSON.pretty_generate(issue)
#  end
  
  yaml = {"title" => key}.to_yaml
  File.open('hugo/content/issues/' + key + '.md','w') do |f|
    f.puts yaml + "---\n\n"
    f.puts "<style>
      th, td {width: 12.5%; vertical-align: top}
      .entry {border: 1px solid black; margin: 2px; padding: 2px; text-align: center}
      .inch1 {min-height: 20px}
      .inch2 {min-height: 40px}
      .inch3 {min-height: 60px}
      .inch4 {min-height: 80px}
      .inch5 {min-height: 100px}
      .inch6 {min-height: 120px}
      .inch7 {min-height: 140px}
      .inch8 {min-height: 160px}
      .inch9 {min-height: 180px}
      .inch10 {min-height: 200px}
      .inch11 {min-height: 220px}
      .inch12 {min-height: 240px}
      .inchmore {min-height: 260px}
      </style>"
    (1..4).each do |page|
      pagedata = issue.dig page
      f.puts "<div class=\"page\"><h4>Page #{page.to_s} ~ <a href='https://chroniclingamerica.loc.gov/lccn/sn83035143/#{key}/ed-1/seq-#{page.to_s}/'>View at ChronAm</a></h4>"
      f.puts '<table><tr>'
      (1..8).each do |col|
        f.puts "<th>#{col.to_s}</th>"
      end
      f.puts '</tr><tr class="column">'
      (1..8).each do |col|
        coldata = pagedata ? pagedata.dig(col) : nil
        f.puts "<td>"
        if coldata
          coldata.each do |entrykey|
            entry = entries[entrykey]
            f.puts entry.to_html
          end
        end
        f.puts "</td>"
      end
      f.puts "</tr></table></div>\n\n"
    end
  end
end
