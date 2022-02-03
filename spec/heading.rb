require './lib/heading.rb'
require 'rspec'
require 'byebug'

describe Heading do
  it 'parses a clean 1864 heading' do
    heading = Heading.new('10|ADVERTISING & ADVERTISERS -', 1, 1864)
    expect(heading.text).to eq('Advertising and Advertisers')
    expect(heading.type).to eq('heading')
    expect(heading.slug).to eq('advertising-and-advertisers')
  end
  it 'parses a clean 1864 see reference' do
    heading = Heading.new('10|DESERTIONS, MILITARY. See Wars - Civil War', 1, 1864)
    expect(heading.text).to eq('Desertions, Military')
    expect(heading.type).to eq('see')
    expect(heading.targets.first[:heading]).to eq(['Wars', 'Civil War']) # TODO
  end
  it 'parses a clean 1864 see also reference' do
    heading = Heading.new('10|See also Iron & Steel - Labor; Labor Unions', 1, 1864)
    expect(heading.text).to eq('See also Iron & Steel - Labor; Labor Unions')
    expect(heading.type).to eq('see also')
    expect(heading.targets[0][:text]).to eq('Iron and Steel - Labor') # TODO
    expect(heading.targets[0][:heading]).to eq(['Iron and Steel', 'Labor']) # TODO    
    expect(heading.targets[1][:text]).to eq('Labor Unions') # TODO
  end
  it 'parses a clean 1864 subheading1' do
    heading = Heading.new('10|Book Stores', 1, 1864)
    expect(heading.text).to eq('Book Stores')
    expect(heading.type).to eq('subheading1')
    expect(heading.slug).to eq('book-stores')
  end
  it 'parses a clean 1864 subheading2' do
    heading = Heading.new('10|(Bandits & Guerillas)', 1, 1864)
    expect(heading.text).to eq('Bandits and Guerillas')
    expect(heading.type).to eq('subheading2')
    expect(heading.slug).to eq('bandits-and-guerillas')
  end
end
