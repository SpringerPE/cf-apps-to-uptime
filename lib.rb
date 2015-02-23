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

def enhance_app_data(app, meta_path, regex, alert_threshold, interval)
  entry_url = app["routes"].select {|route| should_monitor_route? route, regex }[0]
  if not /^http:\/\//.match entry_url
    entry_url = "http://#{entry_url}"
  end
  meta_url = File.join(entry_url, meta_path)
  app["monitor_routes"] = [meta_url]
  app["meta"] = get_meta(meta_url)
  app["alertTreshold"] = alert_threshold if not alert_threshold.nil?  # keyword 'alertTreshold' is misspelled, because it is misspelled in Uptime
  app["interval"] = interval if not interval.nil?
  app
end

def diff(cf_data, uptime_data)
  return_data = {"to_delete" => [],
                 "to_add" => []}

  cf_routes = Set.new (cf_data.map {|app| app["monitor_routes"]}).flatten
  uptime_routes = Set.new uptime_data.map {|route| route["url"]}

  cf_data.each do |app|
    app['monitor_routes'].each do |route|
      if not uptime_routes.include? route
        return_data["to_add"] << { "url" => route,
                                   "meta" => app["meta"],
                                   "org" => app["org"] }
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

def add_to_uptime(data, uptime_api)
  tags = []
  tags << data["org"]
  emails = data.fetch("meta", {}).fetch("alerting", {}).fetch("emails", [])
  tags << emails.map {|email| "mailto:#{email}"}

  body = {"name" => data['url'],
          "url"  => data['url'],
          "tags" => tags.flatten}
  response = HTTParty.put(uptime_api, :body => body)
end

def carry_out_diff(diff, uptime_api)
  diff["to_add"].each do |route|
    add_to_uptime(route, uptime_api)
  end
  diff["to_delete"].each do |route|
    delete_from_uptime(route, uptime_api)
  end
end
