require 'rubygems'
require 'nokogiri'
require 'open-uri'

module String
  def humanize
    self.gsub(/_id$/, "").gsub(/_/, " ").capitalize
  end
end

class FFWorldStatusPlugin < Plugin
  def help(plugin, topic='')
    "Queries FFXIV world server status from ffxiv-status.com. Say ``@ffxiv {server}'' to get status. If no world is specified, Figaro is used."
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
end # OwlPlugin
plugin = FFWorldStatusPlugin.new
plugin.map 'ffxiv', :action => 'realm_status'
plugin.map 'ffxiv :realm', :action => 'realm_status'
