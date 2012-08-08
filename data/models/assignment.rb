class Assignment < ActiveRecord::Base
  belongs_to :playlist
  belongs_to :track

  set_table_name "tracks_playlists"
end
