require 'sinatra'
require 'httparty'

InvalidTokenError = Class.new(Exception)

post '/' do

  raise(InvalidTokenError) unless params[:token] == '2BEFUpP1nHFKvh20EHT8r9Cb'

  text = params.fetch("text").strip

  if text == 'mens'

    response = HTTParty.get('http://businesstime.localytics.com/api')

    men_left_stall_status = response[0]["value"]
    men_right_stall_status = response[1]["value"]
    women_left_stall_status = response[2]["value"]
    women_right_stall_status = response[3]["value"]

    <<-TEXT
    The left stall is #{men_left_stall_status} and the right stall is #{men_right_stall_status}. 
    TEXT

  else

    <<-TEXT
    We only surface information on the men's room currently!
    TEXT
    
  end 

end