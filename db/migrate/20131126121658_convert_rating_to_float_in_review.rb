class ConvertRatingToFloatInReview < ActiveRecord::Migration
  def up
  	change_column :reviews, :rating, :float
  end

  def down
  end
end
