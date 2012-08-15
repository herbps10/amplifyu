#
# File: server.rb
#
# Author: Herb Susmann
# Date: August 2012
#
# Purpose: Web server that exposes interface for controlling the system
#
# It runs an HTTP server as well as a WebSockets server. Commands can be
# recieved through WebSockets. Furthermore, information about the current
# state of the system is pushed back through WebSockets.
#



require 'rubygems'
require 'thin'
require 'sinatra'
require 'haml'
require 'redis'
require 'mysql'
require 'active_record'
require 'yaml'
require 'thin'
require 'em-websocket'

$ip = "192.168.1.2"

class Clients
  def initialize
    @sockets = []
  end

  def add_socket ws
    @sockets.push ws
  end

  def remove_socket ws
    @sockets.delete ws
  end

  def broadcast(message)
    @sockets.each do |ws|
      ws.send message
    end
  end
end

$clients = Clients.new


######### 
# MYSQL #
#########

db_config = YAML::load(File.new("../data/database.yml").read)

ActiveRecord::Base.establish_connection(
  adapter:  db_config['adapter'],
  user:     db_config['user'],
  password: db_config['password'],
  host:     db_config['host'],
  database: db_config['database'],
  pool:     db_config['pool'].to_i
)

require '../data/models/track.rb'
require '../data/models/assignment.rb'
require '../data/models/playlist.rb'
require '../data/models/section.rb'
require '../data/models/segment.rb'
require '../data/models/user.rb'
require '../data/models/light.rb'
require '../data/models/dmx_channel.rb'
require '../data/models/dmx_range.rb'
require '../data/models/user_light.rb'

#########
# REDIS #
#########

$redis = Redis.new
$redis.select 1

Thread.new do
  db = Redis.new({:timeout => 0})
  db.select 1

  db.subscribe("position") do |on|
    on.message do |channel, msg|
      $clients.broadcast( { :action => "position", :value => msg }.to_json )
    end
  end

end

def redis_command(id)
  return "command:" + id.to_s
end

def redis_get_current_command_id
  $redis.incr 'id'
  return $redis.get 'id'
end

def send_command(action, value = nil)
  puts action + " " + value.to_s

  id = redis_get_current_command_id
  command = redis_command(id) 
  $redis.hset(redis_command(id), "type", "player")
  $redis.hset(redis_command(id), "action", action)

  if(value != nil)
    $redis.hset(redis_command(id), "value", value)
  end

  $redis.lpush("player", redis_command(id))
end


