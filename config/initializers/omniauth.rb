# Rails.application.config.middleware.use OmniAuth::Builder do
#   # The following is for facebook
#   provider :facebook, [APP ID], [SECRET KEY], {:scope =&gt; 'email, read_stream, read_friendlists, friends_likes, friends_status, offline_access'}
 
# end

# OmniAuth.config.logger = Rails.logger

# Rails.application.config.middleware.use OmniAuth::Builder do
#   provider :facebook, ENV['FACEBOOK_APP_ID'], ENV['FACEBOOK_SECRET'],
#     :scope => 'email,user_birthday,read_stream', :display => 'popup'
# end