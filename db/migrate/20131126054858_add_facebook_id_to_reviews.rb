class AddFacebookIdToReviews < ActiveRecord::Migration
  def change
  	add_column :reviews, :facebook_id, :string
  end
end
