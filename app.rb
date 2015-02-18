require 'clockwork'
include Clockwork
require_relative 'lib'

handler do |job|
  cf_data = get_from_api(ENV['cf_api'])
  uptime_data = get_from_api(ENV['uptime_api'])

  cf_apps_to_monitor = cf_data.select {|app| should_monitor_app? app}
  cf_apps_enhanced = cf_apps_to_monitor.map {|app| enhance_app_data app}
  diff_data = diff(cf_apps_enhanced, uptime_data)
  puts "DIFF! #{diff_data}"
  carry_out_diff(diff_data, ENV['uptime_api'])
end

every(5.minutes, 'update uptime')
