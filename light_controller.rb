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
require 'thread'

#########
# MYSQL #
#########

db_config = YAML::load(File.new("data/database.yml").read)

$dmx_state = [0] * 512

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

$streamer = IO.popen('/home/herb/git/amplifyu/system/ola/examples/ola_streaming_client', 'w')

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

  def prepare_dmx(name, index, value)
    channel = @light.dmx_channels.where("name = '#{name}'").at(index)

    if value.is_a? String
      range = channel.dmx_ranges.where("name = '#{value}'").first

      $dmx_state[(@channel_start + channel.channel) - 1] = range.start + 1
    else
      $dmx_state[(@channel_start + channel.channel) - 1] = value
    end
  end

  def send_command_wait(name, index, value)
    prepare_dmx(name, index, value)
  end

  def send_command(name, index, value)
    prepare_dmx(name, index, value)

    send_dmx_data
  end
end

def send_dmx_data

  data = $dmx_state.join(',')

  #`./ola/examples/ola_streaming_client -u -0 -d #{data}`

  pid = Process.fork
  if pid == nil
    exec "./ola/examples/ola_streaming_client -u 0 -d #{data}"
  else
    Process.detach(pid)
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


$lights[3].send_command("strobe", 0, "shutter open")
#$lights[3].send_command_wait("yoke course", 0, 50)
$lights[3].send_command("color", 0, "color 7")
#$lights[3].send_command_wait("gobo rotation", 0, 250)

$lights[3].send_command("gobos", 0, "gobo 5")

$lights[0].send_command_wait("pod", 0, "blue")

$lights[3].send_command_wait("base course", 0, 255);

send_dmx_data

if false
  [1, 2].each do |light|
    ["red", "green", "blue"].each do |color|
      [0, 1, 2].each do |index|
        #$lights[light].send_command_wait(color, index, rand() * 255)
        $lights[light].send_command_wait("red", index, index * 100)
      end
      sleep rand() * 2.0
    end
  end
end

def get_track_sections(track)
  return track.sections.where('confidence > 0.0').order('id ASC').all
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
    $lights[3].send_command("color", 0, "color 2")
  elsif color == "green"
    $lights[3].send_command("color", 0, "color 5")
  elsif color == "red"
    $lights[3].send_command("color", 0, "color 7")
  end
end

def randomized_yoke_positions
  positions = []

  positions[0] = [rand() * 255, rand() * 255]
  positions[1] = [positions[0][0] - rand() * 100, positions[0][1] - rand() * 100]
  positions[2] = [positions[0][0] + rand() * 100, positions[0][1] + rand() * 100]

  positions
end

$pubsub = Redis.new
$pubsub.select 1

$redis = Redis.new
$redis.select 1

track = Track.find($redis.get("player:current:id"))
sections = get_track_sections(track)

section_index = 0

yoke_positions = randomized_yoke_positions
puts yoke_positions.inspect
yoke_index = 0

beat_thread = nil

