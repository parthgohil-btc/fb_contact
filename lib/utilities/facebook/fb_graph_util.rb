require 'koala'

module Utilities
  module Facebook
    class FbGraphUtil < Utilities::CommonUtil

      DATA_SINCE_YEARS = 1
      DATA_SINCE_MONTHS = 6
      PHOTOS_PER_PAGE = 5000
      LINKS_PER_PAGE = 5000
      STATUSES_PER_PAGE = 1000
      POSTS_PER_PAGE = 500

      FB_AUTH_ERROR_CLASS = 'Koala::Facebook::AuthenticationError'

      include Koala

      def initialize(token, config={})

        init_fb_graph(token)
        initialize_objects_for_friends_stats

        @photos_per_page = config[:photos] || PHOTOS_PER_PAGE
        @links_per_page = config[:links] || LINKS_PER_PAGE
        @statuses_per_page = config[:statuses] || STATUSES_PER_PAGE
        @posts_per_page = config[:posts] || POSTS_PER_PAGE

      end

      def fetch_photos_activity_details(uid,until_date=get_unix_time_for_today,last_date=get_unix_time_before_months(DATA_SINCE_MONTHS))
        total_photos = 0
        next_until = "0"
        begin
          info " Fetching photos information....until #{until_date}"
          user_photos = graph.get_connections(uid, "photos",{
              fields:"id", type:'uploaded',
              limit: @photos_per_page,  until: until_date, since: last_date
          })
          #total_photos = calculate_activity_count(user_photos)
          total_photos = user_photos.size if user_photos.present?
          next_until = get_next_page_until_val user_photos.next_page_params
        rescue Exception => e
          error "fetch_photos_activity_details : #{e.message}"
          return {is_auth_error: true} if e.class.to_s == FB_AUTH_ERROR_CLASS
        end

        { total_photos: total_photos, next_until_photos: next_until}
      end

      def fetch_links_activity_details(uid,until_date=get_unix_time_for_today,last_date=get_unix_time_before_months(DATA_SINCE_MONTHS))
        total_links = 0
        next_until = "0"
        begin
          info " Fetching Links information...."
          user_links = graph.get_connections(uid, "links",{
              fields:"id",
              limit: @links_per_page, until: until_date, since: last_date
          })
          #total_links = calculate_activity_count(user_links)
          total_links = user_links.size if user_links.present?
          next_until = get_next_page_until_val user_links.next_page_params
        rescue Exception => e
          error "fetch_photos_activity_details : #{e.message}"
          return {is_auth_error: true} if e.class.to_s == FB_AUTH_ERROR_CLASS
        end

        {total_links: total_links, next_until_links:next_until}
      end

      def fetch_statuses_activity_details(uid,until_date=get_unix_time_for_today,last_date=get_unix_time_before_months(DATA_SINCE_MONTHS))
        debug "ENTER :: ==> fetch_status_activity_details(uid,until_date)"
        total_statuses = 0
        next_until = "0"

        begin
          info "Fetching status information...."
          user_statuses = graph.get_connections(uid, "statuses",{
              fields:"id, message", limit: @statuses_per_page,  until: until_date, since: last_date
          })
          if user_statuses.present?
            total_statuses = user_statuses.size
            #next_until = get_next_page_until_val user_statuses.next_page_params
          end
          debug "EXIT :: ==> fetch_status_activity_details(uid,until_date)"
        rescue Exception => e
          error "fetch_status_activity_details : #{e.message}"
          return {is_auth_error: true} if e.class.to_s == FB_AUTH_ERROR_CLASS
        end

        { total_statuses: total_statuses}
      end

      #
      # Returns status/post, photos and links count map with following values,
      #   :total_characters,  :total_likes, :total_comments, :avg_char_length, :total_photos, :total_links
      #
      # @param since
      # @param until
      # @param uid
      #
      def fetch_posts_activity_details(uid,until_date=get_unix_time_for_today,last_date=get_unix_time_before_months(DATA_SINCE_MONTHS))
        debug "ENTER :: ==> fetch_posts_activity_details(uid,until_date)"
        total_msg = 0
        total_likes = 0
        total_comments = 0
        total_posts = 0
        next_until = "0"
        msg_arr = []

        begin

          info "Fetching posts information...."

          posts_fql = "SELECT post_id, message,comments.count, likes.count, created_time FROM stream WHERE actor_id = #{uid} AND
                    source_id = #{uid} AND type != 56 AND created_time >= #{last_date} AND created_time <= #{until_date} LIMIT #{@posts_per_page}"

          user_posts = graph.fql_query(posts_fql)

          if user_posts.present?
            total_posts = user_posts.size
            user_posts.each do |status|
              msg_arr<< status['message'] if status['message'].present?
              total_likes += status['likes']['count'] if status['likes'].present? && status['likes']['count'].present?
              total_comments += status['comments']['count'] if status['comments'].present? && status['comments']['count'].present?
            end
            next_until_param = user_posts.last['created_time']
            next_until = (next_until_param.present? && next_until_param.to_s != until_date.to_s) ? next_until_param : '0'
          end
          total_msg = msg_arr.size
          debug "EXIT :: ==> fetch_posts_activity_details(uid,until_date)"
        rescue Exception => e
          error "fetch_posts_activity_details : #{e.message}"
          return {is_auth_error: true} if e.class.to_s == FB_AUTH_ERROR_CLASS
        end

        {
            next_until_posts: next_until,
            total_posts: total_posts,
            total_msg: total_msg,
            total_likes: total_likes ,
            total_comments: total_comments,
            msg_arr: msg_arr
        }
      end

      #
      # Returns <code>Hash</code> with following keys ,
      #
      #   :gender_map (Count of male/female friends),
      #   :age_map (Age range count of friends),
      #   :location_map (Location based count, for each location),
      #   :relationship_status_map (Relationship status based count)
      #

      def generate_friends_stats_map(user_id)
        debug "ENTER :: ==> generate_friends_stats_map(user_id)"
        @stats_map = {}
        begin
          @friends_profile = graph.get_connections(user_id, "friends", "fields" => "birthday,gender,relationship_status,location,age")
          @friends_profile.each do |friend|
            generate_friends_gender_map(friend)
            generate_friends_relationship_map(friend)
            generate_friends_age_map(friend)
          end
          friends_locations_map = friends_locations_map(user_id)
          debug "EXIT :: ==> generate_friends_stats_map(user_id)"
          @stats_map = {
              gender_map: gender_map,
              relationship_status_map: friends_relationship_map,
              age_map: age_map
          }.merge(friends_locations_map)
          @stats_map[:demographics] = {
            gender: get_percentage_map(gender_map,[:undefined]),
            relationship: get_percentage_map(friends_relationship_map,[:undefined]),
            age_group: get_percentage_map(age_map,[:undefined])
          }
          @stats_map
          #debug " =====================> #{@stats_map.inspect}"
        rescue Exception => e
          error("generate_friends_stats_map :: #{e.message}")
          return {is_auth_error: true} if e.class.to_s == FB_AUTH_ERROR_CLASS
        end
        @stats_map
      end

      def generate_fan_page_stats_map(page_id)
        debug "ENTER :: ==> generate_fan_page_stats_map(#{page_id})"
        @fan_page_stats_map = {}
        begin
          page_details =  graph.get_objects("#{page_id}")
          Rails.logger.info("***************Fan page details....********************** ")
          Rails.logger.info(page_details)
          
          page = {}
          page[:id] = page_details[page_id]['id']
          page[:fans_count] = page_details[page_id]['likes'].present? ? page_details[page_id]['likes'] : 0
          page[:name] = page_details[page_id]['name']
          page[:talking_about_count] = page_details[page_id]['talking_about_count'].present? ? page_details[page_id]['talking_about_count'] : 0
          page[:about] = page_details[page_id]['about'].present? ? page_details[page_id]['about'] : "Information not available"
          page[:description] = page_details[page_id]['description'].present? ? page_details[page_id]['description'] : "Information not available"
          page[:founded] = page_details[page_id]['founded'].present? ? page_details[page_id]['founded'] : "Information not available"
          page[:link] =  page_details[page_id]['link'].present? ? page_details[page_id]['link'] : ""
          
          generate_fans_age_and_gender_map(page_id)
          
          @fan_page_stats_map = {
              gender_map: gender_map,
              age_map: age_map,
              page: page,
          }.merge(generate_fans_location_map(page_id))

          debug "EXIT :: ==> generate_fan_page_stats_map(#{page_id})"

        rescue Exception => e
          error("generate_fan_page_stats_map :: #{e.message}")
          return {is_auth_error: true} if e.class.to_s == FB_AUTH_ERROR_CLASS
        end
        @fan_page_stats_map
      end


      ###################################################################################################

      private

      ###################################################################################################

      # private methods for fan page data.start#

      def generate_fans_location_map(page_id)
        country_map = {}
        city_map = {}

        begin
          page_fans_city = graph.get_connections(page_id,"/insights/page_fans_city")
          page_fans_country = graph.get_connections(page_id,"/insights/page_fans_country")

          if page_fans_country.present?
            if page_fans_country[0]['values'].present? && page_fans_country[0]['values'].last["value"].present?
              country_map = page_fans_country[0]['values'].last["value"]
            end
          end

          if page_fans_city.present?
            if page_fans_city[0]['values'].present? && page_fans_city[0]['values'].last["value"].present?
              city_map = page_fans_city[0]['values'].last["value"]
            end
          end
        rescue Exception => e
          error("generate_fans_location_map :: #{e.message}")
        end

        fans_location_map = {country_map: country_map, city_map: city_map }

      end

      def generate_fans_age_and_gender_map(page_id)
        @age_map = {}

        @male_count = 0
        @female_count = 0
        @undefined_gender_count = 0
        begin
          page_fans_gender_age = graph.get_connections(page_id,"/insights/page_fans_gender_age")
          if page_fans_gender_age.present? && page_fans_gender_age[0]['values'].present? && page_fans_gender_age[0]['values'].last["value"].present?
            page_fans_gender_age[0]['values'].last["value"].each do |age, v|
              @age_map[:"#{age[2..-1]}"] = v
            end
          end

          if page_fans_gender_age.present? && page_fans_gender_age[0]['values'].last["value"].present?
            page_fans_gender_age[0]['values'].last["value"].each do |k, v|
              gender_age_group_arr = k.split('.')
              case gender_age_group_arr[0]
                when 'M'
                  @male_count = @male_count + v.to_i
                when 'F'
                  @female_count = @female_count + v.to_i
                else
                  @undefined_gender_count = @undefined_gender_count + v.to_i
              end
            end
          end
        rescue Exception => e
          error("generate_fans_age_and_gender_map :: #{e.message}")
        end

      end

      # Fan page data methods.end# 

      # For activity stats.start ######################################
      def get_status_action_count(user_statuses, action)
        user_statuses.select { |status|
          status[action].present? && status[action]['count'].present?
        }.collect {|status| status[action]['count']
        }.inject(0){|sum, count| sum+count}
      end

      def calculate_activity_count(fb_activity_results)
        page = 0
        total_count = 0
        while fb_activity_results.present?
          page +=1
          info "Fetching data for page: #{page} ..."
          total_count+= fb_activity_results.size
          fb_activity_results = fb_activity_results.next_page
        end
        total_count
      end

      #For activity stats.end######################################

      #For friends stats.start ######################################


      def friends_locations_map(uid)
        fql_curr_location = "SELECT current_location.state,current_location.country, current_location.city FROM user WHERE uid in (SELECT uid2 FROM friend where uid1 = #{uid} )"
        friends_location_map = graph.fql_query(fql_curr_location)
        country_map = {}
        states_map = {}
        city_map = {}
        top_locations_map = {}
        if friends_location_map.present?
          friends_location_map.each do |location|
            curr_location = location['current_location']
            if curr_location.present? && curr_location['state'].present? && curr_location['country'].present? && curr_location['city'].present?
              state = curr_location['state'].to_sym
              country= curr_location['country'].to_sym
              city= curr_location['city'].to_sym

              country_map[country] ||=0
              country_map[country] += 1

              states_map[state] ||=0
              states_map[state] += 1

              city_map[city] ||=0
              city_map[city] += 1

            end
          end
          top_locations_map[:country_map] = Hash[country_map.sort_by { |k, v| v }.reverse[0..2]]
          top_locations_map[:state_map] = Hash[states_map.sort_by { |k, v| v }.reverse[0..2]]
          top_locations_map[:city_map] = Hash[city_map.sort_by { |k, v| v }.reverse[0..2]]
        end
        {country_map: country_map, state_map: states_map, city_map: city_map, top_locations_map: top_locations_map }
      end

      def gender_map
        { male: @male_count, female: @female_count, undefined: @undefined_gender_count }
      end

      def friends_relationship_map
        {
            married: @married_count,
            single: @single_count,
            engaged: @engaged_count,
            dating: @in_relationship_count,
            #complicated: @its_complicated_count,
            undefined: @other_count
            #open: @open_relationship_count,
        }
      end

      def friends_location_map
        @location_map = {}
        @friends_location.values.each do |val_map|
          @location_map[val_map['location_name']] = val_map['count']
        end
        @location_map
      end

      def age_map
        @age_map
      end

      def generate_friends_age_map(friend)
        if friend["birthday"].present?
          age = age_in_years(friend["birthday"])
          if(age>0 && age<18)
            @age_map[:'1-17'] += 1
          elsif(age>17 && age<25)
            @age_map[:'18-24'] += 1
          elsif(age>24 && age<35)
            @age_map[:'25-34'] += 1
          elsif(age>34 && age<45)
            @age_map[:'35-44'] += 1
          elsif(age>44 && age<55)
            @age_map[:'45-54'] += 1
          elsif(age>54 && age<65)
            @age_map[:'55-64'] += 1
          elsif(age>=65)
            @age_map[:'65+'] += 1
          else
            @age_map[:undefined] += 1
          end
        end
      end

      def generate_friends_relationship_map(friend)
        unless friend["relationship_status"].nil?
          case friend["relationship_status"]
            when "Married"
              @married_count += 1
            when "Single"
              @single_count += 1
            #when "It's complicated"
            #  @its_complicated_count += 1
            when "In a relationship"
              @in_relationship_count += 1
            #when "In an open relationship"
            #  @open_relationship_count += 1
            when "Engaged"
              @engaged_count += 1
          end
        else
          @other_count += 1
        end
      end

      def initialize_objects_for_friends_stats
        #For Gender
        @male_count = 0
        @female_count = 0
        @undefined_gender_count = 0

        #For relationships
        @married_count = 0
        @single_count = 0
        @its_complicated_count = 0
        @other_count = 0
        @open_relationship_count = 0
        @engaged_count = 0
        @in_relationship_count = 0

        @friends_location = {}
        @age_map = {}
        @age_map = {:'undefined' => 0, :'1-17' =>  0, :'18-24' =>  0, :'25-34' =>  0,:'35-44' =>  0,
                            :'45-54' =>  0,:'55-64' =>  0,:'65+' =>  0 }
      end

      def generate_friends_gender_map(friend)
        unless friend["gender"].nil?
          if friend["gender"] == "male"
            @male_count += 1
          elsif friend["gender"] == "female"
            @female_count += 1
          end
        else
          @undefined_gender_count += 1
        end
      end

      # For friends stats.end ######################################

      #
      # Returns user details for given user_id, based on given fields
      # @param uid
      # @param fields
      #
      def get_user_profile(uid,fields)
        begin
          @user_details = graph.get_object("#{uid}","fields" => "#{fields}")
        rescue Exception => e
          error("get_user_profile :: #{e.message}")
        end
      end

      def graph
        @graph
      end

      def init_fb_graph(token)
        begin
          @graph = Koala::Facebook::API.new(token)
        rescue Exception => e
          error("init_fb_graph :: #{e.message} ")
        end
      end

      def age_in_years(birth_date_str)
        return 0 if (!birth_date_str.present? || birth_date_str.split('/').size<3)
        birth_date = Date.strptime birth_date_str, '%m/%d/%Y'
        return 0 if birth_date > Date.today
        Date.today.year - birth_date.year
      end

      def get_next_page_until_val(next_page_params)
        (!next_page_params.nil? && next_page_params.size == 2) ? next_page_params[1]['until'] : '0'
      end
    end
  end
end