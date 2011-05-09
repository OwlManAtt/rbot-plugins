require 'open-uri'
require 'json'

class BitcoinPlugin < Plugin
    def help(plugin, topic='')
      "@bitcoin => owl's bitcoin mining status."
    end # help

    def status(m, params)
      json = open("http://mining.bitcoin.cz/accounts/profile/json/5339-b08a146b04934cec6e6d8041b014ec2f").read
      profile = JSON.parse(json)
  
      values = [profile['unconfirmed_reward'].to_f, profile['confirmed_reward'].to_f]
      values << values.sum
      
      display = values.map {|f| sprintf('%.2f',f) }
      
      m.reply "#{display[0]} unconfirmed + #{display[1]} confirmed = \00309#{display[2]} BTC\003"
    end # summon
end # BitcoinPlugin
plugin = BitcoinPlugin.new
plugin.map 'bitcoin', :action => 'status'
plugin.map 'riches and ores', :action => 'status'
