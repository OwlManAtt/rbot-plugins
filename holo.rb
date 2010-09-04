require 'rubygems'
require 'nokogiri'
require 'open-uri'

class HoloPlugin < Plugin
  def initialize
    @tracking_numbers = {
      #'Case' => '1ZX799390310081385',
      #'Everything else' => '1ZX799331231131463'
      'Disks' => {:number => '1Z462E560321092067', :courier => 'ups'},
      'Fans' => {:number => '1ZX799470329512449', :courier => 'ups'},
      'Monitor' => {:number => '134619891746049', :courier => 'fedex'},
    }
    super
  end # initialize 

  def status(m, params)
    status_fetch.each {|msg| m.reply msg}
  end # status

  def status_fetch
    result = @tracking_numbers.map do |label,info|
      status = ShipmentScreenScraper.send "fetch_#{info[:courier]}", info[:number]     

      if status
        "\00303#{label}\003: #{status.ircify}"
      else
        "\00303#{label}\003: No information available."
      end
    end

    return result
  end # status_fetch

  def whine(m, params)
    status_fetch.each {|msg| @bot.say '#', msg}
  end

end # OwlPlugin
plugin = HoloPlugin.new
plugin.map 'holo', :action => 'status'
plugin.map 'holo whine', :action => 'whine'

