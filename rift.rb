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
      status = "\00304Down\003"
      status = "\00309Up\003" if self[:online]
      
      status    
    end
  end

  class Shard < Server 
    def ircify
      "#{self[:shard].capitalize}-#{self[:type]}: #{colour_status}"
    end
  end # Shard Server

  class System < Server 
    def ircify
      "#{self[:shard].capitalize}: #{colour_status}"
    end
  end # System Server

  def help(plugin, topic='')
    "Rift utilities. @rift => default shard status. @rift shard [name] => shard status. @rift set default [shard name] => set your default shard for the status command."
  end # help

  def status(m, params)
    # I was wondering if you could possibly write a less-parsable document you fucking dick?
    doc = Nokogiri::HTML(open('http://www.riftstatus.com/index.php'))
    status_table = doc.search("h3.maintitle[contains('Server Status (NA)')]").first.next_sibling.next_sibling.children[1]

    system = {}
    shards = {}
    status_table.children.each do |row|
      status = false
      if row.children[0].search('img')[0].attr('src') == 'images/online.png'
        status = true
      end
      
      name = row.children[4].content.strip
      type = row.children[6].content.strip.gsub('(', '').gsub(')', '')
      language = 'EN' # row.children[6].content.strip # changed to a flag, fuck parsing this.
      server = {:shard => name, :type => type, :language => language, :online => status}

      if ['patch server', 'login server'].include? name.downcase
        name = name.split[0].downcase.to_sym
        system[name] = System.new(server)
      else
        shards[name.downcase.to_sym] = Shard.new(server) 
      end
    end

    # Check the name first. If no name was give, use the default.
    status_shard = get_default_shard m.sourcenick 
    status_shard = params[:shard].downcase.to_sym if params.has_key? :shard

    if shards.has_key? status_shard
      m.reply [shards[status_shard].ircify, system[:login].ircify, system[:patch].ircify].join " \00306**\003 "
    else
      m.reply "I don't know anything about that shard. :("
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

  protected
  def get_default_shard(nick)
    k = "shard_#{nick}"
    return DEFAULT_SHARD unless @registry.key? k

    @registry[k].downcase.to_sym
  end
end 
plugin = RiftPlugin.new
plugin.map 'rift shard :shard', :action => 'status'
plugin.map 'rift set default :shard', :action => 'set_default_shard'
plugin.map 'rift', :action => 'status'
