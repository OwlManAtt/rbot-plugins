require 'rubygems'
require 'open-uri'
require 'nokogiri'

class IanaPlugin < Plugin
  def help(plugin, topic='')
    "IANA depletion event utilities. @iana => current depletion date estimate. @iana remaining [verbose] => the number of unallocated /8s."
  end # help

  def iana(m, params)
    date = @bot.httputil.get('http://ipv4depletion.com/iana.js').gsub(/^.*?"(.*?)".*?$/, '\1')
    m.reply "Today's IANA depletion date estimate: #{date}"
  end # iana

  def remaining(m, params)
    m.reply "There are #{fetch_unallocated_records().size} unallocated blocks remaining."
  end # remaining

  def remaining_detail(m, params)
    records = fetch_unallocated_records()

    summary = records.map do |record|
      prefix = record.children[1].content.split('/')[0].to_i
      "#{prefix}.0.0.0/8"
    end

    m.reply "Remaining blocks (#{records.size}): " + (summary.join " \00306**\003 ")
  end

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

  protected
  def fetch_unallocated_records
    doc = Nokogiri::XML(open('http://www.iana.org/assignments/ipv4-address-space/ipv4-address-space.xml'))

    doc.search("record/status[text()='UNALLOCATED']").map(&:parent)
  end
end # OwlPlugin
plugin = IanaPlugin.new
plugin.map 'iana', :action => 'iana'
plugin.map 'iana remaining', :action => 'remaining'
plugin.map 'iana remaining verbose', :action => 'remaining_detail'
plugin.map 'rir remaining', :action => 'rir_remaining'

