require 'rubygems'
require 'nokogiri'
require 'open-uri'

class RiftPlugin < Plugin
  DEFAULT_SHARD = :lotham

  class Server < Hash
    def initialize(args)
      self.update(args)
    end

    def ircify
      raise NotImplementedError
    end

    protected
    def colour_status
      if self[:online]
        if self[:locked]
          status = "\00308Locked\003"
        else
          status = "\00309Up\003"
        end
      else
        status = "\00304Down\003"
      end
      
      status    
    end
  end

  class Shard < Server 
    def ircify
      type = []
      if self[:pvp] == false and self[:rp] == false
        type << 'PvE'
      else
        type << 'PvP' if self[:pvp]
        type << 'RP' if self[:rp]
      end

      if self[:queue_size] > 0
        color = '04'
        color = '08' if self[:queue_size] <= 100

        queue_string = "\003#{color}Queue: #{self[:queue_size].to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1,")}\003"
      else
        queue_string = "\00309No queue!\003"
      end 

      "#{self[:shard].to_s.capitalize}-#{type.join '-'}: #{colour_status} \00306**\003 #{queue_string}"
    end
  end # Shard Server

  class System < Server 
    def ircify
      "#{self[:shard].capitalize}: #{colour_status}"
    end
  end # System Server

  def help(plugin, topic='')
    "Rift utilities. @rift => default shard status. @rift shard [name] => shard status. @rift set default [shard name] => set your default shard for the status command. @rift value [platinum] => Value in USD (for lotham/defiant)."
  end # help

  def status(m, params)
    doc = Nokogiri::HTML(open('http://www.riftgame.com/en/status/na-status.xml'))
    
    shards = {}
    doc.search('//shard').each do |shard|
      s = {
        :shard => shard.attr('name').downcase.to_sym, 
        :rp => (shard.attr('rp').downcase == 'true' ? true : false),
        :pvp => (shard.attr('pvp').downcase == 'true' ? true : false),
        :language => shard.attr('language'),
        :online => (shard.attr('online').downcase == 'true' ? true : false),
        :locked => (shard.attr('locked').downcase == 'true' ? true : false),
        :population => shard.attr('population'),
        :queue_size => shard.attr('queued').to_i,
      }

      shards[s[:shard]] = Shard.new(s)
    end

    status_shard = get_default_shard m.sourcenick 
    status_shard = params[:shard].downcase.to_sym if params.has_key? :shard

    if shards.has_key? status_shard
      m.reply [shards[status_shard].ircify].join " \00306**\003 "
    else
      # Sometimes it goes completely blank and/or realms are missing when they are removed
      # from the cluster (or a user asked for dumb shit).
      m.reply "There isn't any information available for that realm. :("
    end
  end # status

  def set_default_shard(m, params)
    k = "shard_#{m.sourcenick}"
    if params[:shard] == 'nil'
      @registry.delete k
    else
      @registry[k] = params[:shard]
    end

    m.okay
  end

  def platseller_price(m, params)
    doc = Nokogiri::XML(open('http://sellriftgold.com/ashx/getgoldprice.ashx?kgamesort=RIFT&kservername=Lotham-Defiants&goldtype=Platinum', {'Referer' => 'http://sellriftgold.com/RIFT_Gold.html', 'Accept' => 'text/javascript, text/html, application/xml, text/xml, */*'}))
    price = doc.search('//Table/goldPrice').first.content.to_f
    total = params[:plat].to_f * price 

    m.reply "Lotham - Defiant: #{format_currency(params[:plat], :currency_symbol => '')} platinum = #{format_currency(total)} USD" 
  end # platseller_price

  protected
  def get_default_shard(nick)
    k = "shard_#{nick}"
    return DEFAULT_SHARD unless @registry.key? k

    @registry[k].downcase.to_sym
  end

  # Source = http://codesnippets.joyent.com/posts/show/1812
  def format_currency(number, options={})
    # :currency_before => false puts the currency symbol after the number
    # default format: $12,345,678.90
    options = {:currency_symbol => "$", :delimiter => ",", :decimal_symbol => ".", :currency_before => true}.merge(options)
    
    # split integer and fractional parts 
    int, frac = ("%.2f" % number).split('.')
    # insert the delimiters
    int.gsub!(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{options[:delimiter]}")
    
    if options[:currency_before]
      options[:currency_symbol] + int + options[:decimal_symbol] + frac
    else
      int + options[:decimal_symbol] + frac + options[:currency_symbol]
    end
  end
end 
plugin = RiftPlugin.new
plugin.map 'rift shard :shard', :action => 'status'
plugin.map 'rift set default :shard', :action => 'set_default_shard'
plugin.map 'rift value :plat', :action => 'platseller_price'
plugin.map 'rift', :action => 'status'
