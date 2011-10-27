class NanowrimoPlugin < Plugin
  NANO_GOAL = 50000.0 

  def progress(m, params)
    wc = `cd /home/nevans/nanowrimo_2011.git && git log -1 | grep "Word Count: " | awk '{ print $3 }'`.to_i
    
    now = Time.now
    if now.month == 11
      end_of_day_wc = ((NANO_GOAL / 30) * now.day).ceil
      
      if wc >= end_of_day_wc
        color = "\00303"
      else
        color = "\00304"
      end

      m.reply "Current wordcount: #{color}#{format_number(wc)}\003 / #{format_number(end_of_day_wc)}"
    else
      m.reply "It isn't November yet, but your word count is #{format_number(wc)}."
    end

  end # progress

  def format_number(int)
    if int.to_s.length > 3
      int.to_s.gsub!(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1,")
    else
      int
    end
  end
end 

plugin = NanowrimoPlugin.new
plugin.map 'nanowrimo', :action => 'progress'
