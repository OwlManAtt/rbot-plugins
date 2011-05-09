require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'chronic'
require 'active_support' # timezone fuckery

class StarcraftPlugin < Plugin
  EVENTS = {
    :gsl => :until_gsl,
    :nasl => :until_nasl,
    :tsl => :until_tsl,
  }

  def help(plugin, topic='')
    "Available commands: @sc, @gsl, @nasl, @tsl"
  end # help

  # Display thing.
  def until(event)
    at = StarcraftPlugin.send(EVENTS[event].to_s)
  
    if at == nil
      return "Match not scheduled."
    elsif at == 0
      return "Live right now!"
    elsif at > Time.now.to_i
      return "Live in #{Utils.secs_to_string(at - Time.now.to_i)}."
    else
      return "Unknown error: time not handled!"
    end
  end # until

  def self.until_gsl
    doc = Nokogiri::HTML(open('http://gomtv.net'))
    next_match = doc.search('div[@id=mainMenu]//span[@class=tooltip]').last.content.rstrip.lstrip

    at = nil # holds the next match's time, if available.
    if next_match =~ /Please tune in and enjoy/i
      at = 0
    elsif next_match =~ /Next LIVE starts in /i
      next_match.gsub!(/Next LIVE starts in /i,'')

      # -9 hours to undo the KST bullshit  
      at = Chronic::parse(next_match) - (60 * 60 * 9)
    else
      # OK, no match in their scheduler. Let's fall back to the calendar.
      schedule_js = nil
      open('http://gomtv.net').each_line do |line| 
        schedule_js = line if line =~ /^viewDetail\(/
      end

      if schedule_js
        data = {}
        schedule_js.gsub('viewDetail({','').gsub("})});\r\n",'').split("',").each do |line|
          line = line.split " : '"
          data[line[0]] = line[1]
        end

        doc = Nokogiri::HTML(data['stime'])
        next_match = doc.root.content.gsub('@ ','').gsub(/\(.*\)$/,'').split("\302\240").reverse.join
        at = Chronic::parse(next_match) - (60 * 60 * 9)
      end
    end

    return at
  end # until_gsl

  def self.until_nasl
    at = nil # holds the next match's time, if available.

    doc = Nokogiri::HTML(open('http://nasl.tv/Match'))
    day = doc.search('li.group').first # assumption: old days will fall off the page
    
    time = day.search('div.day_details span.date', 'div.day_details span.time').map {|e| e.content.strip }.join(' ').gsub(' (PST)', '')
    at = Chronic::parse(time)

    Time.zone = 'America/Los_Angeles'
    at = Time.zone.at(at)
    Time.zone = 'UTC'
    at = Time.at(at.to_i - at.utc_offset).to_i

    return at
  end # until_nasl

  def self.until_tsl
    at = nil

    useful_line = nil
    open('http://teamliquid.net').each_line do |line|
      useful_line = line if line =~ /^\$\("#tslcountdown"\)\.countdown/  
    end # each_line
    
    if useful_line 
      horrible_time = useful_line.split('(').last.gsub("))});\n",'').split(', ').map {|i| i.split '-' }.flatten
      horrible_time.delete_at(2) # for some fucking reason, the month is ``04-1'' which is obviously wrong...
      date = horrible_time.slice!(0,3)

      at = Chronic::parse("#{date.join('-')} #{horrible_time.join(':')}").to_i
      at = 0 if at < Time.now.to_i # handle live right now (poorly)
    end # useful line

    return at
  end # until_tsl

  def event(m, params)
    m.reply self.until(params[:event])
  end # event

  def list_events(m, params)
    EVENTS.each do |name,method|
      m.reply "\002#{name.to_s.upcase}\002: #{self.until(name)}"
    end
  end # list_events

end # StarcraftPlugin
plugin = StarcraftPlugin.new
plugin.map 'sc', :action => 'list_events'
plugin.map 'gsl', :action => 'event', :defaults => {:event => :gsl} 
plugin.map 'titty', :action => 'event', :defaults => {:event => :gsl} # legacy
plugin.map 'nasl', :action => 'event', :defaults => {:event => :nasl} 
plugin.map 'tsl', :action => 'event', :defaults => {:event => :tsl}
