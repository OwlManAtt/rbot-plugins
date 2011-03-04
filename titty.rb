require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'chronic'

class TittyPlugin < Plugin
  def help(plugin, topic='')
    "Usage: @titty => time until next broadcast. @titty stream (HD|SD) for stream URL."
  end # help

  def until(m, params)
    doc = Nokogiri::HTML(open('http://gomtv.net'))
    next_match = doc.search('div[@id=mainMenu]//span[@class=tooltip]').last.content.rstrip.lstrip

    at = nil # holds the next match's time, if available.
    if next_match =~ /Please tune in and enjoy/i
      m.reply "Live right now!"
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

    if at
      m.reply "Live in #{Utils.secs_to_string(at - Time.now)}."
    else
      m.reply "GOM has not scheduled a match."
    end
  end # until

  def stream_url(m, params)
    titty_ips = ['211.43.144.139','211.43.144.141','211.43.144.142','211.43.144.143',
                '211.43.144.144','211.43.144.145','211.43.144.151','211.43.144.152',
                '211.43.144.159','211.43.144.233','211.43.144.234','211.43.144.235',
                '211.43.144.236','211.43.144.238','211.43.144.239','211.43.144.241']

    quality = params[:quality].downcase
    if quality == 'hd'
      #m.reply "http://#{titty_ips.pick_one}:8902/view.cgi?hid=1&cid=21&nid=902&uno=14698"
      m.reply "Sorry, HD is unavailable. :("
    elsif quality == 'sd'
      m.reply "http://#{titty_ips.pick_one}:8900/view.cgi?hid=1&cid=21&nid=900&uno=11850" 
    else
      m.reply "Sorry, I don't know anything about that quality. :("
    end
  end
end # TittyPlugin
plugin = TittyPlugin.new
plugin.map 'titty', :action => 'until'
plugin.map 'titty stream :quality', :action => 'stream_url'
