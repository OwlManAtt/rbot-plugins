class PickPlugin < Plugin
  def pick(m, params)
    options = params[:stuff].join ' '
    m.reply options.split(',').pick_one.strip
  end # pick
end 
plugin = PickPlugin.new
plugin.map 'pick *stuff', :action => 'pick'
