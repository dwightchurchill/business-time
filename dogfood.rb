require 'ostruct'
require 'thread'
require 'json'

require 'uuid'
require 'faraday'

## DOGFOOD
##
## a really cheap Localytics client library slapped together to
## instrument the Localytics API
##
##
## Usage example:
##
##    Dogfood.config do |cfg|
##      cfg.log_events = Rails.env.production?
##      cfg.debug = !!ENV['DOGFOOD_DEBUG']
##
##      cfg.au = 'your id here'
##      cfg.pa = Time.new(2013, 10, 15).to_i
##      cfg.dp = `uname`.strip
##    end
##
##    Dogfood.log('Poo Click', color: 'brown', flavor: 'Count Chocula')
##
## Instantiating this class is not useful.  +Dogfood+-the-class is designed
## to be used as a singleton object.  It is threadsafe by design.

class Dogfood

private

  UUID_GEN      = UUID.new
  VERSION_STR   = "Dogfood_#{VERSION}"
  INSTALL_ID    = UUID_GEN.generate.to_s
  SESSION_ID    = UUID_GEN.generate.to_s

  @@cfg         = OpenStruct.new(flush_time: 60*2)
  @@events      = []
  @@mutex       = Mutex.new
  @@launched_at = Time.now.to_i
  @@last_flush  = Time.now
  @@blob_seq    = 0
  @@payload     = nil
  @@send_start  = true
  @@send_close  = false

public

  class << self

    ## Set or get config.
    ## Allows setting config parameters if given a block, e.g.:
    ## +Dogfood.config {|cfg| cfg.flush_time = 0}+.
    ## If not given a block, return a *copy* of the config.
    def config
      if block_given?
        @@mutex.synchronize do
          yield @@cfg
        end
      else
        @@cfg.dup
      end
    end

    ## Log an event, with optional attributes.
    def log(event, attrs={})
      return unless @@cfg.log_events
      @@mutex.synchronize do
        @@events << [event.to_s, attrs]
      end
      autoflush
    end

    ## Attempt delivery of all events to Localytics.
    def flush(args={})
      return unless @@cfg.log_events
      @@mutex.synchronize do
        @@send_close = args[:close]
        retval = send_events(@@events)
        @@events = []
        @@last_flush = Time.now
        retval
      end
    end

  private

    ## Flush the cache if longer than +config.flush_time+ seconds have passed,
    ## or if more than +config.flush_count+ events are queued.
    def autoflush
      if @@cfg.flush_time and (Time.now - @@last_flush).to_i > @@cfg.flush_time
        flush
      elsif @@cfg.flush_count and @@events.count > @@cfg.flush_count
        flush
      end
    end


    ## Attempt to send the current event queue to Localytics.  Returns true
    ## on success, false on failure, and nil if nothing had to be done.
    ## Recoverable failures result in the payload being stored in
    ## memory for future re-upload.
    def send_events(events=nil)
      events ||= @@events
      return nil unless @@payload || @@send_start || @@send_close || (events.count > 0)

      ## If we have a payload waiting already, start with that.
      start_payload = @@payload || JSON.dump(make_blob_header_hash)

      jsons = events.map {|e| JSON.dump(make_event_hash(e))}

      if @@send_start
        jsons.unshift(JSON.dump(make_session_start_hash))
        @@send_start = false
      end

      if @@send_close
        jsons << JSON.dump(make_session_close_hash)
      end

      debug @@payload = [start_payload, *jsons].join("\n")

      response = post_payload(@@payload)
      debug response.status

      case response.status / 100
      when 2 ## 2xx, success
        @@payload = nil
        true
      when 5 ## 5xx, server error -- resend later
        false
      when 4 ## 4xx, client error -- don't resend, but warn
        @@payload = nil
        puts "Got #{response.status} status in response: #{response.body}"
        false
      end
    end

    ## POSTs the given string payload in gzip format, and returns a
    ## Faraday::Response object.
    def post_payload(payload=nil)
      return unless payload ||= @@payload
      url = @@cfg.url || "http://analytics.localytics.com/api/v2/applications/#{app_id}/uploads"
      Faraday.post do |req|
        req.url url
        req.headers['Content-Type'] = 'application/json'
        req.headers['Content-Length'] = payload.size.to_s
        req.body = payload
      end
    end


    ## Create a new blob header.
    def make_blob_header_hash
      @@blob_seq += 1
      {
        dt:    "h",
        pa:    @@cfg.pa,
        seq:   @@blob_seq,
        u:     UUID_GEN.generate,
        attrs: get_blob_attrs
      }
    end

    ## Get blob attributes, using values from +config+ when available.
    def get_blob_attrs
      inherited_blob_attrs.merge(
        'lv' => VERSION_STR,
        'iu' => INSTALL_ID
      )
    end

    def inherited_blob_attrs
      %w( au du s j av dp dll dlc nc dc dma
          dmo dov nca dac mnc mcc bs b tdid
          ctdid iu udid cid cem adid cadid cid
          fbat push dpush lad or aid caid pkg ).inject({}) do |hsh, attr|
        val = @@cfg.send(attr.to_sym)
        hsh[attr] = val if val
        hsh
      end
    end


    ## Create a new event hash for the given [event, attrs] pair.
    def make_event_hash(pair)
      event, attrs = pair
      event_hash = {
        dt:    "e",
        ct:    Time.now.to_i,
        u:     UUID_GEN.generate,
        su:    SESSION_ID,
        n:     event
      }
      if attrs.count > 0
        event_hash[:attrs] = Hash[ attrs.map{|k,v| [k, v.to_s]} ]
      end
      event_hash
    end

    def make_session_start_hash
      {
        dt:  "s",
        ct:  @@launched_at,
        u:   SESSION_ID,
        new: true,
        nth: 1
      }
    end

    def make_session_close_hash
      {
        dt:  "c",
        u:   UUID_GEN.generate.to_s,
        ss:  @@launched_at,
        ct:  Time.now.to_i,
        ctl: (Time.now.to_i - @@launched_at)
      }
    end

    def debug(arg); STDERR.puts(arg) if @@cfg.debug; arg end

    def app_id; @@cfg.au end

  end ## class << self
end

## This wouldn't work with an object, but it works with a class.  Nice trick.
ObjectSpace.define_finalizer(Dogfood) { Dogfood.flush(close: true) }