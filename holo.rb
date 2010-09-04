require 'rubygems'
require 'nokogiri'
require 'open-uri'

class HoloPlugin < Plugin
  def initialize
    @tracking_numbers = {
      #'Case' => '1ZX799390310081385',
      'Disks' => '1Z462E560321092067',
      'Fans' => '1ZX799470329512449',
      #'Everything else' => '1ZX799331231131463'
    }
    super
  end # initialize 

  def status(m, params)
    status_fetch.each {|msg| m.reply msg}
  end # status

  def status_fetch
    result = @tracking_numbers.map do |label,number|
      doc = Nokogiri::HTML(open("http://wwwapps.ups.com/WebTracking/processInputRequest?sort_by=status&tracknums_displayed=1&TypeOfInquiryNumber=T&loc=en_US&InquiryNumber1=#{number}&track.x=0&track.y=0"))
      latest_row = doc.search('fieldset[@id=showPackageProgress]//tr')[1]
      if latest_row
        datum = {
          :location => latest_row.children[0].children.first.content.ircify_html,
          :time => latest_row.children[2].content.ircify_html << " " << latest_row.children[4].content.ircify_html,
          :activity => latest_row.children[6].content.ircify_html,
        }
        
        "\00303#{label}\003: #{datum[:activity]} @ #{datum[:time]} - #{datum[:location]}"
      else
        "\00303#{label}\003: No information available."
      end
    end

    return result
  end # status_fetch

  def whine(m, params)
    status_fetch.each {|msg| @bot.say '#', msg}
  end

end # OwlPlugin
plugin = HoloPlugin.new
plugin.map 'holo', :action => 'status'
plugin.map 'holo whine', :action => 'whine'

