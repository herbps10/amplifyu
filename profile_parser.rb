require 'rubygems'
require 'mysql'
require 'active_record'
require 'yaml'

light_id      = ARGV[0]
profile_file  = ARGV[1]

profile = File.new("data/#{profile_file}").readlines

db_config = YAML::load(File.new("data/database.yml").read)

ActiveRecord::Base.establish_connection(
  adapter: db_config['adapter'],
  user: db_config['user'],
  password: db_config['password'],
  host: db_config['host'],
  database: db_config['database']
)

require './data/models/channel.rb'
require './data/models/range.rb'

channel_index = 0
profile.each_with_index do |line, index|
  channels = line.scan(/Channel = ([a-zA-Z _]+)/)
  
  if channels.length > 0
    # We're on a channel line.
    # Ostensibly the next line will describe that channel.

    description = profile[index + 1].chomp

    if description.length > 0
      # Okay, now we have a description line.

      # First, add the dmx channel to the database
      channel = DMXChannel.new(
        :channel  => channel_index,
        :name     => channels[0][0],
        :light_id => light_id
      )

      channel.save

      # Now comes the tricky part.
      # We split it by spaces, then build the ranges from there

      bits = description.split(' ')

      ranges = []

      range = ""
      commas_seen = 0
      bits.each do |bit|
        range += bit

        commas_seen += bit.scan(/,/).length

        if commas_seen == 2
          ranges.push range
          range = ""
          commas_seen = 0
        end
      end
      

      # Now we have an array that contains little strings that look like this:
      # "GreenLED,0,127", "Dimminspeed0-100%,128,169", etc.
      # So each one has the name, the start of the range, and the end of the range, neatly seperated by commas.

      ranges.each do |range|
        name, range_start, range_end = range.split(',')

        # Now, add it to the database
        range = DMXRange.new(
          :name           => name,
          :start          => range_start,
          :end            => range_end,
          :dmx_channel_id => channel.id
        )

        range.save
      end


      channel_index += 1

    end
  end
end
