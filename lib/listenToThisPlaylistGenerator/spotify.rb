require 'rspotify'

module ListenToThis
  class Spotify

    attr_reader :client_id, :client_secret, :user_id, :playlist_id, :refresh_token
    def initialize
      @client_id = ListenToThis::CONFIG['account']['client_id']
      @client_secret = ListenToThis::CONFIG['account']['client_secret']
      @user_id = ListenToThis::CONFIG['account']['user_id']
      @playlist_id = ListenToThis::CONFIG['account']['playlist_id']
      @refresh_token = ListenToThis::CONFIG['account']['refresh_token']

      # Initialize the RSpotify API wrapper and override the incorrectly generated access token
      RSpotify.authenticate(client_id, client_secret)
      RSpotify::User.class_variable_set(:@@users_credentials, { user_id => { token: token } })
    end

    def token
      @token ||= generate_access_token
    end

    def search_for_song(title, artist)
      query = "track:#{title} artist:#{artist}"

      RSpotify::Track.search(query).first
    end

    def update_playlist!(tracks)
      begin
        get_playlist.replace_tracks!(tracks)
      rescue StandardError => e
        ListenToThis::LOGGER.error "Failed to update playlist entries: #{e}"

        false
      end
    end

    def get_playlist
      RSpotify::Playlist.find(user_id, playlist_id)
    end

    private

    def generate_access_token
      authorization = Base64.strict_encode64 "#{client_id}:#{client_secret}"
      headers = { 'Authorization' => "Basic #{authorization}" }
      request_body = {
          grant_type: 'refresh_token',
          refresh_token: refresh_token
      }

      response = RestClient.post('https://accounts.spotify.com/api/token', request_body, headers)
      response = JSON.parse(response)

      response['access_token']
    end
  end
end