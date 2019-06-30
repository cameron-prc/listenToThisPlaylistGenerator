require 'open-uri'
require 'json'
require 'base64'
require 'json'
require 'rest-client'
require 'yaml'
require 'logger'


module ListenToThis
  class Core

    ARTIST_REGEX = /.+?(?= -)/
    TITLE_REGEX = /(?<=- ).+?(?= \[)/

    attr_accessor :reddit, :spotify

    def initialize
      @reddit = Reddit.new
      @spotify = Spotify.new
    end

    def run
      tracks = Array.new
      max_playlist_length = CONFIG['system']['max_playlist_length']
      max_depth = CONFIG['system']['max_depth']

      begin
        until tracks.length >= max_playlist_length || reddit.page >= max_depth
          reddit.next_page

          reddit.posts.each do |post|
            artist, title = get_song_details_from_post_title(post["data"]["title"])

            next unless artist && title

            song = spotify.search_for_song(title, artist)
            tracks << song if song

            break if tracks.length >= max_playlist_length
          end
        end
      rescue StandardError => e
        ListenToThis::LOGGER.error e

        exit 1
      end

      log_playlist(tracks) if spotify.update_playlist!(tracks)
    end

    private

    def log_playlist(tracks)
      ListenToThis::LOGGER.info "Playlist updated"
      ListenToThis::LOGGER.save_playlist(reddit.range, tracks.map { |track|
        { id: track.id, name: track.name, artist: track.artists.first.name }
      })
    end

    def get_song_details_from_post_title(post_title)
      artist = ARTIST_REGEX.match(post_title).to_s
      title = TITLE_REGEX.match(post_title).to_s

      [artist, title]
    end
  end
end
