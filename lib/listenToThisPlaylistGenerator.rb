require 'open-uri'
require 'json'
require 'base64'
require 'json'
require 'restclient'

number_of_results = 0
songs = []
song_urls = []
page = ''
client_id = ''
client_secret = ''
refresh_token = ''
playlist_id = ''
user_id = ''
tracks = ""
first = true


while(number_of_results < 50) do
  puts 'loading page'
  url = "https://www.reddit.com/r/listentothis/top.json#{page}"
  open(url, 'User-Agent' => 'legitimateUser')  do |response|
    json = JSON.parse(response.read)
    items = json['data']['children']
    items.each do |item|
      artist = /.+?(?= -)/.match(item['data']['title']).to_s
      title = /(?<=- ).+?(?= \[)/.match(item['data']['title']).to_s
      songs.push ({:title => title, artist: artist})
        
      # Search Spotify for the track
      url = "https://api.spotify.com/v1/search?" + URI::encode("q=track:'#{title}' artist:'#{artist}'&type=track")
      data = RestClient.get url
      song_url = JSON.parse(data)['tracks']['items'][0]['uri'] rescue nil
        
      if song_url
        number_of_results = number_of_results + 1
        tracks << ',' if !first
        first = false
        tracks << "#{song_url}"
      end
        
      puts number_of_results
      break if number_of_results >= 50
    end
    page = "?count=25&after=#{json['data']['after']}&limit=25/"
  end rescue break
end



request_body = {
  grant_type: 'refresh_token',
  refresh_token: refresh_token
}
authorization = Base64.strict_encode64 "#{client_id}:#{client_secret}"

response = RestClient.post('https://accounts.spotify.com/api/token', request_body, { 'Authorization' => "Basic #{authorization}" })
response = JSON.parse(response)
access_token = response['access_token']

#
# Empty the playlist
#

url = "https://api.spotify.com/v1/users/#{user_id}/playlists/#{playlist_id}/tracks"
data = JSON.parse(RestClient.get(url, {:Authorization => "Bearer #{access_token}"}))
tracks_to_remove = []

data['items'].each do |item|
  if item['track']
    tracks_to_remove << {'uri' => item['track']['uri']}
  end
end

url = "https://api.spotify.com/v1/users/#{user_id}/playlists/#{playlist_id}/tracks"

params = {
  method: :delete,
  url: "https://api.spotify.com/v1/users/#{user_id}/playlists/#{playlist_id}/tracks",
  headers: {'Authorization' => "Bearer #{access_token}"},
  payload: { tracks: tracks_to_remove }
}

params[:payload] = params[:payload].to_json
response = RestClient::Request.execute(params)

#
# Build and log the new playlist
#

out_file = File.new("../playlists/listenToThis-#{Date.today}.txt", "w") || File.open("../playlists/listenToThis-#{Date.today}.txt", "w")
out_file.puts(tracks)
out_file.close

url = "https://api.spotify.com/v1/users/#{user_id}/playlists/#{playlist_id}/tracks?uris=#{URI::encode(tracks)}"
RestClient.post(url, {grant_type: 'client_credentials'}, {'Authorization' => "Bearer #{access_token}"})