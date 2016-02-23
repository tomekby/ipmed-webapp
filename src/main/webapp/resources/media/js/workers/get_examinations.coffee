importScripts '../vendor/lazy.min.js'
importScripts '../vendor/fetch.js'
importScripts '../vendor/moment.min.js'
importScripts '../vendor/moment-timezone.min.js'
importScripts '../config.js'
importScripts 'common.js'

examinations = null
# Filtrowanie i zliczanie elementów w zakładce nowe pomiary
self.addEventListener 'message', (e) ->
  data = e.data
  switch data.cmd
    # Start workera - pobranie danych i ich wstępne przetworzenie
    when 'start'
      res = fetch '../../../'+route_uri('#to-fill')+'?just_data=1', headers: 'Authorization': 'Basic '+ data.auth
      res.then(check_status)
      .then((resp) ->
        resp.json()
      ).then((json) ->
        examinations = map_examinations Lazy json.data
        self.postMessage ['ok']
      ).catch((e) ->
        console.log 'get examinations error'
        self.close()
      )
    # Pobieranie wszystkich pacjentów
    when 'all'
      res = ['all', examinations.size()]
      # Dane są wysyłane na żądanie, aby trochę przyspieszyć
      res.push examinations.toArray() if not data.count?
      self.postMessage res
    # Pobieranie wszystkich pacjentów do uzupełnienia
    when 'not-ok'
      not_ok = examinations.filter (v) -> v.to_complete # Pominięcie tych gdzie jest wszystko OK
      res = ['not-ok', not_ok.size()]
      # Dane są wysyłane na żądanie, aby trochę przyspieszyć
      res.push not_ok.toArray() if not data.count?
      self.postMessage res
    # Pobieranie wszystkich pacjentów do dzwonienia
    when 'phone'
      phone = examinations.filter (v) -> v.qualifiesForPhone
      res = ['phone', phone.size()]
      # Dane są wysyłane na żądanie, aby trochę przyspieszyć
      res.push phone.toArray() if not data.count?
      self.postMessage res
, false
