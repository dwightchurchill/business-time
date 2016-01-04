require 'sinatra'
require 'httparty'
require 'json'

post '/business-time/' do

  token = params.fetch("token").strip
  command = params.fetch("command").strip

  if token == '<SLACK_TOKEN>' 

    if command == '/business-time'
  
    begin
      response = HTTParty.get('http://businesstime.localytics.com/api')
      if response.code == 200
        
        men_left_stall_status = response[0]["value"]
        men_right_stall_status = response[1]["value"]
        women_left_stall_status = response[2]["value"]
        women_right_stall_status = response[3]["value"]

        if men_left_stall_status == 'open' && men_right_stall_status == 'open'
          <<-TEXT
          💚  All stalls are open! 
          TEXT
        elsif men_right_stall_status == 'closed' && men_left_stall_status == 'closed'
          <<-TEXT
          🔴  Unfortunately there are no stalls open!  
          TEXT
        elsif men_right_stall_status == 'open' && men_left_stall_status == 'closed'
          <<-TEXT
          💛  Only the right stall is open! 
          TEXT
        elsif men_right_stall_status == 'closed' && men_left_stall_status == 'open'
          <<-TEXT
          💛  Only the left stall is open! 
          TEXT
        end

      else 

        case request.code 
          when 500, 503 
            <<-TEXT 
            Oh no! The Business Time API is offline at the moment. Please try again later 
            TEXT
          when 404 
            <<-TEXT
            Oh no! This doesn't appear to be real. 
            TEXT
        end
      end 
      rescue SocketError => e
        puts "Connection failed!"
      end 
    end 
  else 
    <<-TEXT 
    Unfortunately you're not authorized to use this slash command!
    TEXT
  end 
end
