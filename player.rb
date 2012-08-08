#
# File: player.rb
#
# Author: Herb Susmann
# Date: August, 2012
# 
# Purpose: listens to commands from the Redis backend queue
#  and controls the music playing through MPD accordingly
#
# The name of the redis queue the player pulls from
# is "player". The player pushes back out information
# to a pub/sub channel called "player" so other components
# can react.
#

require 'rubygems'
require 'redis'
require 'open4'
require 'mysql'
require 'active_record'
require 'yaml'
require 'pty'
require 'highline/system_extensions'

include HighLine::SystemExtensions


#########
# MYSQL #
#########

db_config = YAML::load(File.new("data/database.yml").read)

ActiveRecord::Base.establish_connection(
  adapter: db_config['adapter'],
  user: db_config['user'],
  password: db_config['password'],
  host: db_config['host'],
  database: db_config['database']
)

require './data/models/track.rb'

$pipe = "/tmp/mplayerpipe"


#########
# REDIS #
#########

$redis = Redis.new
$redis.select 1

$socket = TCPSocket.open("localhost", 6600)


#############
# FUNCTIONS #
#############

def send_command(command)
  puts "Sending command: " + command
  
  begin
    $socket.puts(command)
  rescue
    $socket = TCPSocket.open("localhost", 6600)
    send_command(command)
  end
end

#############
# MAIN LOOP #
#############

# Continually check player queue in redis for new things to do
while true
  # Pop off first command in queue
  _, id = $redis.brpop("player")
  command = $redis.hgetall(id.to_s)

  puts command

  ########
  # PLAY #
  ########

  if command['action'] == "play"
    $redis.set("player:status", "playing")
    send_command "play" 

  #########
  # PAUSE #
  #########

  elsif command['action'] == "pause"
    $redis.set("player:status", "paused")
    send_command "pause"
  
  ########
  # SEEK #
  ########

  elsif command['action'] == "seek"
    value = command['value'].to_i

    puts "Seek to #{value}"

    send_command 'seek 0 ' + value.to_s

    $redis.publish("player", "seek")

  ########
  # LOAD #
  ########

  elsif command['action'] == "load"

    # Load from database
    id = command['value']
    track = Track.find(id)

    # Send command to load the file.
    send_command 'delete 0'
    send_command 'add "' + track.file + '"'
    send_command 'play'

    # Update redis with current playing information
    $redis.set("player:current:id",       id.to_i)
    $redis.set("player:current:name",     track.name)
    $redis.set("player:current:artist",   track.artist)
    $redis.set("player:current:duration", track.duration)

    $redis.set("player:current:key", track.key)
    $redis.set("player:current:mode", track.mode)

    $redis.set("player:status", "playing")

    $redis.publish("player", "load")

  ########
  # STOP #
  ########

  elsif command['action'] == "stop"

    send_command 'stop'

    $redis.set("player:status", "stopped")


  ##########
  # VOLUME #
  ##########

  elsif command['action'] == 'volume'

    volume = command['value']
    
    $redis.set("player:volume", volume)
    send_command "setvol #{volume}"

  end
end

$watcher.join
