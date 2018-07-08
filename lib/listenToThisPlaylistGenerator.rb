require 'open-uri'
require 'json'
require 'base64'
require 'json'
require 'restclient'
require 'yaml'
require 'logger'


root_dir = File.expand_path('..', __dir__)
config_dir = File.join(root_dir, 'config')
playlist_dir = File.join(root_dir, 'playlists')

config = YAML.load_file File.join(config_dir, 'main.yaml')
logger = Logger.new(File.join(root_dir, 'log.log'), 'daily')

logger.level = Logger.const_get config['system']['log_level']

current_depth = 1
number_of_results = 0
songs = []
song_urls = []
page = ''
max_entries_reached = false

begin
  request_body = {
    grant_type: 'refresh_token',
    refresh_token: config['account']['refresh_token']
  }

  authorization = Base64.strict_encode64 "#{config['account']['client_id']}:#{config['account']['client_secret']}"
  response = RestClient.post('https://accounts.spotify.com/api/token', request_body, { 'Authorization' => "Basic #{authorization}" })
  response = JSON.parse(response)
  access_token = response['access_token']

rescue Exception => e
  logger.fatal "Unable to obtain authentication token: #{e}"

  throw e
end


loop do

  listen_to_this_url = "#{config['urls']['reddit_base']}#{config['urls'][config['system']['range']]}#{page}"

  logger.debug "Loading content from #{listen_to_this_url}"

  begin
    open(listen_to_this_url, 'User-Agent' => 'legitimateUser')  do |response|

      json = JSON.parse(response.read)
      items = json['data']['children']

      items.each do |item|
        artist = /.+?(?= -)/.match(item['data']['title']).to_s
        title = /(?<=- ).+?(?= \[)/.match(item['data']['title']).to_s

        if artist.empty? or title.empty?
          logger.debug "Failed to parse \"#{item}\" - (title: #{title} , artist: #{artist})"

          next
        end

        url = "#{config['urls']['spotify_base']}search?" + URI::encode("q=track:#{title} artist:#{artist}&type=track")

        logger.debug "Searching for \"#{title}\" by \"#{artist}\" with \"#{url}\""
          
        # Search Spotify for the track
        begin
          data = JSON.parse(RestClient.get(url, {:Authorization => "Bearer #{access_token}"}))
        rescue Exception => e
          logger.fatal "Failed to search spotify with #{url}: #{e}"

          throw e
        end
      
        song_url = data['tracks']['items'][0]['uri'] rescue nil
          
        if song_url
          number_of_results += 1
          song_urls << song_url
          songs << "#{song_url} #{title} - #{artist}"

          logger.debug "Found song \"#{title} by #{artist}\"."
        else
          logger.debug "Unable to find song \"#{title} by #{artist}\"."
        end
          
        if number_of_results >= 50
          max_entries_reached = true

          break
        end
      end

      page = "&count=25&after=#{json['data']['after']}&limit=25/"
    end

  rescue Exception => e
    logger.error "Failed to load reddit page #{listen_to_this_url}: #{e}"

    throw e
  ensure
    if max_entries_reached
      logger.debug "Song limit of #{config['system']['max_playlist_length']} reached."

      break
    end

    if current_depth >= config['system']['max_depth']
      logger.debug "Maximum page depth of #{config['system']['max_depth']} reached with #{number_of_results}."

      break
    end

    current_depth += 1
  end
end

#
# Empty the playlist
#
playlist_url = "#{config['urls']['spotify_base']}users/#{config['account']['user_id']}/playlists/#{config['account']['playlist_id']}/tracks"
data = JSON.parse(RestClient.get(playlist_url, {:Authorization => "Bearer #{access_token}"}))
tracks_to_remove = []

data['items'].each do |item|
  if item['track']
    tracks_to_remove << {'uri' => item['track']['uri']}
  end
end


params = {
  method: :delete,
  url: playlist_url,
  headers: {'Authorization' => "Bearer #{access_token}"},
  payload: { tracks: tracks_to_remove }.to_json
}

#params[:payload] = params[:payload].to_json

begin
  RestClient::Request.execute(params)
rescue Exception => e
  logger.error "Unable to empty playlist #{config['account']['playlist_id']}: #{e}"

  throw e
end

#
# Build and log the new playlist
#
song_urls_string = song_urls.join(',')
songs_string = songs.join("\n")
playlist_backup_name = "listenToThis-#{Date.today}-#{config['system']['range']}.txt"

Dir.mkdir(playlist_dir) unless File.exists?(playlist_dir)

out_file = File.new("#{playlist_dir}/#{playlist_backup_name}", "w") || File.open("#{playlist_dir}/#{playlist_backup_name}", "w")
out_file.puts(songs_string)
out_file.close

begin
  url = "#{playlist_url}?uris=#{URI::encode(song_urls_string)}"
  RestClient.post(url, {grant_type: 'client_credentials'}, {'Authorization' => "Bearer #{access_token}"})
rescue Exception => e
  logger.error "Unable to update playlist #{config['account']['playlist_id']}: #{e}"
end
