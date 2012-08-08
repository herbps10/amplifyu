class Playlist < ActiveRecord::Base
  has_many :assignments
  has_many :tracks, :through => :assignments
end
