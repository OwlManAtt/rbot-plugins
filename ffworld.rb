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
  DEFAULT_STATUS_REALM = 'figaro'
  LEVE_EPOCH = Time.at(1285113600) # Sep 22 00:00:00 UTC 2010 
  LEVE_RESET_PERIOD = 60 * 60 * 36 # 36 hours 
  @timer_handle = nil

  def initialize
    super
    add_leve_announce()
  end

  def help(plugin, topic='')
    "FFXIV utilities. Usage: ffxiv => Figaro world status. ffxiv status [world] => server status. ffxiv set world [world] => set your own default server to check the status of. ffxiv leves => guildleve reset countdown."
  end # help

  def realm_status(m, params)
    world = params.has_key?(:realm) ? params[:realm].downcase : get_default_realm(m.sourcenick)
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

  def set_default_world(m, params)
    k = "world_#{m.sourcenick}"
    if params[:world] == 'nil'
      @registry.delete k
    else
      @registry[k] = params[:world]
    end

    m.okay
  end # set_default_world

  def leve_timer(m, params)
    m.reply "Guildleves will reset in #{Utils.secs_to_string(time_to_leve_reset)}."
  end

  def cleanup
    remove_leve_announce()
  end

  def time_to_leve_reset(now = Time.now)
    periods_since = (now - LEVE_EPOCH) / LEVE_RESET_PERIOD 

    # right on the nose would fuck it up and report 0 seconds instead of now + period. 
    periods_since += 1 if periods_since == periods_since.ceil

    next_reset = LEVE_EPOCH + (periods_since.ceil * LEVE_RESET_PERIOD)
    
    return next_reset - now
  end

  def debug_next(m, params)
    h = @timer_handle

    @bot.timer.instance_eval do 
      m.reply "Handle invalid." unless @actions.key? h
      m.reply "Next run @ #{@actions[h].next}"
    end
  end

  def admin_channel(m, params)
    if params.key? :chan
      @registry[:announce_channel] = params[:chan]
      reset_leve_announce()
    end

    m.reply "Announce channel is '#{@registry[:announce_channel]}'"
  end

  protected
  def get_default_realm(nick)
    k = "world_#{nick}"
    return DEFAULT_STATUS_REALM unless @registry.key? k

    @registry[k]
  end

  def add_leve_announce
    now = Time.now
    next_reset = now + time_to_leve_reset(now)
    announce_channel = @registry[:announce_channel]
    
    if announce_channel
      @timer_handle = @bot.timer.add(LEVE_RESET_PERIOD, {:start => next_reset}) do
        @bot.say announce_channel, "\02\00309FFXIV\02 - Guild leves have been reset!\003" 
      end
    else
      debug 'No announce channel set in the registry - announce timer not queued.' 
    end
  end

  def remove_leve_announce
    @bot.timer.remove(@timer_handle)
    @timer_handle = nil
  end

  def reset_leve_announce
    remove_leve_announce()
    add_leve_announce()
  end
end # FFXIVPlugin 

plugin = FFXIVPlugin.new
plugin.default_auth('debug', false)
plugin.default_auth('edit', false)

# Informational commands
['ffxiv leve[s]', 'leve', 'leves'].each { |c| plugin.map c, :action => 'leve_timer' }
plugin.map 'ffxiv status :realm', :action => 'realm_status'

# User settings
plugin.map 'ffxiv set world :world', :action => 'set_default_world'

# Admin shit
plugin.map 'ffxiv admin chan :chan', :action => 'admin_channel', :auth_path => 'edit'
plugin.map 'ffxiv admin chan', :action => 'admin_channel', :auth_path => 'edit'
plugin.map 'ffxiv debug announce next', :action => 'debug_next', :auth_path => 'debug'

# Default
plugin.map 'ffxiv', :action => 'realm_status'
