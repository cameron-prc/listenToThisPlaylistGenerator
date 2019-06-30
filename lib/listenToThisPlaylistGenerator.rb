require 'open-uri'
require 'json'
require 'base64'
require 'json'
require 'rest-client'
require 'yaml'
require 'rspotify'

module ListenToThis

  ROOT_DIR = File.expand_path('..', __dir__)

  require File.join(ROOT_DIR, 'lib', 'listenToThisPlaylistGenerator', 'logger')
  require File.join(ROOT_DIR, 'lib', 'listenToThisPlaylistGenerator', 'core')
  require File.join(ROOT_DIR, 'lib', 'listenToThisPlaylistGenerator', 'spotify')
  require File.join(ROOT_DIR, 'lib', 'listenToThisPlaylistGenerator', 'reddit')

  CONFIG_DIR = File.join(ROOT_DIR, 'config')
  CONFIG = YAML.load_file File.join(CONFIG_DIR, 'main.yaml')
  LOGGER = ListenToThis::Logger.new

  def self.run(args = {})
    Core.new.run
  end
end
