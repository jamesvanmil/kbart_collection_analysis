require 'bundler/setup'
require 'active_sierra_models'
require 'csv'
require 'fuzzystringmatch'

require_relative 'lib/item'
require_relative 'lib/kbart'
require_relative 'lib/functions'

issn_index
distance = FuzzyStringMatch::JaroWinkler.create( :pure )

kbart = CSV.read(ARGV[0], col_sep: "\t", headers: :first_row)

kbart.each do |row|
  holding = KBART.new(row, @issn_hash)
  next if holding.bib_records.length == 0

  holding.bib_records.each do |bib_number|
    b = BibView.where("record_num = ?", bib_number).first

    next if b.cataloging_date_gmt = nil
    next unless b.bcode3 = '-'

    bib_title = b.title
    title_comparison = distance.getDistance( bib_title, holding.title )

    items = b.item_views.collect { |i| Item.new(i) }
    items.each do |i|
      next unless i.location =~ /^u/
      next if i.location == 'uint'
      next if i.status == 'w'
      next unless i.supression == "-"
      puts "Overlap?\tTitle from Sierra\tTitle from holdings\tTitle ratio\tItem #\tItem\tCall #\tVolume\tNote\tHoldings collection\tHoldings begin\tHoldings end"
      puts "#{holding.within_holdings?(i.dates)}\t#{bib_title}\t#{holding.title}\t#{title_comparison}\ti#{i.item_number}a\t#{i.location}\t#{i.call_number}\t#{i.volume}\t#{i.note}\t#{holding.collection}\t#{holding.begin_date.year}-#{holding.end_date.year}"
    end
  end
    
end
