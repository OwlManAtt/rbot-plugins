require 'open-uri'
require 'json'

class BitcoinPlugin < Plugin
    def help(plugin, topic='')
      "@bitcoin => owl's bitcoin mining status."
    end # help

    def status(m, params)
      json = open("https://mining.bitcoin.cz/accounts/profile/json/5339-b08a146b04934cec6e6d8041b014ec2f").read
      profile = JSON.parse(json)
      coins = profile['unconfirmed_reward'].to_f + profile['confirmed_reward'].to_f  
      m.reply "Balance: #{coins} BTC"

      #ticker_json = open('https://mtgox.com/code/data/ticker.php', {:ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE}).read
      #ticker_json = open('https://mtgox.com/code/data/ticker.php').read
      #t = JSON.parse(ticker_json)
      #t = t['ticker']
      #coin_value = coins * t['buy'].to_f
     
      #values = [coins, coin_value]
      #display = values.map {|f| sprintf('%.2f',f) }
      
      #m.reply "#{display[0]} BTC = #{display[1]} USD"
    end # summon
end # BitcoinPlugin
plugin = BitcoinPlugin.new
plugin.map 'bitcoin', :action => 'status'
plugin.map 'riches and ores', :action => 'status'
