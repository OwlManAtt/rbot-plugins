class TeatimePlugin < Plugin
    def help(plugin, topic='')
      "@tea [type] - Tea steeping timer."
    end # help

    def steep(m, params)
      type = params[:type].downcase
      times = {
        'green' => '3 minutes',
        'black' => '5 minutes',
        'oolong' => '5 minutes',
      }

      if times.has_key? type
        @bot.plugins['remind'].add_reminder(m.channel.to_s, "#{m.sourcenick}: Your tea is ready!", times[type])
        m.okay
      else
        m.reply "Sorry, I don't know about that kind of tea."
      end
    end # summon
end # TeatimePlugin 
plugin = TeatimePlugin.new
plugin.map 'tea :type', :action => 'steep', :defaults => {:type => 'green'}
