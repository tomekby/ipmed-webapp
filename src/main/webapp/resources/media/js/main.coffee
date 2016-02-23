#
# Funkcja dodająca odpowiedni formularz
#
add_form_after_multi = ($this, $id, $name, $on_val, $placeholder = 'Wpisz wartość', $val = null) ->
  $val = $($this).val() if not $val?

  $exists = $('#'+$id).length != 0
  # Formularz nie istnieje, a powinien
  if not $exists and $val? and $on_val in $val
    $form = '<div class="col-xs-5">
               <input type="text" class="form-control" id="'+$id+'" title="'+$placeholder+'" placeholder="'+$placeholder+'" name="'+$name+'" required>
             </div>'
    $($this).closest('.form-group').append $form
    $('#'+$id).tooltip placement: 'right'
    $('#someCreator').bootstrapValidator('addField', $('#'+$id)).bootstrapValidator('revalidateField', $name)
# Formularz istnieje, a nie powinien
  else if $exists and not ($on_val in $val)
    $('#someCreator').bootstrapValidator 'removeField', $('#'+$id)
    $('#'+$id).closest('div').remove()

#
# Funkcja dodająca odpowiedni formularz po wybraniu checkboxa
# Robi fixa na listę wartości formularza
#
add_form_after_checkbox = ($this, $id, $name, $on_val, $placeholder = 'Wpisz wartość') ->
  add_form_after_multi $this, $id, $name, $on_val, $placeholder, $($this+':checked').map(-> @.value).get()

#
# Wykonywanie akcji via AJAX
#
ajax_request = ($url, $data = '', $success_handler = ($data) => ) ->
  if $curr_ajax_request? # jeśli coś aktualnie idzie, kasujemy request
    $curr_ajax_request.abort()

  $request_data =
    type: "GET"
    url: $url
    dataType: 'json'
    data: $data
    complete: ($data) ->
      if $auth_data != '' and $data.status == 503
        # W międzyczasie zalogował się inny użytkownik, więc wylogowujemy aktualnego.
        # (może się to zdarzyć jak przeglądarka nie będzie miała połączenia z serwerem i w międzyczasie ktoś się zaloguje)
        $other_user_logout = true
    success: $success_handler
    error: (jqXHR, status) ->
      return if status == 'abort' #jeśli abort pomijamy...
      # Alert z informacją o błędzie
      bootbox.alert '<h3 class="text-center">Wystąpił błąd</h3>', -> $('a[href="'+$curr_tab+'"]').trigger 'click' # Odświeżenie podstrony
  # Wykonanie requestu
  $curr_ajax_request = $.ajax $request_data

#
# Pseudo comet
#
comet = ($updaters, $auth, $refresh_time = 60) ->
  return if $auth? and $auth != $auth_data # przerwanie jeśli zmieniły się dane autoryzacyjne

  # Wykonywanie każdego updater'a
  Lazy($updaters).each ($updater) ->
# Wywołanie asynchroniczne nie blokuje tak interfejsu
    try Lazy([1]).async().each $updater
    catch
      null

  # Rekurencja
  Lazy([1]).async(1000*$refresh_time).each -> comet $updaters, $auth, $refresh_time

#
# Nowe pomiary
#
$measurements_refresh_queued = false # czy strona z nowymi pomiarami powinna być odświeżona
measurements_updater = ->
  worker = new Worker 'media/js/workers/measurements.js'
  worker.addEventListener 'message', (e) ->
    $measurements = e.data
    # Jeśli nie ma sytuacji, że nie było pomiarów i nadal nie ma
    if not ($measurements == 0 and isNaN parseInt $('#measurements-badge').html())
      # Jeśli zmieniła się ilość pomiarów jeśli jesteśmy na stronie z nowymi pomiarami
      if $new_measurements_opened and parseInt($('#measurements-badge').html()) != $measurements
        # Jeśli jest modal, zakolejkowanie na później
        if $('.modal-dialog:visible').length then $measurements_refresh_queued = true
        # Jeśli nie ma modala, odświeżenie strony
        else
          $('a[href="#new-measurements"]').trigger 'click'
          $measurements_refresh_queued = false
      # Jeśli było zakolejkowane i jesteśmy na stronie z nowymi pomiarami - odświeżenie strony
      else if $new_measurements_opened and $measurements_refresh_queued
        $('a[href="#new-measurements"]').trigger 'click'
        $measurements_refresh_queued = false
    # Update badge'a w razie potrzeby
    $('#measurements-badge').html if $measurements > 0 then $measurements else ''

  # Oddelegowanie filtrowania do workera
  worker.postMessage cmd: 'start', auth: $auth_data

