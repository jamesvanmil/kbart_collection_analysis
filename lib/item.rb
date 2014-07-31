class Item
  require 'date'
  require 'active_sierra_models'
  ## Accept ItemView object and create object with all of the information we will need for comparison
  attr_accessor :item_number, :volume, :call_number, :dates, :location, :status, :supression, :note

  def initialize(item_view)
    @item_number = item_view.record_num
    @volume = volume_parser(item_view)
    @call_number = call_number_parser(item_view)
    @location = item_view.location_code
    @status = item_view.item_status_code
    @supression = item_view.icode2
    @dates = date_parser(volume)
    @note = note_parser(item_view)
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

  def note_parser(item_view)
    ##Concatenate all notes into one field
    notes = item_view.varfield_views.varfield_type_code("x").collect { |f| f.field_content }
    notes.join("; ")
  end

  def date_parser(volume)
    ## Parsing attempt #1: (YYYY), (YYYY/YY), (YYYY/YYYY)
    date_matches =  /\((\d\d)(\d\d)[-\\\/]?(\d\d)?(\d\d)?\)/.match(volume)

    ## Parsing attemt #2: ^YYYY, ^YYYY/YY, ^YYYY/YYYY
    date_matches =  /^(\d\d)(\d\d)[-\\\/]?(\d\d)?(\d\d)?/.match(volume) if date_matches.nil?

    unless date_matches.nil?
      volume_begin = Date.strptime(date_matches[1] + date_matches[2], '%Y')
      if date_matches[3].nil?
        volume_end = Date.strptime(date_matches[1] + date_matches[2], '%Y')
      elsif date_matches[4].nil?
        increment = true if date_matches[3].to_i > date_matches[2].to_i
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
    date_matches = /\((\d\d\d\d):((?:Jan\w*)(?:Feb\w*)(?:Mar\w*)(?:Apr\w*)(?:May\w*)(?:Jun\w*)(?:Jul\w*)(?:Aug\w*)(?:Sep\w*)(?:Oct\w*)(?:Nov\w*)(?:Dec\w*)\.?)[-\\\/]?((?:Jan\w*)(?:Feb\w*)(?:Mar\w*)(?:Apr\w*)(?:May\w*)(?:Jun\w*)(?:Jul\w*)(?:Aug\w*)(?:Sep\w*)(?:Oct\w*)(?:Nov\w*)(?:Dec\w*)\.?)?\)/.match(volume)
    unless date_matches.nil?
      puts volume, date_matches
      volume_begin = Date.parse("#{date_matches[2]} #{date_matches[1]}")
      if date_matches[3].nil?
        volume_end = volume_begin
      else
        volume_end = Date.parse("#{date_matches[3]} #{date_matches[1]}")
      end
      return [volume_begin, volume_end]
    end

    ## Parsing attempt #4: (YYYY:Mon./YYYY:Mon.)
    date_matches =  /\((\d\d)(\d\d):([A-Za-z]+\.?)[-\\\/](\d\d)(\d\d)?:([A-Za-z]+\.?)\)/.match(volume)
    unless date_matches.nil?
      volume_begin = Date.parse("#{date_matches[3]} #{date_matches[1]+date_matches[2]}")
      if date_matches[5].nil?
        increment = true if date_matches[4].to_i > date_matches[2].to_i
        if increment
          volume_end = Date.parse("#{date_matches[6]} #{(date_matches[1].to_i + 1).to_s + date_matches[4]}")
        else
          volume_end = Date.parse("#{date_matches[6]} #{date_matches[1] + date_matches[4]}")
        end
      else
        volume_end = Date.parse("#{date_matches[6]} #{date_matches[4] + date_matches[5]}")
      end
      return [volume_begin, volume_end]
    end

    [nil, nil]
  end

end
