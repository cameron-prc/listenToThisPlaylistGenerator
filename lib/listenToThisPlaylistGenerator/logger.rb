require 'firebase'

module ListenToThis
  class Logger

    attr_reader :firebase

    def initialize
      base_uri = ListenToThis::CONFIG["urls"]["firebase"]

      @firebase = Firebase::Client.new(base_uri)
    end

    def save_playlist(range, songs)
      push("#{range}-playlists", { date: DateTime.now, songs: songs, '.priority': 1 })
    end

    def info(message)
      log(:INFO, message)
    end

    def error(message)
      log(:ERROR, message)
    end

    private

    def log(level, message)
      push("logs", { date: DateTime.now, level: level.to_s, message: message, '.priority': 1 })
    end

    def push(path, data)
      firebase.push(path, data)
    end
  end
end
