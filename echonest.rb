
# File: echonest.rb
# 
# Author: Herb Susmann
# Date: August 12
#
# Purpose: Download Echonest API information for a specific track
# in the music library
#
# Usage: echonest.rb song.mp3
#
# The track must already be in the database for this script to work.
#

require 'rubygems'
require 'json'
require 'mysql'
require 'active_record'

db_config = YAML::load(File.new("/home/herb/git/amplifyu/system/data/database.yml").read)

ActiveRecord::Base.establish_connection(
  adapter: db_config['adapter'],
  user: db_config['user'],
  password: db_config['password'],
  host: db_config['host'],
  database: db_config['database']
)

require '/home/herb/git/amplifyu/system/data/models/track.rb'
require '/home/herb/git/amplifyu/system/data/models/section.rb'
require '/home/herb/git/amplifyu/system/data/models/segment.rb'

$api_key = 'TCVN6FSMVZYKYAPOS'

def upload_json(filename)
  return JSON.parse(`curl -X POST -H "Content-Type:application/octet-stream" "http://developer.echonest.com/api/v4/track/upload?api_key=#{$api_key}&filetype=mp3" --data-binary "@/home/herb/git/amplifyu/system/music-library/#{filename}"`)
end

def profile_json(upload_id)
  return JSON.parse(`curl -F "api_key=#{$api_key}" -F "format=json" -F "id=#{upload_id}" -F "bucket=audio_summary" "http://developer.echonest.com/api/v4/track/analyze"`)
end

def raw_song_data(url)
  return `curl "#{url}"`
end


filename = ARGV[0].gsub('./music-library/', '')

puts filename
track = Track.where("file = '#{filename}'").first

# Clean out the database in case this script has been run
# before on this track
Segment.delete_all("track_id = #{track.id}")
Section.delete_all("track_id = #{track.id}")

#
# Only download from the Echonest servers if we haven't cached this track's
# API information in the database.
#
# If we have downloaded it before, skip this part and jump right to parsing
# the response.
#
if(track.echonest_detailed_json == nil or track.echonest_detailed_json == '')
  upload_json = upload_json(filename)

  # First, upload the file to echonest
  puts upload_json

  upload_id = upload_json["response"]["track"]["id"]

  profile_json = profile_json(upload_id)

  # Now, download the succinct profile information
  expanded_profile_url = profile_json["response"]["track"]["audio_summary"]["analysis_url"]

  raw_song_data = raw_song_data(expanded_profile_url)

  track.echonest_detailed_json = raw_song_data

  track.save
end

song_data = JSON.parse(track.echonest_detailed_json)


#
# Save track information
#
keys = ['c', 'c-sharp', 'd', 'e-flat', 'e', 'f', 'f-sharp', 'g', 'a-flat', 'a', 'b-flat', 'b']
track.mode = song_data['track']['mode'].to_i == 0 ? 'minor' : 'major'
track.tempo = song_data['track']['tempo'].to_i
track.key = keys[song_data['track']['key'].to_i]
track.fade_in_end = song_data['track']['end_of_fade_in'].to_f
track.fade_out_start = song_data['track']['start_of_fade_out'].to_f
track.genre = song_data['meta']['genre']

track.save

#
# Save section data
# 
# Sections are portions of the song that vary significantly.
# For example, the chorus and verse would be different sections.
#
song_data['sections'].each do |section_data|
  section = Section.new
  section.track_id = track.id
  section.start = section_data['start'].to_f
  section.end = section_data['start'].to_f + section_data['duration'].to_f
  section.confidence = section_data['confidence'].to_f
  section.save
end

#
# Save segment data
#
# Segments are short periods in the song
#
song_data['segments'].each do |segment_data|
  segment = Segment.new
  segment.track_id = track.id
  segment.start = segment_data['start'].to_f
  segment.end = segment_data['start'].to_f + segment_data['duration'].to_f
  segment.confidence = segment_data['confidence'].to_f
  segment.loudness = segment_data['loudness_max'].to_f
  
  segment.save
end
