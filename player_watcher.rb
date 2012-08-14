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

if false
  host = "localhost"
  port = 6600

  addr = Socket.getaddrinfo(host, nil)

  watcher_socket = Socket.new(Socket.const_get(addr[0][0]), Socket::SOCK_STREAM, 0)


  socket = nil
  begin
    watcher_socket.connect_nonblock(Socket.pack_sockaddr_in(port, addr[0][3]))
  rescue Errno::EINPROGRESS
    sockets = IO.select([watcher_socket], nil, nil, 2)
    socket = sockets[0][0]
  end
end



#watcher_socket = Socket.new("localhost", 

watcher_socket = TCPSocket.open("localhost", 6600)

watcher_socket.gets


$pubsub = Redis.new
$pubsub.select 1

$pubsub.subscribe("player") do |on|
  on.message do |channel, msg|
    if msg == "load"
      playing = true

      until playing == false
        watcher_socket.puts "status"

        first_response = watcher_socket.gets
        if first_response =~ /volume/
          response = ''
          14.times do
            response = watcher_socket.gets
          end

          puts "Response: #{response}"
          
          3.times do
            watcher_socket.gets
          end
        else
          next
        end

        elapsed = response.split(" ").at(1).to_f

        $redis.set("player:current:position", elapsed)
        $redis.publish("position", elapsed)

        # add the next song from the playlist to the queue, if we're playing from a playlist
        playlist_id = nil
        playlist_id = $redis.get("current:playlist:id").to_i if $redis.get("current:playlist:id") != nil

        puts "Playlist: #{playlist_id}"

        track_data = nil

        fade_out_start = $redis.get("player:current:duration").to_f

        if playlist_id
          track_id = $redis.get("player:current:id")

          track_data = Assignment.where("track_id = #{track_id} AND playlist_id = #{playlist_id}").first
          
          if track_data != nil
            fade_out_start = track_data.fade_out if track_data.fade_out != nil
          end
        end

        if elapsed >= (fade_out_start - 2)
          puts "Ending playback watching"
          playing = false

          if track_data != nil
            puts "here"

            puts "Grabbing next song data"
            next_track = Assignment.where("playlist_id = #{playlist_id} AND `order` > #{track_data.order}").order('`order` ASC').limit(1).first
          end
          
          # Check to see if we're at the end of a playlist
          if next_track != nil
            puts next_track.inspect

            puts "Song ended"

            send_command 'load', next_track.track_id

            $redis.publish("player", "ended")

            if next_track.fade_in != nil
              send_command 'seek', next_track.fade_in
            end

            # Check to see if we need to to a crossfade effect
            if track_data
              if track_data.fade_type == 1
                # Okay here we do a record scratch effect
                sleep 0.3
                puts "Record scratch change"
                system("mpg123 /home/herb/git/amplifyu/system/effects/record-scratch.mp3")
              end
            end


          end
        end
        #puts elapsed.to_s

        sleep 0.2
       end
    end
  end
end
