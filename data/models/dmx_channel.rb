class DmxChannel < ActiveRecord::Base
  has_many :dmx_ranges
end
