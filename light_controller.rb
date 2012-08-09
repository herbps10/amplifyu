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

$dmx_state = [0] * 512

def send_dmx_command(channel, value)
  $dmx_state[channel - 1] = value

  dmx_data = $dmx_state.join(',')

  `./ola/examples/ola_streaming_client -u 0 -d #{dmx_data}`
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

        send_dmx_batch(10, ([Proc.new { rand(255) }] * 6).map { |e| e.call })

        #send_dmx_command(16, [0, 100, 200][rand(3)])
        send_dmx_command(16, 0)
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
