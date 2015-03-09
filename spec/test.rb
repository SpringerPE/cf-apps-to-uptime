require 'spec_helper'
require_relative '../lib'

describe 'should_monitor_route?' do

  context 'when given a non monitorable url' do
    it 'should return false' do
      expect(should_monitor_route?('http://cats-persistent-app.domain.com', /-live.domain.com/)).to eq false
    end
  end

  context 'when given a monitorable url' do
    it 'should return true' do
      expect(should_monitor_route?('http://component-service-live.domain.com', /-live.domain.com/)).to eq true
    end
  end
end

describe 'should_monitor_app?' do
  context 'when given a app with monitorable url' do
    data = {
      "org" => "isrctn",
      "space" => "live",
      "name"=> "isrctn-live-509",
      "routes"=> [
        "isrctn-live.domain.com",
        "isrctn-live-509.domain.com",
        ".www.isrctn.com"
      ],
      "data_from"=>1424103541
    }

    it 'should return true' do
      expect(should_monitor_app?(data, /-live.domain.com/)).to eq true
    end
  end

  context 'when given a app without monitorable url' do
    data = {
      "org"=> "oscar",
      "space"=> "live",
      "name"=> "springer-user-service-0_35",
      "routes"=> [
         "springer-user-service-0_35.domain.com",
         "springer-user-service.domain.com"
      ],
      "data_from"=> 1424103541
    }
    it 'should return false' do
      expect(should_monitor_app?(data, /-live.domain.com/)).to eq false
    end
  end
end

describe 'diff' do
  context 'when given a new route not in uptime' do
    it 'should add the route' do
      cf_data = [{"monitor_routes" => ["http://blablabla.com"], "tags" => ["simon"]}]
      uptime_data = []

      diff_data = diff(cf_data, uptime_data)
      expected = {"to_add" => [{
                                 "name" => "http://blablabla.com",
                                 "url" => "http://blablabla.com",
                                 "tags" => ["simon"]
                               }],
                  "to_delete" => [],
                  "to_update" => []}
      expect(diff_data).to eq expected
    end
  end

  context 'when given routes that are in uptime but not in cf' do
    it 'should remove them' do
      cf_data = []
      uptime_data = [{"url" => "http://blablabla.com", "org" => "simon"}]

      diff_data = diff(cf_data, uptime_data)
      expected = {"to_add" => cf_data, "to_delete" => uptime_data, "to_update" => []}
      expect(diff_data).to eq expected
    end
  end

  context 'when given a mix' do
    it 'should do the needful' do
      cf_data = [{"monitor_routes" => ["a", "g"]}, {"monitor_routes" => ["b"]}, {"monitor_routes" => ["c"]}]
      uptime_data = [{"url" => "a"}, {"url" => "c"}, {"url" => "d"}]

      diff_data = diff(cf_data, uptime_data)
      expected = {"to_add" => [{"url" => "g", "name" => "g"},
                               {"url" => "b", "name" => "b"}],
                  "to_delete" => [{"url" => "d"}],
                  "to_update" => []}
      expect(diff_data).to eq expected
    end
  end

  context 'when given a updated cf data' do
    it 'should update the check' do
      cf_data = [{"monitor_routes" => ["a"], "tags" => ["simon", "johansson"]}]
      uptime_data = [{"_id" => "WRYYYYY", "url" => "a", "name" => "a", "tags" => ["simon"]}]

      diff_data = diff(cf_data, uptime_data)
      expected = {"to_add" => [],
                  "to_delete" => [],
                  "to_update" => [{"_id" => "WRYYYYY", "tags" => ["simon", "johansson"]}]}

      expect(diff_data).to eq expected
    end
  end
end

describe 'create_app_data' do
  context 'when given a app with metadata' do
    it 'should return the app data' do
      stub_request(:get, /isrctn-live.domain.com/).
        to_return(status: 200,
                  body: '{"alerting": {"emails": ["mailme@domain.com"]}}')

      data = {
        "org" => "isrctn",
        "space" => "live",
        "name"=> "isrctn-live-509",
        "routes"=> [
          "isrctn-live.domain.com",
          "isrctn-live-509.domain.com"
        ],
        "data_from"=>1424103541
      }

      expected = {
        "monitor_routes" => ["http://isrctn-live.domain.com/internal/status"],
        "alertThreshold" => 1,  # keyword is misspelled in Uptime
        "interval" => 60,
        "tags" => ["isrctn", "mailto:mailme@domain.com"]
      }
      expect(create_app_data data, "/internal/status", /-live/, 1, 60).to eq(expected)
    end
  end
end

