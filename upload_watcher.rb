require 'rubygems'
require 'redis'

$redis = Redis.new
$redis.select 1

$redis.subscribe('uploads') do |on|
  on.message do |channel, msg|
    name = msg

    puts "UPLOADED: #{name}"

    `ruby ./update_library.rb`
    command = "ruby ./echonest.rb \"#{name}\""

    puts command

    system(command)

    puts "Done with #{name}"
  end
end
