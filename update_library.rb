#
# File: update_library.rb
#
# Author: Herb Susmann
# Date: August, 2012
#
# Purpose: Goes through all the files in the music library
# and makes sure they're in the database. It also generates 
# a waveform image for use in the frontend.
#
# TODO: Hook this up so it automatically calls echonest.rb on the track
#

require 'socket'
require "mp3info"
require "mysql2"
require 'yaml'
require 'active_record'

db_config = YAML::load(File.new("data/database.yml").read)

ActiveRecord::Base.establish_connection(
  adapter: db_config['adapter'],
  user: db_config['user'],
  password: db_config['password'],
  host: db_config['host'],
  database: db_config['database'],
)

require './data/models/track.rb'

Dir.glob("music-library/**/*").each do |file|
  filename = file.split("/").at(1)

  track = Track.where("file = '" + filename.gsub("'", "''") + "'")

  if track.length == 0
    begin
      Mp3Info.open(file) do |mp3|
        track = Track.new
        
        track.duration = mp3.length
        track.name = mp3.tag.title
        track.artist = mp3.tag.artist
        track.album = mp3.tag.album
        track.file = filename

        track.save

        puts track.id
        puts file
        %x[ sox "#{file}" -c 1 -t wav - | ./wav2png --background-color=C7C7C7ff -o server/public/waveforms/#{track.id.to_s}.png /dev/stdin ]

        %x[ convert server/public/waveforms/#{track.id.to_s}.png -resize 700x109 server/public/waveforms/#{track.id.to_s}.png ]
      end
    rescue Mp3InfoError
      puts "Could not add " + file
    end
  end
end

socket = TCPSocket.open("localhost", 6600)
socket.puts("update")
