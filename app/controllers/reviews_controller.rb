class ReviewsController < ApplicationController
	
	before_filter :authenticate_user!
  before_filter :initialize_review

  def new 
  end

  def create
    params[:review][:rating] = params[:score]
    params[:review][:facebook_id] = session[:facebook_id]
    review = Review.new(params[:review])

    if review.save
      redirect_to root_path
      flash[:notice] = "Review posted"
    else
      flash.now[:alert] = "please check the details"
      render :new
    end
  end

  private
  def initialize_review
    @review = Review.new
  end
end