$pubsub.subscribe("player", "position") do |on|
  on.message do |channel, msg|
    return if sections == nil

    if channel == "player"
      if msg == "load"
        id = $redis.get('player:current:id')

        track = Track.find(id)
        sections = get_track_sections(track)

        section_index = 0

        beat_thread.kill unless beat_thread == nil
        beat_thread = Thread.new(track.tempo.to_f) do |bpm|
          pause = 1.0 / (bpm / 60.0)
          index = 0

          while true
            time_start = Time.now

            if index >= 0 and index <= 5
              puts "index: #{index}"
              $lights[0].send_command_wait("pod", index, ["red", "green", "blue"].at(rand() * 3))
              send_dmx_data
            end

            
            if index == 6
              5.times do |i|
                puts i
                $lights[0].send_command_wait("pod", i, "no_function")
              end
              send_dmx_data
            end

            index = (index + 1) % 7

            ActiveRecord::Base.connection.close


            until (Time.now() - time_start) >= pause
            end
          end
        end


      end

      if msg == "ended"
        beat_thread.kill unless beat_thread == nil
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
        $dmx_state = [0] * 512
        send_dmx_data
      end

      puts "MEssage: #{msg}"
    end


    if channel == "position"
      next_start = track.duration
      next_start = sections[section_index + 1].start.to_f if section_index + 1 < sections.length

      $lights[3].send_command_wait("base course", 0, yoke_positions[yoke_index][0])
      $lights[3].send_command_wait("yoke course", 0, yoke_positions[yoke_index][1])

      puts "Randomizing yoke location to #{yoke_positions[yoke_index][0]}, #{yoke_positions[yoke_index][1]}"

      send_dmx_data
      
      yoke_index = (yoke_index + 1) % 3
      
      until sections[section_index].start.to_f <= msg.to_f && next_start >= msg.to_f
        break if section_index + 1 == sections.length
        section_index += 1
        next_start = track.duration
        next_start = sections[section_index + 1].start.to_f if sections[section_index + 1] != nil

        puts "Changing sections"

        yoke_positions = randomized_yoke_positions

        # Change the yoke color
        $lights[3].send_command_wait("color", 0, ["color 1", "color 2", "color 3", "color 4", "color 5", "color 6", "color 7"].at(rand() * 7))

        # Change the iSpot gobo
        $lights[3].send_command_wait("gobos", 0, ["gobo 1", "gobo 2", "gobo 3", "gobo 4", "gobo 5", "gobo 6"].at(rand() * 6))

        send_dmx_data


        if section_index < sections.length - 1
          colors = {}
          if track.mode == "major"
            puts 'Major key'
            colors = {
              "red"   => rand() * 255,
              "green" => rand() * 255, 
              "blue"  => rand() * 255 
            }
          else
            puts 'Minor key'

            colors = {
              "red"   => 255,
              "green" => rand() * 100,
              "blue"  => rand() * 100,
            }
          end
          
          if get_avg_loudness(sections[section_index]) > -15
            if get_avg_loudness(sections[section_index + 1]) > get_avg_loudness(sections[section_index])
              puts "Louder section"

              # This section is louder than the previous section
              [1, 2].each do |light|
                Thread.new(light) do |light|

                  brightness = 0

                  until colors["red"] * brightness >= colors["red"] and colors["green"] * brightness >= colors["green"] and colors["blue"] * brightness >= colors["blue"]
                    ["red", "green", "blue"].each do |color|
                      [0, 1, 2].each do |index|
                        $lights[light].send_command_wait(color, index, colors[color] * brightness)
                      end
                    end

                    send_dmx_data


                    brightness += 0.1

                  end

                end

                ActiveRecord::Base.connection.close

                
              end


              # Have the iSpot strobe for a second
              Thread.new do
                puts "Strobing the iSpot"
                $lights[3].send_command_wait("strobe", 0, 120) # enable the strobe
                sleep 2
                $lights[3].send_command_wait("strobe", 0, "shutter open")

                send_dmx_data

                ActiveRecord::Base.connection.close
              end

            else
              # This section is quieter than the previous section
              puts "Quieter section"

              [1, 2].each do |light|
                
                Thread.new(light) do |light|
                  brightness = 255
                  until brightness <= 10
                    [0, 1, 2].each do |index|
                      $lights[light].send_command_wait("red", index, brightness)
                      $lights[light].send_command_wait("green", index, brightness)
                      $lights[light].send_command_wait("blue", index, brightness)
                    end

                    send_dmx_data
                    

                    brightness -= 10

                  end

                  ActiveRecord::Base.connection.close
                end

              end

            end
          else
            
                        
          end
        end

        $lights[3].send_command_wait("base course", 0, rand() * 255)
        send_dmx_data
      end

      puts sections[section_index].end.to_s + ", " + msg.to_s
      puts section_index

      puts 'Loudness ' + get_avg_loudness(sections[section_index]).to_s

      if get_avg_loudness(sections[section_index]) < -14

        # Turn off all the lights

        puts 'Turning off all the lights'

        [1, 2].each do |light|
          [0, 1, 2].each do |index|
            $lights[light].send_command_wait("red", index, 0)
            $lights[light].send_command_wait("green", index, 0)
            $lights[light].send_command_wait("blue", index, 0)
          end
        end


        $lights[3].send_command_wait("strobe", 0, "shutter closed")
        yoke_positions = [[120, 50]] * 3

        send_dmx_data


     elsif get_avg_loudness(sections[section_index]) < -10.5
      yoke_positions = [[120, 50]] * 3

      $lights[3].send_command_wait("strobe", 0, "shutter open")

      send_dmx_data
     end


      ##
      ## If this section is louder than the next section
      ##
      if section_index < sections.length - 1
        if get_avg_loudness(sections[section_index]) > get_avg_loudness(sections[section_index + 1])
        else
          
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
      send_dmx_data
    end
  end
end
