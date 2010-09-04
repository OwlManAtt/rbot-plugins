class OwlPlugin < Plugin
    def initialize
        super
        @mpc_command = "export MPD_HOST=dicks@10.0.16.11; /usr/bin/mpc"
    end # initialize

    def help(plugin, topic='')
        "Attempts to summon forth an owl by playing EXTREMELY LOUD MUSIC right next to his bed."
    end # help

    def summon(m, params)
        `#{@mpc_command} load ysogg`
        `#{@mpc_command} play`

        m.reply "Yasashii Radio enabled on hina." 
    end # summon

    def abort(m, params)
       `#{@mpc_command} stop` 

        m.reply "Canceling noise."
    end # abort

end # OwlPlugin
plugin = OwlPlugin.new
plugin.map 'owl abort', :action => 'abort'
plugin.map 'owl', :action => 'summon'

