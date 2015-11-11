require 'sinatra'
require 'httparty'

InvalidTokenError = Class.new(Exception)

post '/business-time' do

  raise(InvalidTokenError) unless params[:token] == 'K5Dcv99PyTWwSWb7bo9M9xJt'

  command = params.fetch("command").strip

  if command == '/business-time'

    response = HTTParty.get('http://businesstime.localytics.com/api')

    men_left_stall_status = response[0]["value"]
    men_right_stall_status = response[1]["value"]
    women_left_stall_status = response[2]["value"]
    women_right_stall_status = response[3]["value"]
    
    if men_left_stall_status && men_right_stall_status == 'open'

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

  end 

end