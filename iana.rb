require 'rubygems'
require 'open-uri'
require 'nokogiri'

class IanaPlugin < Plugin
  def help(plugin, topic='')
    "IANA depletion event utilities. @iana => current depletion date estimate. @iana remaining => the number of unallocated /8s."
  end # help

  def iana(m, params)
    date = @bot.httputil.get('http://ipv4depletion.com/iana.js').gsub(/^.*?"(.*?)".*?$/, '\1')
    m.reply "Today's IANA depletion date estimate: #{date}"
  end # iana

  def remaining(m, params)
    m.reply "IANA allocated the final block on 2011-02-03 at 09:39 EST."
  end # remaining

  def rir_remaining(m, params)
    value_re = Regexp.new(/value=(.*?)&/)
    extract_value = lambda {|s| r = value_re.match(s); r and r[1].to_f }
    rir_names = ['arin', 'apnic', 'lacnic', 'ripencc', 'afrinic']
    rir_remaining = Hash.new
    for rir in rir_names
      res = @bot.httputil.get("http://www.ipv4depletion.com/flash/flashdata.pl?funcName=pmeter_#{rir}")
      rir_remaining[rir]=extract_value[res]
    end
    m.reply "Remaining blocks per RIR (/8s): %s" % \
        rir_remaining.map{|pair| "%s: %.3f" % pair }.join(" \00306**\003 ")
  end
end # OwlPlugin
plugin = IanaPlugin.new
plugin.map 'iana', :action => 'remaining'
plugin.map 'iana remaining', :action => 'remaining'
plugin.map 'rir remaining', :action => 'rir_remaining'

