class Light < ActiveRecord::Base
  has_many :dmx_channels
end
