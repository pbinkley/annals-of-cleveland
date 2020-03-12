require './lib/heading.rb'
require 'rspec'
require 'byebug'

describe Heading do
  it 'parses a clean 1864 heading' do
    heading = Heading.new('10|ADVERTISING & ADVERTISERS -', 1, 1864)
    expect(heading.text).to eq('Advertising and Advertisers')
    expect(heading.type).to eq('heading')
    expect(heading.slug).to eq('advertisingandadvertisers')
  end
  it 'parses a clean 1864 see reference' do
    heading = Heading.new('10|ABANDONED CHILDREN. See Children', 1, 1864)
    expect(heading.text).to eq('Abandoned Children')
    expect(heading.type).to eq('see')
    expect(heading.targets.first[:heading]).to eq('Children')
  end
  it 'parses a clean 1864 see also reference' do
    heading = Heading.new('10|See also Farm Products', 1, 1864)
    expect(heading.text).to eq('See also Farm Products')
    expect(heading.type).to eq('see also')
    expect(heading.targets.first[:text]).to eq('Farm Products')
  end
  it 'parses a clean 1864 subheading1' do
    heading = Heading.new('10|Book Stores', 1, 1864)
    expect(heading.text).to eq('Book Stores')
    expect(heading.type).to eq('subheading1')
    expect(heading.slug).to eq('bookstores')
  end
  it 'parses a clean 1864 subheading2' do
    heading = Heading.new('10|(Bandits & Guerillas)', 1, 1864)
    expect(heading.text).to eq('Bandits and Guerillas')
    expect(heading.type).to eq('subheading2')
    expect(heading.slug).to eq('banditsandguerillas')
  end
end
