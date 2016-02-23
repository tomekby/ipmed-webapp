importScripts '../vendor/lazy.min.js'
importScripts '../vendor/fetch.js'
importScripts 'common.js'

# Filtrowanie i zliczanie elementów w zakładce nowe pomiary
self.addEventListener 'message', (e) ->
  data = e.data
  switch data.cmd
    when 'start'
      res = fetch '../../../'+route_uri('#new-measurements')+'?just_data=1', headers: 'Authorization': 'Basic '+ data.auth
      res.then(check_status)
      .then((resp) ->
        resp.json()
      ).then((json) ->
        measurements = fix_measurements(Lazy(json.data)).filter((val) -> not val.patient?).size()
        self.postMessage measurements
        self.close()
      ).catch((e) ->
        console.log 'measurements updater error'
        self.close()
      )
, false