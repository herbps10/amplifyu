class User < ActiveRecord::Base
  has_many :lights, :through => :user_lights
end
