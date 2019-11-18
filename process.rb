#!/usr/bin/env ruby
# frozen_string_literal: true

require 'nokogiri'
require 'slugify'
require 'json'
require 'yaml'
require 'date'
require 'fileutils'

require './lib/context.rb'
require './lib/entry.rb'
require './lib/page.rb'

require 'byebug'

NWORDREGEX = /([#{78.chr}#{110.chr}])#{105.chr}#{103.chr}#{103.chr}#{101.chr}#{114.chr}/.freeze
MISSINGENTRIES = ((303..454).to_a +
                  (1758..1764).to_a +
                  (1872..1959).to_a +
                  (2068..2077).to_a +
                  (2216..2255).to_a +
                  (2533..2552).to_a +
                  (2638..2652).to_a +
                  (2680..2692).to_a +
                  (2726..2727).to_a +
                  [974, 1212, 1240, 1300, 1821, 1867, 2044, 2377, 2515, 2626]).freeze

newspapers = {
  'L': {
    title: 'Cleveland Morning Leader',
    chronam: 'https://chroniclingamerica.loc.gov/lccn/sn83035143/'
  }
}

# page-level url: https://chroniclingamerica.loc.gov/lccn/sn83035143/1864-01-01/ed-1/seq-2/

doc = File.open('source/1864-corrected.html') { |f| Nokogiri::HTML(f) }

FileUtils.mkdir_p './output'

pages = doc.xpath('//div[@class="Page"]')
entries = {}
in_header = false

context = Context.new

seealsos = {}

# abstracts pages
pages[24..383].each do |page_ocr|
  page = Page.new(context, page_ocr)

  page.lines.each do |line|
    line[:text].gsub!('–', '-')
    # detect headings, see, see also
    is_heading = false
    # ignore dashes at end of line
    if line[:text].match(/^===/)
      # TODO: handle heading note
    elsif line[:text].match(/^\+/)
      # heading inserted by editor
      heading = line[:text].gsub(/^\++ /, '')
      if line[:text].match(/^\+\+\+ /)
        context.subheading2 = heading
      elsif line[:text].match(/^\+\+ /)
        context.subheading1 = heading
        context.subheading2 = ''
      else
        context.heading = heading
        context.subheading1 = ''
        context.subheading2 = ''
      end
    elsif line[:text].match(/^[A-Z\&\'\,\ ]*[\.\-\ ]*$/)
      context.heading = line[:text].sub(/[\.\-\ ]*$/, '')
      context.subheading1 = ''
      context.subheading2 = ''
      is_heading = true
    elsif line[:text].match(/^[A-Z\&\'\,\ ]*\. See .*$/)
      # TODO: handle see reference
      # e.g. "ABANDONED CHILDREN. See Children"
      is_heading = true
    elsif line[:text].match(/^.* - See .*$/)
      # TODO: handle see entry reference
      # e.g. "ABANDONED CHILDREN. See Children"
      is_heading = true
    elsif line[:text].match(/^See also .*$/)
      # e.g. "See also Farm Products"
      seealso = line[:text].sub('See also ', '')
      seealso.split(';').each do |heading|
        heading.strip!
        seealsos[context.heading] = [] unless seealsos[context.heading]
        if heading[0].match(/[A-Z]/)
          parts = heading.split('-')
          obj = {'heading' => parts[0].to_s.strip, 'slug' => parts[0].to_s.strip.slugify.gsub(/-+/, '')}
          obj['subheading'] = parts[1].to_s.strip
          seealsos[context.heading] << obj
        else
          # generic entry like "names of animals"
          seealsos[context.heading] << {generic: heading}
        end
      end
      is_heading = true
    end
    if context.linebuffer.count > 0
      # look for: previous line ends with inch count in parentheses
      # and this line start with capital or parenthesis + letter
      if context.linebuffer.last.match(/.*\((\d+)\)$/) &&
        line[:text].match(/^[A-Z()].*/) && !is_heading
        if line[:text].match(/^\([A-Z].*/)
          context.subheading2 = line[:text].gsub(/[()]/, '')
        else
          context.subheading1 = line[:text].sub(/[\.\-\ ]*$/, '')
          context.subheading2 = ''
        end
        puts context.subheading1 + ' - ' + context.subheading2 if context.subheading2 != ''
        is_heading = true
      end
    end
    next if is_heading

    # returns a populated record if the line can be parsed,
    # or an empty one if it can't
    record = Entry.new(context, line[:text], page.seq, line[:index])

    # do not overwrite existing entries
    if record.id && !entries[record.id]
      entries[record.id] = record
      context.preventry = record
    end
  end
end
# hack to populate the last inches field
entries[entries.keys.last].store_lines context.linebuffer

puts 'Breaks: ' + context.breaks.to_s
puts 'Entries: ' + entries.keys.count.to_s
puts 'Highest: ' + context.highest.to_s
puts 'Longest: ' + context.maxinches.to_s
puts 'Max page: ' + context.maxpage.to_s
puts 'Max column: ' + context.maxcolumn.to_s

terms = {}

# index pages - discover index terms matched to entry numbers
badcount = 0
pages[398..465].each do |page|
  # seq = page.xpath('./@id').first.text
  lines = page.xpath('./p[@class="Text"]').first.text.split(/\n+/)
  inHeader = true
  lines.each do |line|
    next if (inHeader && line.match(/^[(0-9)]*$/))
    next if (inHeader && line.match(/^INDEX/))
    inHeader = false
    line.gsub!(/\ [-.!,:;*º•'‘"“~ ]*$/, '') # remove trailing punctuation
    line.gsub!(/([0-9])\.\ ?([0-9])/, '\1\2') # remove period between digits
    
    elements = line.match(/^(.*)\, ([0-9\ \;\-\/]*)$/)
    seeref = line.match(/^(.+)\. See (.+)$/)
    continuation = line.match(/^[0-9\ -\/]*$/)
    puts line unless elements || seeref || continuation
    badcount += 1 unless elements || seeref || continuation
    next unless elements || seeref || continuation
    if elements
      term = elements[1]
      slug = term.slugify.gsub(/\-+/, '')
      ids = elements[2].split
      terms[term] = { slug: slug, ids: ids }
      previd = 0.0
      ids.each do |id|
        parts = id.split('-')
        id = parts[0].to_f
        # handle -1/2 suffix on id
        id += 0.5 if parts.count == 2 && parts[1] == '1/2'
        puts "High: #{term} | #{id}" if id > 2774.0
        entries[id] = Entry.new(context, id) unless entries[id]
        entries[id].add_term(term: term, slug: slug)
        previd = id
      end
    else
      # TODO: handle seeref and continuation
    end
  end
end
puts "badcount: #{badcount}"

# classification list
class_lines = []
pages[16..22].each_with_index do |page_ocr, page_index|
  # skip odd pages, which are blank
  next if page_index.odd?
  page = Page.new(context, page_ocr)
  page.lines.each do |line|
    class_lines << line
  end
end

classification = []
line_buffer = []
current_class = nil
previous_class = nil
class_lines.each do |line|
  if line[:text].match(/^[A-Z&, ]+$/)
    if current_class
      c = {headings: [], title: current_class, slug: current_class.gsub('&', 'and').slugify.gsub(/-+/, '')}
      c['line_buffer'] = line_buffer
      classification << c
      line_buffer = []
    end
    current_class = line[:text]
  else
    line_buffer << line[:text]
  end
end
classification.each do |c|
  heading_blocks = c['line_buffer'].join(' ').gsub(/\s+/, ' ').gsub('–', '-').gsub(/(\d)\- (\d)/, '\1-\2').gsub('- ', '').split('. ')

  heading_blocks.each do |block|
    block_parts = block.match(/^(.*)\ (.+?)$/)

    block_entries = block_parts[2].split('-')
    first = block_entries[0].to_i + 1
    last = block_entries.count > 1 ? block_entries[1].to_i : first

    c[:headings] << {
      heading: block_parts[1],
      upheading: block_parts[1].upcase,
      slug: block_parts[1].gsub('&', 'and').slugify.gsub(/-+/, ''),
      first: first,
      last: last,
      count: last - first + 1
    }
  end
  c.delete 'line_buffer'
end

# output full data dump
entries_array = []
entries.keys.sort.each do |key|
  entries_array << entries[key].to_hash
  puts "half-key: #{key}" if key % 1 == 0.5
end
File.open('output/data.json', 'w') do |f|
  f.puts JSON.pretty_generate(
    'entries': entries_array,
    'terms': terms,
    'issues': context.issues,
    'classification': classification
  )
end

# output csv of headings
require "csv"
CSV.open("output/headings.csv", "w") do |csv|
  entries_array.each do |entry|
    csv << [entry[:id], entry[:heading], entry[:subheading1], entry[:subheading2], ]
  end
end

# output list of missing ids
missing = 0
File.open('output/missing.txt', 'w') do |f|
  (1..context.highest.to_i).each do |key|
    if !MISSINGENTRIES.include?(key) && (!entries.keys.include?(key.to_f) || !entries[key.to_f].init)
      f.puts key.to_s
      puts 'First missing: ' + key.to_s if missing == 0
      missing += 1
    end
  end
end
puts 'Missing: ' + missing.to_s

entries.keys.sort.each do |key|
  puts 'Missing inches: ' + key.to_s unless (MISSINGENTRIES.include?(key.to_i) || entries[key].inches.is_a?(Integer))
end

# generate Hugo data
hugodata = {}
headings = []

entries.keys.sort.each do |key|
  entry = entries[key]
  if !hugodata[entry.heading]
    hugodata[entry.heading] = {}
    hugodata[entry.heading][:entries] = []
    hugodata[entry.heading][:subheadings] = {}
  end
  hugodata[entry.heading][:entries] << entry.to_hash
  
  if entry.subheading1 && entry.subheading1 != ''
    hugodata[entry.heading][:subheadings][entry.subheading1] = [] unless hugodata[entry.heading][:subheadings][entry.subheading1]
  end
  if entry.subheading2 && entry.subheading2 != ''
    hugodata[entry.heading][:subheadings][entry.subheading1] << entry.subheading2 unless hugodata[entry.heading][:subheadings][entry.subheading1].include?(entry.subheading2)
  end
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

File.open('hugo/data/headings.json', 'w') do |f|
  f.puts JSON.pretty_generate(headings)
end

File.open('hugo/data/classification.json', 'w') do |f|
  f.puts JSON.pretty_generate(classification)
end

headings.each do |heading|
  slug = heading.to_s.gsub('&', 'and').slugify.gsub('-', '')
  File.open('hugo/data/headings/' + slug + '.json', 'w') do |f|
    f.puts JSON.pretty_generate(
      title: heading, slug: slug, entries: hugodata[heading][:entries]
    )
  end
  subheadings = []
  hugodata[heading][:subheadings].each do |subheading|
    subheadings << {subheading[0] => subheading[1]}
  end
  yaml = { 'title' => heading, 'slug' => slug, 'count' =>
    hugodata[heading][:entries].count, 'seealso' => seealsos[heading],
    'subheadings' => subheadings }.to_yaml
  File.open('hugo/content/headings/' + slug + '.md', 'w') do |f|
    f.puts yaml + "\n---\n\n{{< heading >}}\n"
  end
end

terms.keys.each do |term|
  slug = term.to_s.gsub('&', 'and').slugify.gsub(/-+/, '')
  termentries = []
  terms[term][:ids].each do |id|
    termentries << entries[id.to_f].to_hash
  end
  File.open('hugo/data/terms/' + slug + '.json', 'w') do |f|
    f.puts JSON.pretty_generate(
      title: term, slug: slug, entries: termentries
    )
  end
  yaml = { 'title' => term, 'slug' => slug, 'count' =>
    termentries.count }.to_yaml
  File.open('hugo/content/terms/' + slug + '.md', 'w') do |f|
    f.puts yaml + "\n---\n\n{{< term >}}\n"
  end
end

context.issues.keys.each do |key|
  issue = context.issues[key]

  yaml = { 'title' => key }.to_yaml
  File.open('hugo/content/issues/' + key + '.md', 'w') do |f|
    f.puts yaml + "---\n\n"
    f.puts '<style>
      th, td {width: 12.5%; vertical-align: top}
      .entry {border: 1px solid black;
        margin: 2px;
        padding: 2px;
        text-align: center}
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
      </style>'
    (1..4).each do |page|
      pagedata = issue.dig page
      f.puts "<div class=\"page\"><h4>Page #{page} ~ "
      f.puts "<a href='#{newspapers[:L]['chronam']}/#{key}/ed-1/seq-#{page}/'>"
      f.puts 'View at ChronAm</a></h4>'
      f.puts '<table><tr>'
      (1..8).each do |col|
        f.puts "<th>#{col}</th>"
      end
      f.puts '</tr><tr class="column">'
      (1..8).each do |col|
        coldata = pagedata ? pagedata.dig(col) : nil
        f.puts '<td>'
        coldata&.each do |entrykey|
          entry = entries[entrykey]
          f.puts entry.to_html
        end
        f.puts '</td>'
      end
      f.puts '</tr></table></div>'
    end
  end
end
