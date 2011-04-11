require 'rubygems'
require 'nokogiri'
require 'open-uri'

class HoloPlugin < Plugin
  class ShipmentStatusRecord < Struct.new(:label, :status)
    def to_s
      if self.status
        "\00303#{label}\003: #{status.ircify}"
      else
        "\00303#{label}\003: No information available."
      end
    end
  end

  def initialize
    @tracking_numbers = {
      #'Case' => '1ZX799390310081385',
      #'Everything else' => '1ZX799331231131463'
      #'Disks' => {:number => '1Z462E560321092067', :courier => 'ups'},
      #'Fans' => {:number => '1ZX799470329512449', :courier => 'ups'},
      #'Monitor' => {:number => '134619891746049', :courier => 'fedex'}
      # "Final Fantasy™ XIV COLLECTOR'S EDITION" => {:number => '1Z04462W1300903990', :courier => 'ups'}
      #"IB's dicks" => {:number => '1Z8FX6286801195292', :courier => 'ups'},
      #"WoW Anthology" => {:number => '1ZA7810W0398708948', :courier => 'ups'}
      #"Overpriced HID" => {:number => '1Z4F37F10399609311', :courier => 'ups'}
      #"魔法少女リリカルなのは　The MOVIE 1st＜初回限定版＞" => {:number => '424981299085', :courier => 'fedex'}
      #'Disk' => {:number => '1ZX799470342426740', :courier => 'ups'},
      #'WiMAX CPE' => {:number => '485264002054', :courier => 'fedex'},
      #'WiMAX CPE the 2nd' => {:number => '485264110765', :courier => 'fedex'},
      #'WiMAX CPE - ODU ' => {:number => '1Z3X3F271343232801', :courier => 'ups'},
      # 'Plus Headphones' => {:number => '1Z0X118A1210790602', :courier => 'ups'},
      #'HD 280 Pro' => {:number => '1Z5993920144768026', :courier => 'ups'},
      'Gentech CPE' => {:number => '1Z07R37W9096472131', :courier => 'ups'},
    }
    super
  end # initialize 

  def status(m, params)
    status_fetch.each {|msg|
      m.reply msg
    }
  end # status

  def status_fetch
    @tracking_numbers.map {|label,info|
      ShipmentStatusRecord.new(label, ShipmentScreenScraper.send("fetch_#{info[:courier]}", info[:number]))
    }
  end # status_fetch

  def whine(m, params)
    status_fetch.each {|msg|
      @bot.say '#', msg if msg.status.ircify != @registry[msg.label]
      @registry[msg.label] = msg.status.ircify
    }
  end
end # OwlPlugin
plugin = HoloPlugin.new
plugin.map 'holo', :action => 'status'
plugin.map 'holo whine', :action => 'whine'

