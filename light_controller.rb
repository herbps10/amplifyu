#
# File: echonest.rb
# 
# Author: Herb Susmann
# Date: August 2012
#
# Purpose: The light controller listens to events coming from
# the music player and makes the lights respond accordingly.
#

require 'rubygems'
require 'redis'
require 'yaml'
require 'mysql'
require 'active_record'

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
require './data/models/section.rb'
require './data/models/segment.rb'
require './data/models/user_light.rb'
require './data/models/dmx_channel.rb'
require './data/models/dmx_range.rb'
require './data/models/light.rb'


$dmx_state = [0] * 512

def send_dmx_command(channel, value)
  $dmx_state[channel - 1] = value
  
  send_dmx_data
end

def send_dmx_data
  dmx_data = $dmx_state.join(',')

  `./ola/examples/ola_streaming_client -u 0 -d #{dmx_data}`
end


class LightControl
  def initialize(channel_start, light)
    @channel_start = channel_start
    @light = light
  end

  def prepare_dmx(name, index, value)
    channel = @light.dmx_channels.where("name = '#{name}'").at(index)

    if value.is_a? String
    # Retrieve the right DMX value to send
      range = channel.dmx_ranges.where("name = '#{value}'").first

      puts range.inspect

      $dmx_state[@channel_start + channel.channel - 1] = range.start + 1
      puts "Channel: " + (@channel_start + channel.channel - 1).to_s + " Value: " + (range.start + 1).to_s

    else
      $dmx_state[@channel_start + channel.channel - 1] = value

    end
  end

  def send_command_wait(name, index, value)
    prepare_dmx(name, index, value)
  end

  def send_command(name, index, value)
    send_command_wait(name, index, value)

    send_dmx_data
  end
end

def get_user_lights(user_id)
  lights = []

  user_lights = UserLight.where("user_id = #{user_id}")

  user_lights.each do |user_light|
    lights.push LightControl.new(user_light.start_dmx_channel, user_light.light)
  end

  return lights
end

$lights = get_user_lights(1)

puts $lights[3].inspect

$lights[3].send_command_wait("strobe", 0, "shutter open")
#$lights[3].send_command_wait("yoke course", 0, 50)
$lights[3].send_command_wait("color", 0, "color 7")
#$lights[3].send_command_wait("gobo rotation", 0, 250)

send_dmx_data

$lights[3].send_command_wait("gobos", 0, "gobo 5")

send_dmx_data

#exit

if false
  send_dmx_data
  [1, 2].each do |light|
    ["red", "green", "blue"].each do |color|
      [0, 1, 2].each do |index|
        #$lights[light].send_command_wait(color, index, rand() * 255)
        $lights[light].send_command_wait("red", index, index * 100)
      end
      send_dmx_data
      sleep 1
    end
  end
end

def send_dmx_batch(start, values)
  values.each_with_index do |value, index|
    $dmx_state[start - 1 + index] = value
  end

  dmx_data = $dmx_state.join(',')

  `./ola/examples/ola_streaming_client -u 0 -d #{dmx_data}`
end

def turn_on_pod(number, value)
  pod_base = 10

  puts pod_base + number

  send_dmx_command(pod_base + number, value)
end

def set_strobe_speed(speed)

end

def set_strobe_intensity(brightness)
  send_dmx_command(5, brightness)
end

def turn_on_blinder
  send_dmx_command(4, 100)
  send_dmx_command(5, 0)
end

def turn_off_blinder
  send_dmx_command(4, 0)
  send_dmx_command(5, 0)
end

def turn_on_strobes
  turn_off_blinder
  set_strobe_speed(100)
  set_strobe_intensity(100)
end

def get_track_sections(track)
  return track.sections.where('confidence > 0.3').order('id ASC').all
end

def get_avg_loudness(segment)
    avg = Segment.select("AVG(loudness) as loudness").where("start > " + segment.start.to_s + " and end < " + segment.end.to_s).first
    return avg.loudness
end

def set_all_to_color(color)
  (["red", "green", "blue"] - [color]).each do |color|
    [1,2].each do |light|
      [0,1,2].each do |index|
        $lights[light].send_command_wait(color, index, 0)
      end
    end
  end


  [1, 2].each do |light|
    [0, 1, 2].each do |index|
      $lights[light].send_command_wait(color, index, 255)
    end
  end
  
  if color == "blue"
    $lights[3].send_command_wait("color", 0, "color 2")
  elsif color == "green"
    $lights[3].send_command_wait("color", 0, "color 5")
  elsif color == "red"
    $lights[3].send_command_wait("color", 0, "color 7")
  end

  send_dmx_data
end

$pubsub = Redis.new
$pubsub.select 1

$redis = Redis.new
$redis.select 1

track = Track.find($redis.get("player:current:id"))
sections = get_track_sections(track)

section_index = 0

$pubsub.subscribe("player", "position") do |on|
  on.message do |channel, msg|

    if channel == "player"
      if msg == "load"
        id = $redis.get('player:current:id')

        track = Track.find(id)
        sections = get_track_sections(track)

        section_index = 0
      end

      if msg == "seek"
        section_index = 0
      end

      if msg == "blue"
        puts "Blue message"

        set_all_to_color('blue') 
      end

      if msg == "green"
        puts 'Green message'
        set_all_to_color('green')
      end

      if msg == "red"
        puts "Red message"
        set_all_to_color('red') 
      end

      if msg == "turnoffeverything"
        $dmx_state = [0] * 255
        send_dmx_data
      end
    end


    if channel == "position"
      next_start = track.duration
      next_start = sections[section_index + 1].start.to_f if section_index + 1 < sections.length

      until sections[section_index].start.to_f <= msg.to_f && next_start >= msg.to_f
        break if section_index + 1 == sections.length
        section_index += 1
        next_start = track.duration
        next_start = sections[section_index + 1].start.to_f if sections[section_index + 1] != nil

        puts "Changing sections"

        #send_dmx_batch(10, ([Proc.new { rand(255) }] * 6).map { |e| e.call })

        #send_dmx_command(16, [0, 100, 200][rand(3)])
        #send_dmx_command(16, 0)
        [1, 2].each do |light|
          ["red", "green", "blue"].each do |color|
            [0, 1, 2].each do |index|
              $lights[light].send_command_wait(color, index, rand() * 255)
            end
            send_dmx_data
          end
        end

        $lights[3].send_command("base course", 0, rand() * 255)
      end

      puts sections[section_index].end.to_s + ", " + msg.to_s
      puts section_index
      
      ##
      ## If this section is louder than the next section
      ##
      if section_index < sections.length - 1
        if get_avg_loudness(sections[section_index]) > get_avg_loudness(sections[section_index + 1])
          turn_off_blinder();
        end

        ##
        ## If this section is quieter than the next section
        ##
        if get_avg_loudness(sections[section_index]) < get_avg_loudness(sections[section_index + 1])
          if(track.mode == "major")
            #puts "Since this is a major key, enable the strobes"

            #turn_on_strobes();
          else 
            #turn_on_blinder();
          end
        end
      end
    end
  end
end
