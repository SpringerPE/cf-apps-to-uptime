uptime_api = ENV['uptime_api']
cf_api = ENV['cf_api']
route_regex = Regexp.new (ENV['route_regex'] || '.*')