#
# Filtrowanie danych do zakładki telefony
# Wg. kwalifikacji z mapowania
#
phones_filter = ($data) -> map_examinations($data).filter ($v) -> $v.qualifiesForPhone

#
# Do uzupełnienia / telefony
#
examinations_updater = ->
  worker = new Worker 'media/js/workers/get_examinations.js'
  # Dane są pobrane i przetworzone
  worker.addEventListener 'message', (e) ->
    return if e.data[0] != 'ok'

    # próba wywołania aktualizatorów
    try
      worker.postMessage cmd: 'not-ok'
      worker.postMessage cmd: 'phone'
    catch
      null
  # Aktualizacja ilości przy do uzupełnienia
  worker.addEventListener 'message', (e) ->
    return if e.data[0] != 'not-ok'
    $('#to-fill-badge').html if e.data[1] > 0 then e.data[1] else ''
  # Aktualizacja ilości przy telefonach
  worker.addEventListener 'message', (e) ->
    return if e.data[0] != 'phone'
    $('#phones-badge').html if e.data[1] > 0 then e.data[1] else ''

  # Oddelegowanie pobrania/filtrowania/przetwarzania do workera
  worker.postMessage cmd: 'start', auth: $auth_data

#
# Funkcja obsługująca automatyczne wylogowanie
#
$logout_info = false
auto_logout = ->
  return if $last_activity == 0

  # Jeśli użytkownik jest zalogowany
  if $auth_data != ''
    $duration = moment.duration ($logout_after * 60 - (moment().unix() - $last_activity))*1000
    $timer = $('#logout-timer')
    $timer.removeClass().html $duration.minutes() + ':' + (if $duration.seconds() < 10 then '0' else '') + $duration.seconds()
    # Animacja i/lub kolor
    if $duration.asSeconds() > 60
      $timer.addClass 'text-success'
    else if $duration.asSeconds() >= 30
      $timer.addClass 'text-warning'
    else
      $timer.addClass 'text-danger'
    if $logout_info
      $('#logout-info-timer').html("Sesja wygaśnie za: 0:#{(if $duration.seconds() < 10 then '0' else '') + $duration.seconds()}")

  # 30s przed wylogowaniem wyrzucony komunikat o wylogowaniu
  if $auth_data != '' and moment().unix() - $last_activity >= $logout_after * 60 - 30 and not $logout_info
    $logout_info = true
    bootbox.dialog
      closeButton: false
      message: '<h3 id="logout-info-timer" class="text-center">Sesja wygaśnie za: 0:30</h3>'
      buttons:
        cancel:
          label: 'Wyloguj'
          callback: ->
            $('.bootbox').modal 'hide'
            logout()
            $logout_info = false
            return true
        confirm:
          label: 'Kontynuuj sesję'
          callback: ->
            $last_activity = moment().unix()
            $logout_info = false
            return true
  # Jeśli użytkownik jest zalogowany i był nieaktywny dłużej niż określony czas lub ktoś inny się zalogował...
  if $auth_data != '' and ($other_user_logout or moment().unix() - $last_activity >= $logout_after * 60)
    $('.bootbox').modal 'hide'
    logout()
    $logout_info = false
    # Info o automatycznym wylogowaniu
    if $other_user_logout
      bootbox.alert '<h3 class="text-center">Wylogowano, ponieważ do aplikacji zalogował się inny użytkownik lub serwer jest przeciążony.</h3>'
    else
      bootbox.alert '<h3 class="text-center">Sesja wygasła.</h3>'

#
# Sortowanie listy pacjentów i badań
#
sort_examinations = ($divs, $href, $sort_by = 'name', $sort_order = 'asc') ->
  console.time 'examinations sort'
  $divs = Lazy($divs).sortBy ($x) ->
    $x = $($href+' .panel[data-uid="'+$x+'"]').find('[data-type="'+$sort_by+'"]').html()
    # Sortowanie po imieniu i nazwisku
    if $sort_by == 'name'
      # Zmiana kolejności imię/nazwisko
      return Lazy($x).split(' ').reduce (($old, $new) -> $old += $new+' '), ''
    return $x
  , $sort_order == 'asc'
  # Przesuwanie elementów
  $divs.each ($val) -> $($href+' table#do-uzupelnienia').next().prepend $($href+' .panel[data-uid="'+$val+'"]').detach()
  console.timeEnd 'examinations sort'
  null

