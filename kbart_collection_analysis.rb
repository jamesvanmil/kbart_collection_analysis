require 'bundler/setup'
require 'active_sierra_models'
require 'csv'

def issn_index
  'Query the Sierra database fo all ISSNs (MARC Tag 022: |a,|y,|l) on all bib records)'
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

def get_volumes(bib_number)
  BibView.where("record_num = ?", bib_number)[0].item_views { |item| puts item.varfield_views.varfield_type_code("v").field_content }
end

class KBART
  'Accept KBART row and extract useful information - accepts row of CSV data loaded with headers'
  attr_accessor :title, :issns, :begin_date, :end_date, :url, :collection, :bib_records

  def initialize(row, hash)
    @title = row.field("publication_title")
    @issns = Array.new
    @issns << row.field("print_identifier") unless row.field("print_identifier").nil?
    @issns << row.field("online_identifier") unless row.field("online_identifier").nil?
    @begin_date = row.field("date_first_issue_online")
    @end_date = row.field("date_last_issue_online")
    @url = row.field("title_url")
    @collection = row.field("collection")
    @bib_records = get_bibs(hash)
  end

  private

  def get_bibs(hash)
    array = Array.new
    self.issns.each { |issn| array.concat hash[issn] if hash.has_key? issn }
    array.uniq
  end
end

issn_index
puts @issn_hash

kbart = CSV.read(ARGV[0], col_sep: "\t", headers: :first_row)

kbart.each do |row|
  bib_records = Array.new
  holding = KBART.new(row, @issn_hash)

  next if holding.bib_records.length == 0

  holding.bib_records.each { |bib| get_volumes(bib) }
end
