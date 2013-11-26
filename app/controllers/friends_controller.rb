class FriendsController < ApplicationController
  def index
  	@reviews = Review.find_all_by_facebook_id(params[:id])
  end
end
