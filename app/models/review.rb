class Review < ActiveRecord::Base
  attr_accessible :comment, :place_id, :rating, :facebook_id
  validates :comment, :place_id, :rating, presence: true
  belongs_to :place
end
