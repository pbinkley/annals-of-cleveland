# frozen_string_literal: true

require 'slugify'
require 'json'
require 'yaml'
require 'date'
require 'fileutils'
require './lib/metadata.rb'

require 'byebug'

class Hugo

  def initialize(data)
    @data = data
    @abstracts = @data[:abstracts]
    @headings = @data[:headings]
    @terms = @data[:terms]
    @issues = @data[:issues]
    @hugodata = {}
    @headings = []
  end
  
  def generate
=begin
    @abstracts.keys.sort.each do |key|
      abstract = @abstracts[key]
      if !hugodata[abstract.heading]
        hugodata[abstract.heading] = {}
        hugodata[abstract.heading][:abstracts] = []
        hugodata[abstract.heading][:subheadings] = {}
      end
      hugodata[abstract.heading][:abstracts] << abstract.to_hash
      
      if abstract.subheading1 && abstract.subheading1 != ''
        hugodata[abstract.heading][:subheadings][abstract.subheading1] = [] unless hugodata[abstract.heading][:subheadings][abstract.subheading1]
      end
      if abstract.subheading2 && abstract.subheading2 != ''
        hugodata[abstract.heading][:subheadings][abstract.subheading1] << abstract.subheading2 unless hugodata[abstract.heading][:subheadings][abstract.subheading1].include?(abstract.subheading2)
      end
      headings << abstract.heading unless headings.include?(abstract.heading)
    end
=end

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
      f.puts JSON.pretty_generate(@headings)
    end
    
=begin
    File.open('hugo/data/classification.json', 'w') do |f|
      f.puts JSON.pretty_generate(classification)
    end
=end

    @headings.each do |heading|
      byebug
      slug = heading.to_s.gsub('&', 'and').slugify.gsub('-', '')
      File.open('hugo/data/headings/' + slug + '.json', 'w') do |f|
        f.puts JSON.pretty_generate(
          title: heading, slug: slug, abstracts: hugodata[heading][:abstracts]
        )
      end
      subheadings = []
      hugodata[heading][:subheadings].each do |subheading|
        subheadings << {subheading[0] => subheading[1]}
      end
      yaml = { 'title' => heading, 'slug' => slug, 'count' =>
        hugodata[heading][:abstracts].count, 'seealso' => seealsos[heading],
        'subheadings' => subheadings }.to_yaml
      File.open('hugo/content/headings/' + slug + '.md', 'w') do |f|
        f.puts yaml + "\n---\n\n{{< heading >}}\n"
      end
    end
    
    @terms.keys.each do |term|
      slug = term.to_s.gsub('&', 'and').slugify.gsub(/-+/, '')
      termentries = []
      @terms[term][:ids].each do |id|
        termentries << @abstracts[id]
      end
      File.open('hugo/data/terms/' + slug + '.json', 'w') do |f|
        f.puts JSON.pretty_generate(
          title: term, slug: slug, abstracts: termentries
        )
      end
      yaml = { 'title' => term, 'slug' => slug, 'count' =>
        termentries.count }.to_yaml
      File.open('hugo/content/terms/' + slug + '.md', 'w') do |f|
        f.puts yaml + "\n---\n\n{{< term >}}\n"
      end
    end
    
    @issues.keys.each do |key|
      issue = @issues[key]
    
      yaml = { 'title' => key }.to_yaml
      File.open('hugo/content/issues/' + key + '.md', 'w') do |f|
        f.puts yaml + "---\n\n"
        f.puts '<style>
          th, td {width: 12.5%; vertical-align: top}
          .abstract {border: 1px solid black;
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
          f.puts "<a href='#{NEWSPAPERS[:L]['chronam']}/#{key}/ed-1/seq-#{page}/'>"
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
              abstract = @abstracts[entrykey]
              f.puts abstract.to_html
            end
            f.puts '</td>'
          end
          f.puts '</tr></table></div>'
        end
      end
    end
  end
end