EventMachine.run do
  
  class App < Sinatra::Base
    ##############
    # HTML VIEWS #
    ##############

    get "/app" do
      erb :app, :layout => false
    end

    get '/' do
      @index = true
      @playlist = false

      ActiveRecord::Base.connection_pool.with_connection do
        @tracks = Track.order("artist ASC").all
      end

      ActiveRecord::Base.connection_pool.with_connection do
        @playlists = Playlist.all
      end

      @minimal = false
      haml :index
    end

    post '/upload' do
      unless params[:file] && (tmpfile = params[:file][:tempfile]) && (name = params[:file][:filename])
        return haml(:upload)
      end

      while blk = tmpfile.read(65536)
          File.open("/home/herb/git/amplifyu/system/music-library/#{name}", "wb") { |f| f.write(tmpfile.read) }
      end
      
      $redis.publish('uploads', name)

     'success'
    end

    get '/intensity_graph' do
      track_id = params[:track].to_i

      ActiveRecord::Base.connection_pool.with_connection do
        @segments = Segment.where("track_id = #{track_id}").order('id ASC').all
      end

      erb :graph
    end

    get '/add_track_to_playlist' do
      @index = false
      @playlist = true

      track     = params[:track].to_i
      playlist  = params[:playlist].to_i

      tracks_in_playlist = nil
      ActiveRecord::Base.connection_pool.with_connection do
        # See if there are any already there
        tracks_in_playlist = Assignment.where("playlist_id = #{playlist}").order("`order` DESC").limit(1)
      end

      order = 0
      if tracks_in_playlist.length > 0
        order = tracks_in_playlist.first.order + 1
      end

      ActiveRecord::Base.connection_pool.with_connection do
        query = ActiveRecord::Base.connection.raw_connection.prepare("INSERT INTO tracks_playlists (track_id, playlist_id, `order`) VALUES(?, ?, ?)")
        query.execute(track, playlist, order)
        query.close
      end

      haml :track
    end

    get '/track' do
      @index = false
      @playlist = true

      haml :track
    end

    get '/playlists' do
      ActiveRecord::Base.connection_pool.with_connection do
        @playlists = Playlist.all
        haml :playlists
      end
    end

    get "/player" do 
      ActiveRecord::Base.connection_pool.with_connection do
        @tracks = Track.all
        haml :player, :layout => false
      end
    end

    get "/hotkey/turnoffeverything" do
      $redis.publish("player", "turnoffeverything")     
    end

    get "/hotkey/blue" do
      $redis.publish("player", "blue")     
    end

    get "/hotkey/green" do
      $redis.publish("player", "green")     
    end

    get "/hotkey/red" do
      $redis.publish("player", "red")     
    end

    get '/add_light_to_user' do
      brand = params["brand"].gsub("_", " ")
      name = params["name"].gsub("_", " ")
      user = params["user"].to_i

      top_light = UserLight.where("user_id = #{user}").order("start_dmx_channel DESC").limit(1).first
      top_light_channels = DmxChannel.where("light_id = #{top_light.id}").all.length
      
      light = Light.where("brand = '#{brand}' AND name = '#{name}'").first

      user_light = UserLight.new
      user_light.light_id = light.id
      user_light.user_id = user
      user_light.start_dmx_channel = top_light.start_dmx_channel + top_light_channels + 1

      user_light.save

      #return [{ :channel => user_light.start_dmx_channel }].to_json
      return (top_light.start_dmx_channel + top_light_channels + 1).to_s
    end

    get "/play_from_playlist" do
      track_id     = params[:track].to_i
      playlist_id  = params[:playlist].to_i

      track = nil
      ActiveRecord::Base.connection_pool.with_connection do
        track     = Track.find(track_id)
      end

      playlist = nil
      ActiveRecord::Base.connection_pool.with_connection do
        playlist  = Playlist.find(playlist_id)
      end

      data = {
        :action     => "load",
        :id         => track.id,
        :name       => track.name,
        :artist     => track.artist,
        :duration   => track.duration,
      }

      playlist_id = $redis.get("current:playlist:id")

      if playlist_id
        assignment = nil
        ActiveRecord::Base.connection_pool.with_connection do
          assignment = Assignment.where("track_id = #{track.id} AND playlist_id = #{playlist_id}").first
        end
        
        if assignment != nil
          data['fade_in_time'] = -1
          data['fade_in_time'] = assignment.fade_in if assignment.fade_in != nil

          data['fade_out_time'] = -1
          data['fade_out_time'] = assignment.fade_out if assignment.fade_out != nil
        end
      end

      $clients.broadcast(data.to_json)
      
      send_command "load", track.id

      $redis.set("current:playlist:id", playlist.id)
    end

    get "/play_track" do
      @index = true
      @playlist = false

      track_name  = params[:track]

      track = nil
      ActiveRecord::Base.connection_pool.with_connection do
        track = Track.where("name = '#{track_name}'").first
      end

      $clients.broadcast({ :action => "load",
            :id         => track.id,
            :name       => track.name,
            :artist     => track.artist,
            :duration   => track.duration,
      }.to_json)
      
      send_command "load", track.id

      ActiveRecord::Base.connection_pool.with_connection do
        @tracks = Track.order("artist ASC").all
      end
      
      ActiveRecord::Base.connection_pool.with_connection do
        @playlists = Playlist.all

      end

      @minimal = true
      haml :index

    end

    ########################
    # AJAX PLAYER COMMANDS #
    ########################

    get '/play' do
      send_command("play")

      return 'play'
    end

    get '/pause' do
      send_command("pause")

      return 'pause'
    end

    get '/seek/:value' do
      value = params[:value]
      send_command("seek", value)

      return 'seek'
    end

    get '/load/:id' do
      id = params[:id]
      send_command("load", id)

      return 'loadandplay'
    end

    #################
    # JSON REQUESTS #
    #################
    
    get '/track_playlist_info.json' do
      track_id = params[:track]
      playlist_id = params[:playlist]

      track = nil
      ActiveRecord::Base.connection_pool.with_connection do
        track = Track.find(track_id)
      end

      track_playlist = nil
      ActiveRecord::Base.connection_pool.with_connection do
        track_playlist = Assignment.where("playlist_id = #{playlist_id} AND track_id = #{track_id}").first
      end

      info = { 
        :track => {
          :id             => track.id,
          :name           => track.name,
          :duration       => track.duration,
          :artist         => track.artist,
          :fade_in_time   => track_playlist.fade_in,
          :fade_out_time  => track_playlist.fade_out,
          :fade_type      => track_playlist.fade_type
        }
      }

      return info.to_json
    end

    get '/user_lights.json' do
      user_id = params[:user]

      user_lights = nil
      ActiveRecord::Base.connection_pool.with_connection do
        user_lights = UserLight.where("user_id = #{user_id}").all
      end

      lights = user_lights.map { |l| { id: l.light.id, name: l.light.name, brand: l.light.brand } }
      
      return lights.to_json
    end

    get '/brand_lights.json' do
      return { :brands => ['Chauvet', 'Test'] }.to_json
    end

    get '/lights.json' do
      brand = params[:brand]

      return { :lights => [ '6 SPOT' ] }.to_json
    end

    get '/playlists.json' do 
      ActiveRecord::Base.connection_pool.with_connection do
        playlists = Playlist.all

        alphabetized = {}
        playlists.each do |playlist|
          next if playlist.name == nil

          first_letter = playlist.name[0]

          alphabetized[first_letter] = [] if alphabetized[first_letter] == nil
          alphabetized[first_letter].push playlist.name
        end

        return alphabetized.to_json
      end
    end

    get '/playlist/add/:name' do
      name = params[:name]

      ActiveRecord::Base.connection_pool.with_connection do
        playlist = Playlist.new
        playlist.name = name

        playlist.save

        return ({ :status => "success", :id => playlist.id }.to_json)
      end
    end

    get "/status.json" do
      @status = $redis.get("player:status")

      erb :status
    end

    get '/track.json' do
      id = $redis.get("player:current:id")

      if id
        ActiveRecord::Base.connection_pool.with_connection do
          @track = Track.find(id)
        end

        content_type :json
        erb :track
      else
        erb :player_stopped
      end
    end

    get '/tracks.json' do
      ActiveRecord::Base.connection_pool.with_connection do
        @tracks = Track.all

        content_type :json
        erb :tracks
      end
    end

    get '/artists.json' do
      ActiveRecord::Base.connection_pool.with_connection do
        tracks = Track.order('artist ASC').group('artist')

        artists = {}
        tracks.each do |track|
          first_letter = track.artist[0]

          next if first_letter == '' or first_letter == nil

          artists[first_letter] = [] if artists[first_letter] == nil

          artists[first_letter].push track.artist
        end

        content_type :json

        puts artists.inspect
        
        return artists.to_json
      end
    end

    get '/artist_tracks.json' do
      artist = params['artist']
      ActiveRecord::Base.connection_pool.with_connection do
        alphabetized = {}

        tracks = Track.where("artist = '#{artist}'").order('name ASC').all

        tracks.each do |track|
          first_letter = track.name[0].downcase

          alphabetized[first_letter] = [] if alphabetized[first_letter] == nil

          if false
          alphabetized[first_letter].push({ 
            :name => track.name, 
            :id => track.id, 
            :duration => track.duration, 
            :artist => track.artist, 
            :album => track.album
          })
          end

          alphabetized[first_letter].push track.name
        end

        content_type :json
        return alphabetized.to_json
      end 
    end

    get '/album_tracks.json' do
      album = params['album']
      ActiveRecord::Base.connection_pool.with_connection do
        alphabetized = {}

        tracks = Track.where("album = '#{album}'").order('name ASC').all

        tracks.each do |track|
          first_letter = track.name[0].downcase

          alphabetized[first_letter] = [] if alphabetized[first_letter] == nil
          alphabetized[first_letter].push track.name
        end

        content_type :json
        return alphabetized.to_json
      end 
    end

    get '/playlist_tracks.json' do
      playlist = params['playlist']

      puts "Playlist #{playlist}"

      ActiveRecord::Base.connection_pool.with_connection do
        alphabetized = {}

        playlist = Playlist.where("name = '#{playlist}'").first

        assignments = Assignment.where("playlist_id = '#{playlist.id}'").all

        tracks = []
        assignments.each do |assignment|
          tracks.push assignment.track.name
        end

        content_type :json
        return tracks.to_json
      end
    end

    get '/albums.json' do
      ActiveRecord::Base.connection_pool.with_connection do
        @tracks = Track.group('album').order('album DESC').all

        alphabetized = {}

        @tracks.each do |track|
          next if track.album == nil
          next if track.album[0] == nil

          first_letter = track.album[0].downcase
          
          next if first_letter == nil or first_letter == '' or first_letter.chomp == ''

          alphabetized[first_letter] = [] if alphabetized[first_letter] == nil

          alphabetized[first_letter].push track.album

        end

        content_type :json
        return alphabetized.to_json
      end
    end

    get '/songs.json' do
      ActiveRecord::Base.connection_pool.with_connection do
        @tracks = Track.order('name ASC').all

        alphabetized = {}

        @tracks.each do |track|
          nexst if track.name == nil
          first_letter = track.name[0]

          next if first_letter.nil? or first_letter == '' or first_letter.chomp == ''

          alphabetized[first_letter] = [] if alphabetized[first_letter] == nil

          alphabetized[first_letter].push track.name

        end
        
        content_type :json
        return alphabetized.to_json
      end
    end
    

    get '/sections.json' do
      track_id = params[:track_id]
      ActiveRecord::Base.connection_pool.with_connection do
        @sections = Section.order('id ASC').where("track_id = #{track_id}").where('confidence > 0.0').all

        content_type :json
        return @sections.to_json
      end
    end
  end

  EventMachine::WebSocket.start(:host => $ip, :port => 5000) do |ws|
    ws.onopen do
      $clients.add_socket ws

      if $redis.get("player:status") == "playing"
        ActiveRecord::Base.connection_pool.with_connection do
          id = $redis.get("player:current:id")
          position = $redis.get("player:current:position").to_f

          track = Track.find(id)

          percent = (position * 100) / track.duration.to_f;

          data = { :action => "startup",
            :status     => "playing",
            :id         => id,
            :position   => position,
            :name       => track.name,
            :artist     => track.artist,
            :duration   => track.duration,
            :volume     => $redis.get("player:volume")
          }

          playlist_id = $redis.get('current:playlist:id')

          if playlist_id
            assignment = Assignment.where("playlist_id = #{playlist_id} AND track_id = #{track.id}").first

            if assignment != nil
              data['fade_in_time'] = assignment.fade_in
              data['fade_out_time'] = assignment.fade_out
              data['fade_type'] = assignment.fade_type
            end
          end

          ws.send(data.to_json);
        end

      else
        ws.send ({ :status => "stopped" }.to_json)
      end
    end
    
    ws.onmessage do |msg|
      begin
        data = JSON.parse(msg)
      rescue
        puts "Invalid JSON"
        next
      end

      puts "Recieved websocket command: #{msg}"

      ########
      # PLAY #
      ########

      if data["action"] == "play"
        send_command "play" 
        $clients.broadcast('{ "action": "play" }')


      #########
      # PAUSE #
      #########

      elsif data["action"] == "pause"
        send_command "pause"
        $clients.broadcast('{ "action": "pause" }')

      ########
      # SEEK #
      ########

      elsif data["action"] == "seek"
        send_command "seek", data['value']
      

      ########
      # LOAD #
      ########

      elsif data["action"] == "load"
        ActiveRecord::Base.connection_pool.with_connection do
          track = Track.find(data['value'])

          websocket_data = { 
            :action     => "load",
            :id         => track.id,
            :name       => track.name,
            :artist     => track.artist,
            :duration   => track.duration,
          }

          playlist_id = $redis.get("current:playlist:id")

          if playlist_id
            assignment = Assignment.where("track_id = #{track.id} AND playlist_id = #{playlist_id}").first

            if assignment != nil
              websocket_data['fade_in_time'] = -1
              websocket_data['fade_in_time'] = assignment.fade_in if assignment.fade_in != nil

              websocket_data['fade_out_time'] = -1
              websocket_data['fade_out_time'] = assignment.fade_out if assignment.fade_out != nil
            end
          end

          $clients.broadcast(websocket_data.to_json)

          puts "Recieved load command"

          send_command "load", data['value']
        end

      ##########
      # VOLUME #
      ##########

      elsif data["action"] == "volume"
        send_command "volume", data['value']
        $clients.broadcast('{ "action": "volume", "value": ' + data['value'].to_s + '}')
      
      
      ############
      # POSITION #
      ############

      elsif data["action"] == "position"
        position = $redis.get("player:position").to_f
        duration = $redis.get("player:current:duration").to_f
        percent = (position * 100) / duration

        ws.send({ :action => "position", :value => position, :percent => percent}.to_json)

      #############
      # FADE TYPE #
      #############

      elsif data["action"] == 'fade_type'
        puts "Fade type"
        ActiveRecord::Base.connection_pool.with_connection do
          playlist_id = $redis.get("current:playlist:id").to_i
          track_id = $redis.get("player:current:id").to_i

          playlist_id = data['playlist'].to_i if data['playlist']
          track_id = data['track'].to_i if data['track']

          if playlist_id
            track_data = Assignment.where("track_id = #{track_id} AND playlist_id = #{playlist_id}").first

            if track_data
              track_data.fade_type = data["value"].to_i
              track_data.save
            end
          end
        end

      ##################
      # FADE IN TIMES  #
      ##################

      elsif data["action"] == "fade_in_time" or data["action"] == "fade_out_time"
        ActiveRecord::Base.connection_pool.with_connection do
          # Check to see if we're in a playlist 
          playlist_id = $redis.get("current:playlist:id").to_i
          track_id = $redis.get("player:current:id").to_i

          playlist_id = data["playlist"].to_i if data["playlist"]
          track_id = data["track"].to_i if data["track"]

          if playlist_id
            track_data = Assignment.where("track_id = #{track_id} AND playlist_id = #{playlist_id}").first

            if track_data
              if data["action"] == "fade_in_time"
                track_data.fade_in = data["value"].to_f
              elsif data["action"] == "fade_out_time"
                track_data.fade_out = data["value"].to_f
              end

              track_data.save
            else 
              $redis.del("current:playlist:id")
            end

          else
            track_data.fade_in = -1
            track_data.fade_out = -1
          end
        end
      end
    end

    ws.onclose do
      $clients.remove_socket ws
    end
  end
  
  App.run!({ :port => 4000 })
end
