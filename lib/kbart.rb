class KBART
  require 'date'
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


