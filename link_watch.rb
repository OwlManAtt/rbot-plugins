require 'rubygems'
require 'active_record'

class ::Hyperlink < ActiveRecord::Base
  # ::class because rbot puts this shit in an anonymous module and that
  # skullfucks AR's ability to divine the table name. :: puts it back at
  # the top of the shitty namespace thing.
end # Hyperlink

class LinkWatchPlugin < Plugin
  def initialize
    super

    Config.register Config::ArrayValue.new('links.ignore',
      :default => [],
      :desc => "Ignored nick list"
    )
  
    # Baller regexp from <http://daringfireball.net/2010/07/improved_regex_for_matching_urls>
    @url_regexp = Regexp.new('(?i)\b((?:https?://|www\d{0,3}[.]|[a-z0-9.\-]+[.][a-z]{2,4}/)(?:[^\s()<>]+|\(([^\s()<>]+|(\([^\s()<>]+\)))*\))+(?:\(([^\s()<>]+|(\([^\s()<>]+\)))*\)|[^\s`!()\[\]{};:\'".,<>?«»“”‘’]))') 
   
    ActiveRecord::Base.establish_connection(
      :adapter => 'mysql',
      :host => 'localhost', 
      :database => 'miyu', 
      :username => 'miyu',
      :password => 'd0ng$',
      :socket => '/var/run/mysqld/mysqld.sock',
      :reconnect => true
    ) 
  end # initialize

  def help(plugin, topic='')
    "A passive module that logs links and displays them in a web GUI. Owl is fucking lazy and hates copypasting shit."
  end # help

  def message(m)
    return unless @url_regexp.match(m.message)
    
    link = Hyperlink.new(
      :network => '', # Future use (probably)
      :channel_name => m.channel.to_s, 
      :nickname => m.sourcenick, 
      :link => $~[1],
      :linked_at => m.time
    )
    link.save unless @bot.config['links.ignore'].member? m.sourcenick.downcase

    # m.reply "URL detected in #{m.channel} by #{m.sourcenick} at #{m.time}: #{$~[1]}"
  end # message

  def ignore_list(m, params)
    list = @bot.config['links.ignore']

    if list.length == 0
      m.reply "No ignored nicks!"
    else
      m.reply list.join ', '
    end
  end # ignore_list
  
  def ignore(m, params)
    name = params[:name].downcase
    @bot.config['links.ignore'] << name unless @bot.config['links.ignore'].member? name

    m.reply "#{name} is now being ignored!"
  end # ignore

  def unignore(m, params)
    name = params[:name].downcase
    @bot.config['links.ignore'].delete name

    m.reply "#{name} will have their links logged again!"
  end # unignore
end # LinkWatchPlugin
plugin = LinkWatchPlugin.new
plugin.default_auth 'ignore', false
plugin.map 'links ignore_list', :action => 'ignore_list', :auth_path => 'ignore'
plugin.map 'links ignore :name', :action => 'ignore', :auth_path => 'ignore'
plugin.map 'links unignore :name', :action => 'unignore', :auth_path => 'ignore'
