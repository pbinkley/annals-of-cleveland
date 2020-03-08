require './lib/abstract.rb'

describe Abstract do
  it 'parses a clean 1864 abstract' do
    abs = Abstract.new(
      [
        '1|24 - L Mar. 5:4/4 - George Miller was arrested on a charge of entering',
        '2|the shop of Humbert Droz, a watchmaker, on Detroit st. and running off',
        '3|with a watch. He claimed it was his. The watch was not recovered. (3)'
      ], 1864
    )
    expect(abs.parsed).to eq(true)
    expect(abs.inches).to eq(3)
  end

  it 'parses a messy 1848 abstract' do
    abs = Abstract.new(
      [
        '3436|265 . H May 17: ed;2/l • The slavery question is about to produce a',
        '3437|division of the Baptist as well as the Methodist church.',
        '3438|(3)'
      ], 1864
    )
    expect(abs.parsed).to eq(true)
    expect(abs.inches).to eq(3)
  end

  it 'parses a multicolumn abstract with sequence' do
    abs = Abstract.new(
      [
        '1|213 - L. May 28; ed: 1/1,2 - Wallandigham occupies a suite of rooms at the',
        '3438|(3)'
      ], 1864
    )
    expect(abs.parsed).to eq(true)
    expect(abs.blocks.keys.first).to eq(1)
    expect(abs.blocks[1].last).to eq(2)
  end

  it 'parses a multicolumn abstract with range' do
    abs = Abstract.new(
      [
        '1|213 - L. May 28; ed: 1/1-3 - Wallandigham occupies a suite of rooms at the',
        '3438|(3)'
      ], 1864
    )
    expect(abs.parsed).to eq(true)
    expect(abs.blocks.keys.first).to eq(1)
    expect(abs.blocks[1].last).to eq(3)
    expect(abs.blocks[1].count).to eq(3)
  end

  it 'parses a multipage abstract' do
    abs = Abstract.new(
      [
        '1|213 - L. May 28: 1/1-3, 2/5 - Wallandigham occupies a suite of rooms at the',
        '3438|(3)'
      ], 1864
    )
    expect(abs.blocks.keys[1]).to eq(2)
    expect(abs.blocks[1].last).to eq(3)
    expect(abs.blocks[1].count).to eq(3)
    expect(abs.blocks[2].last).to eq(5)
  end
end