describe 'get_meta' do
  context 'when given a route with metadata' do
    it 'should return the meta' do
      stub_request(:get, /app.com/).
        to_return(status: 200,
                  body: '{"alerting": {"emails": ["mailme@domain.com"]}}')
      expect(get_meta('http://app.com/')).to eq({"alerting" => {"emails" => ["mailme@domain.com"]}})
    end
  end
  context 'when given a route without metadata' do
    it 'should return empty meta' do
      stub_request(:get, /app.com/).
        to_return(status: 200,
                  body: '')
      expect(get_meta('http://app.com')).to eq({})
    end
  end
    context 'when given a route with crappy json metadata' do
    it 'should return emtpy meta' do
      stub_request(:get, /app.com/).
        to_return(status: 200,
                  body: "{'emails': []}")
      expect(get_meta('http://app.com')).to eq({})
    end
  end
  context 'when given a route that 404' do
    it 'should return empty meta' do
      stub_request(:get, /app.com/).
        to_return(status: 404)
      expect(get_meta('http://app.com')).to eq({})
    end
  end
end

describe 'delete_from_uptime' do
  context 'when given a route to be deleted' do
    it 'should delete the route' do
      stub_request(:delete, /api.uptime.com/).
        to_return(:status => 200)

      delete_from_uptime({"_id" => "asdfasdf"}, "http://api.uptime.com")
      expect(WebMock).to have_requested(:delete, "http://api.uptime.com/asdfasdf")
    end
  end
end

describe 'add_to_uptime' do
  context 'when given a route to be added' do
    it 'should add the route' do
      stub_request(:put, /api.uptime.com/).
        to_return(:status => 200)

      add_to_uptime({"url" => "http://my-app-live.domain.com", "name" => "http://my-app-live.domain.com", "tags" => ["test"]}, "http://api.uptime.com")
      expect(WebMock).to have_requested(:put, "http://api.uptime.com/").
                          with(:body => {"name" => "http://my-app-live.domain.com",
                                         "url" => "http://my-app-live.domain.com",
                                         "tags" => ["test"]})

    end
  end

  context 'when given a route to be added with interval and adding interval and alertThreshold' do
    it 'should add the route with interval and alertThreshold' do
      stub_request(:put, /api.uptime.com/).
        to_return(:status => 200)

      add_to_uptime({"url" => "http://my-app-live.domain.com", "name" => "http://my-app-live.domain.com", "tags" => ["test"], "interval" => 10, "alertThreshold" => 3}, "http://api.uptime.com")
      expect(WebMock).to have_requested(:put, "http://api.uptime.com/").
                          with(:body => {"name" => "http://my-app-live.domain.com",
                                         "url" => "http://my-app-live.domain.com",
                                         "tags" => ["test"],
                                         "interval" => "10",
                                         "alertTreshold" => "3"
                                        })

    end
  end
end

describe 'carry_out_diff' do
  context 'when given a diff' do
    it 'should carry out the diff' do
      stub_request(:put, /api.uptime.com/).
        to_return(:status => 200)
      stub_request(:delete, /api.uptime.com/).
        to_return(:status => 200)
      diff_data = {"to_add" => [{"url" => "a", "name" => "a", "tags" => ["test"]}, {"url" => "b", "name" => "b", "tags" => ["test", "mailto:mailme@domain.com"]}],
                   "to_delete" => [{"_id" => "blurgh"}, {"_id" => "wakawaka"}],
                   "to_update" => []}
      carry_out_diff(diff_data, "http://api.uptime.com")
      expect(WebMock).to have_requested(:delete, "http://api.uptime.com/blurgh")
      expect(WebMock).to have_requested(:delete, "http://api.uptime.com/wakawaka")
      expect(WebMock).to have_requested(:put, "http://api.uptime.com/").
                          with(:body => {"name" => "a",
                                         "url" => "a",
                                         "tags" => ["test"]})
      expect(WebMock).to have_requested(:put, "http://api.uptime.com/").
                          with(:body => {"name" => "b",
                                         "url" => "b",
                                         "tags" => ["test", "mailto:mailme@domain.com"]})
    end
  end
end


describe 'alert_treshold' do

  context 'when given no data' do
    it 'should return nil' do
      expect(alert_treshold({}, nil)).to eq nil
    end
  end

  context 'when given only global alert_threshold' do
    it 'should return global alert_threshold' do
      expect(alert_treshold({}, 3)).to eq 3
    end
  end

  context 'when given only meta' do
    it 'should return meta threshold' do
      expect(alert_treshold({"monitoring" => {"threshold" => 3}}, nil)).to eq 3
    end
  end

  context 'when given both global and meta' do
    it 'should return meta threshold' do
      expect(alert_treshold({"monitoring" => {"threshold" => 3}}, 2)).to eq 3
    end
  end
end


describe 'interval' do

  context 'when given no data' do
    it 'should return nil' do
      expect(check_interval({}, nil)).to eq nil
    end
  end

  context 'when given only global check_interval' do
    it 'should return global check_interval' do
      expect(check_interval({}, 3)).to eq 3
    end
  end

  context 'when given only meta' do
    it 'should return meta threshold' do
      expect(check_interval({"monitoring" => {"interval" => 3}}, nil)).to eq 3
    end
  end

  context 'when given both global and meta' do
    it 'should return meta threshold' do
      expect(check_interval({"monitoring" => {"interval" => 3}}, 2)).to eq 3
    end
  end
end
