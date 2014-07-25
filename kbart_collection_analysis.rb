require 'bundler/setup'
require 'active_sierra_models'
require 'csv'
require 'date'

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
    @begin_date = DateTime.strptime(row.field("date_first_issue_online"), '%Y-%m-%d')
    @end_date = DateTime.strptime(row.field("date_last_issue_online"), '%Y-%m-%d')
    @url = row.field("title_url")
    @collection = row.field("collection")
    @bib_records = get_bibs(hash)
  end

  def within_holdings?(dates)
    ## Accepts date Array with begin and end dates and returns true if the date statments are within the holding
    dates.each { |date| return false if date.nil? }
    return false if dates[0] < self.begin_date
    return false if dates[1] > self.end_date
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
  attr_accessor :item_number, :volume, :call_number, :dates, :location, :status, :supression

  def initialize(item_view)
    @item_number = item_view.record_num
    @volume = volume_parser(item_view)
    @call_number = call_number_parser(item_view)
    @location = item_view.location_code
    @status = item_view.item_status_code
    @supression = item_view.icode2
    @dates = date_parser(volume)
  end

  private
  
  def volume_parser(item_view)
    ## Assume there is only one volume
    volumes = item_view.varfield_views.varfield_type_code("v").collect { |f| f.field_content }
    volumes[0]
  end

  def call_number_parser(item_view)
    ## Assume there is only one call number
    call_numbers = item_view.varfield_views.varfield_type_code("c").collect { |f| f.field_content }
    call_numbers[0]
  end

  def date_parser(volume)
    ## Parsing attempt #1: (YYYY), (YYYY/YY), (YYYY/YYYY)
    date_matches =  /\((\d\d)(\d\d)[-\\\/]?(\d\d)?(\d\d)?\)/.match(volume)

    ## Parsing attemt #2: ^YYYY$, ^YYYY/YY$, ^YYYY/YYYY$
    date_matches =  /^(\d\d)(\d\d)[-\\\/]?(\d\d)?(\d\d)?$/.match(volume) if date_matches.nil?

    unless date_matches.nil?
      volume_begin = Date.strptime(date_matches[1] + date_matches[2], '%Y')
      if date_matches[3].nil?
        volume_end = Date.strptime(date_matches[1] + date_matches[2], '%Y')
      elsif date_matches[4].nil?
        increment = true if date_matches[3].to_i < date_matches[2].to_i
        if increment
          volume_end = Date.strptime((date_matches[1].to_i + 1).to_s + date_matches[3], '%Y')
        else
          volume_end = Date.strptime(date_matches[1] + date_matches[3], '%Y')
        end
      else
       volume_end = Date.strptime(date_matches[3] + date_matches[4], '%Y')
      end
      return [volume_begin, volume_end]
    end

    ## Parsing attempt #3: (YYYY:Mon.), (YYYY:Mon./Mon.)
    month_hash = [ "Jan" => "1", "Feb" => "2", "Mar" => "3", 
    date_matches = /\(\d\d\d\d):([AZaz]+\.?)[-\\\/]?([AZaz]+\.?)?/.match(volume)
    unless date_matches.nil?
      volume_begin = Date.strptime(date_matches[1], '%Y')
      if date_matches.
    end
   return [nil, nil] 
  end
end

issn_index

kbart = CSV.read(ARGV[0], col_sep: "\t", headers: :first_row)

kbart.each do |row|
  holding = KBART.new(row, @issn_hash)
  next if holding.bib_records.length == 0

  holding.bib_records.each do |bib_number|
    b = BibView.where("record_num = ?", bib_number).first

    next if b.cataloging_date_gmt = nil
    next unless b.bcode3 = '-'

    bib_title = b.title
    items = b.item_views.collect { |i| Item.new(i) }
    items.each do |i|
      next unless i.location =~ /^u/
      next if i.location == 'uint'
      next unless i.supression == "-"
      puts "#{holding.within_holdings?(i.dates)}\t#{bib_title}\ti#{i.item_number}a\t#{i.call_number}\t#{i.volume}\t#{holding.collection}\t#{holding.begin_date.year}-#{holding.end_date.year}"
    end
  end
    
end
