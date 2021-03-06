require 'httparty'
require 'json'

def get_from_api(api_url)
  JSON.parse(HTTParty.get(api_url).body)
end

def should_monitor_route?(route, regex)
  not (regex.match route).nil?
end

def should_monitor_app?(app, regex)
  app["routes"].each do |route|
    if should_monitor_route? route, regex
      return true
    end
  end
  false
end

def get_meta(url)
  begin
    get_from_api(url)
  rescue Exception => e
    {}
  end
end

def alert_treshold(meta, alert_threshold)
  meta_alert_threshold = meta.fetch("monitoring", {})["threshold"]
  if meta_alert_threshold
    return meta_alert_threshold.to_i
  end
  alert_threshold.to_i
end

def check_interval(meta, check_interval)
  meta_check_interval = meta.fetch("monitoring", {})["interval"]
  if meta_check_interval
    return meta_check_interval.to_i
  end
  check_interval.to_i
end

def create_tags(app, meta)
  tags = []
  tags << app["org"]
  emails = meta.fetch("alerting", {}).fetch("emails", [])
  tags << emails.map {|email| "mailto:#{email}"}
  tags.flatten
end

def create_app_data(app, meta_path, regex, alert_threshold, interval)
  app_data = {}

  entry_url = app["routes"].select {|route| should_monitor_route? route, regex }[0]
  if not /^http:\/\//.match entry_url
    entry_url = "http://#{entry_url}"
  end
  meta_url = File.join(entry_url, meta_path)
  meta = get_meta(meta_url)

  app_data["monitor_routes"] = [meta_url] # This will be enhanced trough the app metadata.
  app_data["alertTreshold"] = alert_treshold(meta, alert_threshold) # alertTreshold is wrongly spelled in uptime.
  app_data["interval"] = check_interval(meta, interval)
  app_data["tags"] = create_tags(app, meta)
  app_data["empty_meta"] = true if meta.empty?
  app_data
end

def diff(cf_data, uptime_data)
  diff_data = {"to_delete" => [],
               "to_add" => [],
               "to_update" => []}

  cf_routes = Set.new (cf_data.map {|app| app["monitor_routes"]}).flatten
  uptime_routes = Set.new uptime_data.map {|route| route["url"]}

  cf_data.each do |app|
    app['monitor_routes'].each do |url|
      if not uptime_routes.include? url
        app_data = app.clone # This will have the format of the returned hash from create_app_data
        app_data.delete("monitor_routes")
        app_data["name"] = url
        app_data["url"] = url
        diff_data["to_add"] << app_data
      else
        # Check is already in uptime, better check if we need to update it
        if not app["empty_meta"] # If we for some reason failed to fetch the meta we dont want to update the check!
          uptime_check = uptime_data.select {|u| u["url"] == url}[0]
          update_data = {}
          update_data["alertTreshold"] = app["alertTreshold"] if app["alertTreshold"] != uptime_check["alertTreshold"] # alertTreshold is wrongly spelled in uptime.
          update_data["interval"] = app["interval"] if app["interval"] != uptime_check["interval"]
          update_data["tags"] = app["tags"] if Set.new(app["tags"]) != Set.new(uptime_check["tags"])
          if not update_data.empty?
            update_data["_id"] = uptime_check["_id"]
            diff_data["to_update"] << update_data
          end
        end
      end
    end
  end

  uptime_data.each do |route|
    if not cf_routes.include? route["url"]
      diff_data["to_delete"] << route
    end
  end
  diff_data
end

def delete_from_uptime(app, uptime_api)
  HTTParty.delete(File.join(uptime_api, app['_id']))
end

def add_to_uptime(app, uptime_api)
  HTTParty.put(uptime_api, :body => app)
end

def update_check_in_uptime(app, uptime_api)
  HTTParty.post(File.join(uptime_api, app['_id']), :body => app)
end

def carry_out_diff(diff, uptime_api)
  diff["to_add"].each do |app|
    add_to_uptime(app, uptime_api)
  end
  diff["to_delete"].each do |app|
    delete_from_uptime(app, uptime_api)
  end
  diff["to_update"].each do |app|
    update_check_in_uptime(app, uptime_api)
  end
end
