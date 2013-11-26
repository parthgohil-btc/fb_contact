class Place < ActiveRecord::Base
  attr_accessible :name
  validates :name, presence: true, uniqueness: true
  has_one :review
end
