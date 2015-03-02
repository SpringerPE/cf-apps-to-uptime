require 'clockwork'
include Clockwork
require_relative 'lib'
require_relative 'config'

handler do |job|
  cf_data = get_from_api(AppConfig::CF_API)
  uptime_data = get_from_api(AppConfig::UPTIME_API)

  cf_apps_to_monitor = cf_data.select {|app| should_monitor_app? app, AppConfig::ROUTE_REGEX}
  cf_apps_enhanced = cf_apps_to_monitor.map {|app| enhance_app_data app,
                                                                    AppConfig::META_PATH,
                                                                    AppConfig::ROUTE_REGEX,
                                                                    AppConfig::ALERT_THRESHOLD,
                                                                    AppConfig::INTERVAL}
  diff_data = diff(cf_apps_enhanced, uptime_data)
  puts "DIFFED DATA YO: #{diff_data}"
  carry_out_diff(diff_data, AppConfig::UPTIME_API)
end

every(5.minutes, 'update uptime')
