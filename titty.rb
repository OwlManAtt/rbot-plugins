require 'rubygems'
require 'nokogiri'
require 'open-uri'

class TittyPlugin < Plugin
  def help(plugin, topic='')
    "Usage: @titty => time until next broadcast. @titty stream (HD|SD) for stream URL."
  end # help

  def until(m, params)
    doc = Nokogiri::HTML(open('http://gomtv.net'))
    m.reply doc.search('div[@id=mainMenu]//span[@class=tooltip]').last.content.rstrip.lstrip
  end # until

  def stream_url(m, params)
    titty_ips = ['211.43.144.139','211.43.144.141','211.43.144.142','211.43.144.143',
                '211.43.144.144','211.43.144.145','211.43.144.151','211.43.144.152',
                '211.43.144.159','211.43.144.233','211.43.144.234','211.43.144.235',
                '211.43.144.236','211.43.144.238','211.43.144.239','211.43.144.241']

    quality = params[:quality].downcase
    if quality == 'hd'
      m.reply "http://#{titty_ips.pick_one}:8902/view.cgi?hid=1&cid=21&nid=902&uno=14698"
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
