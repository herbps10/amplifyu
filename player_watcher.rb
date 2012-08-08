#
# File: player_watcher.rb
# 
# Author: Herb Susmann
# Date: August 2012
#
# Purpose: Watches output from MPD and pushes the
# information to a Redis pub/sub channel. Also
# handles loading the next song from the playlist
#
# Track position information is pushed to the "position" channel
#

require 'rubygems'
require 'redis'
require 'yaml'
require 'mysql'
require 'active_record'

$redis_config = YAML::load(File.new("data/database.yml").read)

ActiveRecord::Base.establish_connection(
  adapter: $redis_config['adapter'],
  user: $redis_config['user'],
  password: $redis_config['password'],
  host: $redis_config['host'],
  database: $redis_config['database']
)

require './data/models/track.rb'
require './data/models/playlist.rb'
require './data/models/assignment.rb'

def send_command(action, value = nil)
  id = redis_get_current_command_id
  command = redis_command(id) 
  $redis.hset(redis_command(id), "type", "player")
  $redis.hset(redis_command(id), "action", action)

  if(value != nil)
    $redis.hset(redis_command(id), "value", value)
  end

  $redis.lpush("player", redis_command(id))
end

def redis_command(id)
  return "command:" + id.to_s
end

def redis_get_current_command_id
  $redis.incr 'id'
  return $redis.get 'id'
end


$redis = Redis.new
$redis.select 1

watcher_socket = TCPSocket.open("localhost", 6600)

while true

  watcher_socket.puts("status")

  response = watcher_socket.gets

  until response =~ /elapsed/
    response = watcher_socket.gets
  end

  elapsed = response.split(" ").at(1).to_f

  $redis.set("player:current:position", elapsed)
  $redis.publish("position", elapsed)

  # add the next song from the playlist to the queue, if we're playing from a playlist
  playlist_id = $redis.get("current:playlist:id").to_i

  puts "Playlist: #{playlist_id}"

  if playlist_id
    track_id = $redis.get("player:current:id")
    track_data = Assignment.where("track_id = #{track_id} AND playlist_id = #{playlist_id}").first

    fade_out_start = track_data.fade_out
    fade_out_start = $redis.get("player:current:duration").to_f if fade_out_start == nil

    if elapsed >= (fade_out_start - 2)
      next_track = Assignment.where("playlist_id = #{playlist_id} AND `order` > #{track_data.order}").limit(1).first
      
      # Check to see if we're at the end of a playlist
      if next_track != nil
        puts next_track.inspect

        puts "Song ended"

        send_command 'load', next_track.track_id

        if next_track.fade_in != nil
          send_command 'seek', next_track.fade_in
        end
      end
    end
  end

  #puts elapsed.to_s

  sleep 0.2
end
puts "Done"
