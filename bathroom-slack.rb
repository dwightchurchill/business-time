require 'sinatra'
require 'httparty'
require './dogfood'

InvalidTokenError = Class.new(Exception)

Dogfood.config do |cfg|
 cfg.log_events = true
 cfg.debug = true

 cfg.au = '9259d48d2ae648f40fe046d-2f8adb82-88ad-11e5-bd6a-00d0fea82624'
 cfg.pa = Time.new(2013, 10, 15).to_i
 cfg.dp = `uname`.strip
end

post '/business-time/' do

  raise(InvalidTokenError) unless params[:token] == 'SyoRNu5pZJTDvvrhn5JipsLT'

  command = params.fetch("command").strip

  if command == '/business-time'

    response = HTTParty.get('http://businesstime.localytics.com/api')

    men_left_stall_status = response[0]["value"]
    men_right_stall_status = response[1]["value"]
    women_left_stall_status = response[2]["value"]
    women_right_stall_status = response[3]["value"]
    
    if men_left_stall_status == 'open' && men_right_stall_status == 'open'

      <<-TEXT
      💚  All stalls are open! 
      TEXT

      Dogfood.log('Business Time Request', method: 'POST', status: 'All Stalls Open')
      Dogfood.flush

    elsif men_right_stall_status == 'closed' && men_left_stall_status == 'closed'

      <<-TEXT
      🔴  Unfortunately there are no stalls open!  
      TEXT

      Dogfood.log('Business Time Request', method: 'POST', status: 'No Stalls Open')
      Dogfood.flush

    elsif men_right_stall_status == 'open' && men_left_stall_status == 'closed'

      <<-TEXT
      💛  Only the right stall is open! 
      TEXT

      Dogfood.log('Business Time Request', method: 'POST', status: 'Right Stall Open')
      Dogfood.flush

    elsif men_right_stall_status == 'closed' && men_left_stall_status == 'open'
      
      <<-TEXT
      💛  Only the left stall is open! 
      TEXT

      Dogfood.log('Business Time Request', method: 'POST', status: 'Left Stall Open')
      Dogfood.flush

    end

  end 

end