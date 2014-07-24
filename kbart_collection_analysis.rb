require 'bundler/setup'
require 'active_sierra_models'
require 'csv'

def issn_index
  ## Query the Sierra database fo all ISSNs (MARC Tag 022: |a,|y,|l) on all bib records)
  @issn_hash = Hash.new
  
  def hash_setter(bib, issn)
    issn_match = /^\d{4}-\d{3}[\dXx]$/

    if issn =~ issn_match
      if @issn_hash.has_key? issn
        @issn_hash[issn] << bib
      else
        @issn_hash[issn] = [bib]
      end
      @issn_hash[issn].uniq!
    end
  end

  issn_fields = VarfieldView.marc_tag("022").record_type_code("b").limit(1000)
  issn_fields.each do |field| 
    field.subfields.tag("a").each { |a| hash_setter(field.record_num, a.content) }
    field.subfields.tag("y").each { |y| hash_setter(field.record_num, y.content) }
    field.subfields.tag("l").each { |l| hash_setter(field.record_num, l.content) }
  end
end

class KBART
  ## Accept KBART row and extract useful information - accepts row of CSV data loaded with headers
  attr_accessor :title, :issns, :begin_date, :end_date, :url, :collection, :bib_records

  def initialize(row, hash)
    @title = row.field("publication_title")
    @issns = Array.new
    @issns << row.field("print_identifier") unless row.field("print_identifier").nil?
    @issns << row.field("online_identifier") unless row.field("online_identifier").nil?
    @begin_date = DateTime.parse(row.field("date_first_issue_online"))
    @end_date = DateTime.parse(row.field("date_last_issue_online"))
    @url = row.field("title_url")
    @collection = row.field("collection")
    @bib_records = get_bibs(hash)
  end

  def within_holdings?(volume)
    ## Accepts item and returns true if the item volume statments are within the holding
    date_matches =  /\((\d\d)(\d\d)[-\\\/](\d\d)?(\d\d)?\)/.match(volume)
		return false if date_matches.nil?

    volume_begin = DateTime.parse(date_matches[1] + date_matches[2])
    
    if date_matches[3].nil?
      volume_end = DateTime.parse(date_matches[1] + date_matches[2])
    elsif date_matches[4].nil?
      increment = true if date_matches[3].to_i < date_matches[2].to_i
      if increment
        volume_end = DateTime.parse((date_matches[1].to_i + 1).to_s + date_matches[3])
      else
        volume_end = DateTime.parse(date_matches[1] + date_matches[3])
      end
    else
     volume_end = DateTime.parse(date_matches[3] + date_matches[4])
    end

    return false if volume_begin < self.begin_date
    return false if volume_end > self.begin_date

    true
  end

  private

  def get_bibs(hash)
    array = Array.new
    self.issns.each { |issn| array.concat hash[issn] if hash.has_key? issn }
    array.uniq
  end
end

class Item
  ## Accept ItemView object and create object with all of the information we will need for comparison
  attr_accessor :item_number, :volumes, :call_numbers, :begin_date, :end_date, :location

  def initialize(item_view)
    @item_number = item_view.record_num
    @volumes = item_view.varfield_views.varfield_type_code("v").collect { |f| f.field_content }
    @call_numbers = item_view.varfield_views.varfield_type_code("c").collect { |f| f.field_content }
    @location = item_view.location_code
  end
end

issn_index

kbart = CSV.read(ARGV[0], col_sep: "\t", headers: :first_row)

kbart.each do |row|
  holding = KBART.new(row, @issn_hash)
  next if holding.bib_records.length == 0

  holding.bib_records.each do |bib_number|
    b = BibView.where("record_num = ?", bib_number).first

    puts b.cataloging_date_gmt
    next if b.cataloging_date_gmt = nil
    next unless b.bcode3 = '-'

    bib_title = b.title
    items = b.item_views.collect { |i| Item.new(i) }
    items.each do |i|
      next unless i.location =~ /^u/
      puts bib_title, i.item_number, i.volumes
    end
  end
    
end
