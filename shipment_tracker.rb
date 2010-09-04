require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'json' # fuck fedex in the ass

module ::ShipmentScreenScraper
  class ShipmentStatus
    @number = nil
    @location = nil
    @time = nil
    @activity = nil
    @carrier = nil

    attr_reader :number, :location, :time, :activity, :carrier

    def initialize(data)
      @number = data[:number]
      @location = data[:location]
      @time = data[:time]
      @activity = data[:activity]
      @carrier = data[:carrier]
    end # initialize

    def ircify
      "#{activity} @ #{time} - #{location}"
    end
  end # ShipmentStatus

  def self.fetch_ups(number)
    doc = Nokogiri::HTML(open("http://wwwapps.ups.com/WebTracking/processInputRequest?sort_by=status&tracknums_displayed=1&TypeOfInquiryNumber=T&loc=en_US&InquiryNumber1=#{number}&track.x=0&track.y=0"))
    latest_row = doc.search('fieldset[@id=showPackageProgress]//tr')[1]
    if latest_row
      status = ShipmentStatus.new(
        :number => number,
        :location => latest_row.children[0].children.first.content.ircify_html,
        :time => latest_row.children[2].content.ircify_html << " " << latest_row.children[4].content.ircify_html,
        :activity => latest_row.children[6].content.ircify_html,
        :carrier => 'UPS'
      )
    else
      nil 
    end
  end # fetch UPS

  def self.fetch_fedex(number)
    doc = open("http://www.fedex.com/Tracking?language=english&cntry_code=us&tracknumbers=#{number}")

    data = ''
    doc.each_line do |line| 
      if line =~ /^var detailInfoObject/ 
        data = line 
        break # fuck the rest of this page
      end
    end
    data = data.sub(/var detailInfoObject = /, '').sub(/;\n$/, '')
    
    if data == '' 
      return nil
    end

    # keys = ["scanDate", "GMTOffset", "showReturnToShipper", "scanStatus", "scanLocation", "scanTime", "scanComments"]
    data = JSON.parse(data)
    latest_row = data['scans'].first 

    if latest_row
      status = ShipmentStatus.new(
        :number => number,
        :location => latest_row['scanLocation'], 
        :time => latest_row['scanDate'] << ' ' << latest_row['scanTime'],
        :activity => latest_row['scanStatus'],
        :carrier => 'FedEx'
      )
    else
      nil
    end
  end # fetch fedex
 
end

class ShipmentTrackerPlugin < Plugin
  def status(m, params)
    number = params[:number]
    carrier = params[:carrier].downcase

    method = "fetch_#{carrier}"
    if ShipmentScreenScraper.respond_to? method
      status = ShipmentScreenScraper.send method, number 
      
      if status
        m.reply status.ircify
      else # status = nil
        m.reply "Sorry, no information is available."
      end # status
    else
      m.reply "Sorry, that courier service is not supported. :("
    end
  end # status

end # ShipmentTrackerPlugin 
plugin = ShipmentTrackerPlugin.new
plugin.map 'shipment :number :carrier', :action => 'status'
