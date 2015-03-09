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
    return meta_alert_threshold
  end
  alert_threshold
end

def check_interval(meta, check_interval)
  meta_check_interval = meta.fetch("monitoring", {})["interval"]
  if meta_check_interval
    return meta_check_interval
  end
  check_interval
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
  app_data["alertThreshold"] = alert_treshold(meta, alert_threshold)
  app_data["interval"] = check_interval(meta, interval)
  app_data["tags"] = create_tags(app, meta)
  app_data
end

def diff(cf_data, uptime_data)
  return_data = {"to_delete" => [],
                 "to_add" => []}

  cf_routes = Set.new (cf_data.map {|app| app["monitor_routes"]}).flatten
  uptime_routes = Set.new uptime_data.map {|route| route["url"]}

  cf_data.each do |app|
    app['monitor_routes'].each do |route|
      if not uptime_routes.include? route
        app_data = app.clone # This will have the format of the returned hash from create_app_data
        app_data.delete("monitor_routes")
        app_data["name"] = route
        app_data["url"] = route
        return_data["to_add"] << app_data
      end
    end
  end

  uptime_data.each do |route|
    if not cf_routes.include? route["url"]
      return_data["to_delete"] << route
    end
  end
  return_data
end

def delete_from_uptime(data, uptime_api)
  HTTParty.delete(File.join(uptime_api, data['_id']))
end

def add_to_uptime(app, uptime_api)
  body = prepare_body(app)
  response = HTTParty.put(uptime_api, :body => body)
end

def prepare_body(app)
  body = {}
  body["name"] = app["name"] if app["name"]
  body["url"] = app["url"] if app["url"]
  body["tags"] = app["tags"] if app["tags"]
  body["interval"] = app["interval"] if app["interval"]
  body["alertTreshold"] = app["alertThreshold"] if app["alertThreshold"] # keyword 'alertTreshold' is misspelled, because it is misspelled in Uptime
  body
end

def carry_out_diff(diff, uptime_api)
  diff["to_add"].each do |route|
    add_to_uptime(route, uptime_api)
  end
  diff["to_delete"].each do |route|
    delete_from_uptime(route, uptime_api)
  end
end
