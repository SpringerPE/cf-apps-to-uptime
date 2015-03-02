module AppConfig
  UPTIME_API = ENV['uptime_api']
  CF_API = ENV['cf_api']
  ROUTE_REGEX = Regexp.new (ENV['route_regex'] || '.*')
  ALERT_TRESHOLD = ENV["alertTreshold"]
  INTERVAL = ENV["interval"]
end
