require 'yaml'

module Shenzhen
  VERSION = '0.0.5'

  config_path = "#{Dir.pwd}/config.yml"
  if File.exist?(config_path)
    CONFIG = YAML.load_file(config_path) #[RAILS_ENV]
  else
    CONFIG = nil
  end
end

require 'shenzhen/agvtool'
require 'shenzhen/xcodebuild'
