This util updates uptime based on a regex pattern for routes of applications.

1. First, it queries the cf-light-api and filter outs applications that has a route that matches a regex(specified in manifest, if nothing is specified /.*/ will be used)
2. Secondly, if specified in the manifest it goes to the meta-path of each application to fetch metadata for the application.
   Metadata might be a email address to alert if an event is triggered or other paths we want to monitor.
3. It queries the uptime api to get all the checks we already have in place.
4. It creates a datastrucure of new checks to add, checks to change and checks to delete
5. It iterates over 4 and carries out the actions.


There is a assumption made that the app exposes a metadata endpoint.

The schema is currently:

```
	{
    "alerting": { (optional)
		"emails": ["email@domain.com", "email2@domain.com"] (optional)
	},
    "monitoring": { (optional)
        "interval": 60, (optional)
        "threshold": 3, (optional)
    }
}
```

## Setting up your env
Easy peasy

	rvm use 2.0.0@cf-apps-to-uptime --create
	bundle install

## Running the tests

	rspec tests

## Getting this into CF

	mv example-manifest.yml manifest.yml
	emacs manifest.yml
	cf push
