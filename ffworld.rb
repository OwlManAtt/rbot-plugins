# Copyright 2010 owlmanatt <owlmanatt@gmail.com>. 
# No rights reserved, go hog wild.

require 'rubygems'
require 'nokogiri'
require 'open-uri'

module String
  def humanize
    self.gsub(/_id$/, "").gsub(/_/, " ").capitalize
  end
end # string

class FFXIVPlugin < Plugin
  def help(plugin, topic='')
    "FFXIV utilities. Usage: ffxiv => Figaro world status. ffxiv status [world] => server status. ffxiv leves => guildleve reset countdown. "
  end # help

  def realm_status(m, params)
    world = params.has_key?(:realm) ? params[:realm].downcase : 'figaro' 
    worlds = Hash.new 

    # 1996-style HTML. Fuck my life with a ferret.
    doc = Nokogiri::HTML(open('http://www.ffxiv-status.com/index.php'))
    horrible_table = doc.search('table/td[@class=middle]//table/tr')
   
    ignore_tr = [/FFXIV SERVER LIST/i, /Server Name/, /Legend:/, /is automatically refreshed every/] 
    horrible_table.each do |tr|
      # Do we ignore this?
      skip = false
      ignore_tr.each do |ignore|
        skip = true if tr.content.match(ignore)
      end 

      unless skip
        #m.reply "Line = #{tr.children.first.children.first.children.first.content}"
        name = tr.children.first.children.first.children.first.content.match(/([A-Z]+)( World)?:?/i)[1].downcase
        status = tr.children.last.search('img').attr('alt').content

        worlds[name] = status
        #m.reply worlds.inspect
      else
        #m.reply "Skipping #{tr.content}"
      end
    end
    
    if worlds.has_key?(world)
      color = {'offline' => '04', 'online' => '09'}
      #m.reply "#{world.humanize}: \003#{color[worlds[world].downcase]}#{worlds[world]}\003"
      
      status = [world, 'login', 'lobby', 'patch'].uniq.map do |s|
        "#{s.humanize}: \003#{color[worlds[s].downcase]}#{worlds[s]}\003"
      end

      m.reply status.join " \00306**\003 "
    else
      m.reply "Sorry, I don't know about that server."
    end
  end # realm_status

  def leve_timer(m, params)
    # #Guildleves reset every 48h on the 00:00:00. This is September 12th 00:00:00:
    # epoch = Time.at(1284249600)
    #
    # OK beta ended, retail is 36h reset. Epoch is Sep 22 00:00:00 UTC 2010. 
    epoch = Time.at(1285113600)
    now = Time.now
    period_seconds = 60 * 60 * 36
    
    periods_since = (now - epoch) / period_seconds

    # right on the nose would fuck it up and report 0 seconds instead of now + period. 
    periods_since += 1 if periods_since == periods_since.ceil

    next_reset = epoch + (periods_since.ceil * period_seconds)
    seconds_remaining = next_reset - now

    m.reply "Guildleves will reset in #{Utils.secs_to_string(seconds_remaining)}"
  end

end # OwlPlugin
plugin = FFXIVPlugin.new
plugin.map 'ffxiv leves', :action => 'leve_timer'
plugin.map 'ffxiv leve', :action => 'leve_timer' # goons are bad at timezones AND inflection
plugin.map 'ffxiv status :realm', :action => 'realm_status'
plugin.map 'ffxiv', :action => 'realm_status'
