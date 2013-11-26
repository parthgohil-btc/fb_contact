class HomeController < ApplicationController
  def index
  	if current_user.present?
      @reviews = Review.all
      fetch_friends_details(current_user.uid)
      logger.debug "current_user.uid------------------#{current_user.uid}=========="
    else
      logger.debug "--------------------not login----------------------"
    end  
  end	
  
  private
  def fetch_friends_details(uid)
    @graph = Koala::Facebook::API.new(oauth_access_token)
    @profile = @graph.get_object("me")
    @profile_pic = @graph.get_picture("me")
    #@friends = @graph.get_connections("me", "friends")

    all_friends_profile = @graph.get_connections(uid, "friends",
      fields: "name,birthday,gender,location,picture.type(small)"
    )
    @friends_profile = []
    all_friends_profile.each do |friends|
      review = Review.find_by_facebook_id(friends["id"])
      @friends_profile << friends unless review.nil?
    end
    facebook_id(@profile)
    # logger.debug "-----@friends_profile-----------#{@friends_profile}"
    # logger.debug "---friends...#{@friends_profile}-----"
    # logger.debug "---oauth_access_token ...#{oauth_access_token}------"
    # logger.debug "---profile...#{@profile}-----"
  end

  def facebook_id(profile)
    session[:facebook_id] = profile["id"]
  end

  def oauth_access_token
    session[:devise_fb_token]
  end	

  # def oauth_access_token_new
  #   @oauth = Koala::Facebook::OAuth.new(ENV['FACEBOOK_APP_ID'],
  #     ENV['FACEBOOK_SECRET'])
  #   @oauth.get_app_access_token
  # end

end