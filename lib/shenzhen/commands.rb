$:.push File.expand_path('../', __FILE__)

require 'plugins/testflight'
require 'plugins/kw_app_distribution'

require 'commands/build'
require 'commands/distribute'

