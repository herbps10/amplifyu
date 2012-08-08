class Track < ActiveRecord::Base
  has_many :assignments
  has_many :playlists, :through => :assignments
  has_many :sections
end
