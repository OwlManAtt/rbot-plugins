# Copyright 2010 owlmanatt <owlmanatt@gmail.com>. 
# No rights reserved, go hog wild.
#
# The latest version of this plugin can be found at 
# <http://github.com/OwlManAtt/rbot-plugins/blob/master/ffxiv.rb>.
#
# To configure the optional settings:
#   config set ffxiv.default_world lindblum   # world to show when 'ffxiv' is invoked.
#   ffxiv admin chan #my-ffxiv-channel        # channel to notify when leves reset.

require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'ffxiv-lodestone' # gem install ffxiv-lodestone

module String
  def humanize
    self.gsub(/_id$/, "").gsub(/_/, " ").capitalize
  end
end # string

class FFXIVPlugin < Plugin
  LEVE_EPOCH = Time.at(1285113600) # Sep 22 00:00:00 UTC 2010 
  LEVE_RESET_PERIOD = 60 * 60 * 36 # 36 hours 
  ANIMA_RESET_PERIOD = 60 * 60 * 4 # 4 hours
  @timer_handle = nil

  # "!config set ffxiv.default_world lindblum" to change.
  Config.register Config::StringValue.new('ffxiv.default_world',
    :default => 'figaro',
    :desc => "Which world should be used by default if none is specified?")

  def initialize
    super
    add_leve_announce()
  end

  def help(plugin, topic='')
    "FFXIV utilities. Usage: ffxiv => #{@bot.config['ffxiv.default_world'].humanize} world status. ffxiv status [world] => server status. ffxiv set world [world] => set your own default server to check the status of. ffxiv leves => guildleve reset countdown. ffxiv anima => anima countdown timer. ffxiv jobs [world] [name] => job list. ffxiv price [item] => median price (via ffxivpro)."
  end # help

  def realm_status(m, params)
    world = params.has_key?(:realm) ? params[:realm].downcase : get_default_realm(m.sourcenick).downcase
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
   
    # The lobby hates freedom. The status reported on the lobby is pretty much always
    # incorrect. Square leaves it up when it's refusing connections, and that state cannot
    # be polled without reverse-engineering their stupid auth/lobby protocols, doing a login,
    # and getting its status. So, shrugging man unless its down hard.
    worlds['lobby'] = '┐(´д｀)┌' unless worlds['lobby'].downcase == 'offline' 

    if worlds.has_key?(world)
      color = Hash.new('08')
      color.merge!({'offline' => '04', 'online' => '09'})
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

  def fetch_price(m, params)
    item_name = params[:item].join ' '.humanize
    doc = Nokogiri::HTML(open("http://ffxivpro.com/search/item?q=#{params[:item].join '+'}"))
    
    prices = doc.search('table[@class="stdtbl"]/tr/td[contains("Median")]')
    unless prices
      m.reply "No data is available for #{item_name}."
    else
      unless prices.first
        m.reply "No data could be found for #{item_name}."
      else
        prices = prices.first.next_sibling.next_sibling.search('div').map do |element|
          e = element.content.strip.split ': ' 
          name = e[0]
          name = item_name if name == 'NQ'
          p = e[1].gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1,")

          "#{name}: #{p} gil"
        end # map
        
        m.reply prices.join " \00306**\003 "
      end
    end
  end # fetch_price

  def leve_timer(m, params)
    m.reply "Guildleves will reset in #{Utils.secs_to_string(time_to_next(LEVE_RESET_PERIOD))}."
  end

  # TODO Unvalidated assumptions: (1) Anima regenerates on a global timer, not a character-specific
  # timer. (2) Anima regen started when service went online, just like the leve countdown.
  def anima_timer(m, params)
    m.reply "You will gain 1 anima in #{Utils.secs_to_string(time_to_next(ANIMA_RESET_PERIOD))}. [Experimental]"
  end

  def list_jobs(m, params)
    params[:character] = params[:character].join ' '
    reg_key = "charid_#{params[:world].downcase}_#{params[:character].downcase.gsub(' ','-')}"

    # If this character has been loaded before, query from its cached ID. This saves the gem from
    # having to do two HTTP GETs. If we don't have the ID cached, load by name and save it for
    # later.
    begin
      if @registry.key? reg_key
        #m.reply "load by id #{@registry[reg_key]}"
        char = FFXIVLodestone::Character.new(:id => @registry[reg_key])
      else
        #m.reply "load by name"
        char = FFXIVLodestone::Character.new(:world => params[:world], :name => params[:character])
      end
    rescue => e
      m.reply "Error: #{e.to_s}"
    end
    
    @registry[reg_key] = char.character_id unless @registry.key? reg_key
    list = char.jobs.levelled.sort {|a,b| b.rank <=> a.rank }.map {|j| "#{j.name}: #{j.rank}" }
    list.unshift "Physical Level: #{char.physical_level}" 

    m.reply list.join " \00306**\003 "
  end

  # Invoked when the module is unloaded or rescanned.
  def cleanup
    remove_leve_announce()
  end

  def time_to_next(period_secs, now = Time.now)
    periods_since = (now - LEVE_EPOCH) / period_secs 

    # right on the nose would fuck it up and report 0 seconds instead of now + period. 
    periods_since += 1 if periods_since == periods_since.ceil

    next_reset = LEVE_EPOCH + (periods_since.ceil * period_secs)
    
    return next_reset - now
  end

  def debug_next(m, params)
    h = @timer_handle

    @bot.timer.instance_eval do 
      m.reply "Handle invalid." unless @actions.key? h
      m.reply "Next run @ #{@actions[h].next}"
    end
  end

  # This is an option managed by the plugin, not a configuration option managed by rbot.
  # I do this because rbot's config command does not allow me to run a method when the value
  # is changed; only require a rescan. That's kind of a dumb solution, so this method manages
  # it instead.
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
    return @bot.config['ffxiv.default_world'] unless @registry.key? k

    @registry[k]
  end

  def add_leve_announce
    now = Time.now
    next_reset = now + time_to_next(LEVE_RESET_PERIOD,now)
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
['ffxiv leve[s]', 'leve', 'leves', 'levequest', 'levequests', 'guildleve', 'guildleves'].each do |c| 
  plugin.map c, :action => 'leve_timer' 
end
plugin.map 'ffxiv anima', :action => 'anima_timer'
plugin.map 'anima', :action => 'anima_timer'
plugin.map 'ffxiv price *item', :action => 'fetch_price'

plugin.map 'ffxiv status :realm', :action => 'realm_status'
plugin.map 'ffxiv jobs :world *character', :action => 'list_jobs'
plugin.map 'shock spikes', :action => 'shock_spikes'

# User settings
plugin.map 'ffxiv set world :world', :action => 'set_default_world'

# Admin/debugging tools. 
plugin.map 'ffxiv admin chan :chan', :action => 'admin_channel', :auth_path => 'edit'
plugin.map 'ffxiv admin chan', :action => 'admin_channel', :auth_path => 'edit'
plugin.map 'ffxiv debug announce next', :action => 'debug_next', :auth_path => 'debug'

# Default
plugin.map 'ffxiv', :action => 'realm_status'
