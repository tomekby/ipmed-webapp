$logout_after = 30
$updaters_refresh_after = 30
# Poniższe 2 zmienne są ustawiane przez task na podstawie pliku properties
# Czas w minutach od ostatniej aktywności po którym nastąpi automatyczne wylogowanie
#$logout_after
# Czas w sekundach po jakim mają być odświeżone funkcje sprawdzające ilość nowości
#$updaters_refresh_after

#
# global settings → zmienne trzymane pomiędzy wszystkimi requestami
#
# aktualna / poprzednia karta (jeśli zalogowany)
$curr_tab = $prev_tab = null
# ikonki dla walidacji
$feedbackIcons =
  valid: 'void'
  invalid: 'fa fa-exclamation-circle fa-lg icon-fix'
  validating: 'fa fa-refresh fa-lg icon-fix'
# Aktualny request AJAX
$curr_ajax_request = null
$horizontal_form_row = '<div class="fluid-row">
                          <div class="col-xs-12">
                              <div class="form-group">
                                  <label class="col-sm-2 control-label dependent-label"></label>
                                  <div class="col-xs-5">
                                    {label_content}
                                  </div>
                              </div>
                          </div>
                      </div>'
# Ostatnia aktywność na poszczególnych podstronach (podstrony tu niewymienione nie będą uwzględniane)
$since =
  '#new-measurements': 0
  '#all-measurements': 0
  '#all-examinations': 0
  '#to-fill': 0
  '#phones': 0
# Dane autoryzacyjne dla HTTP basic auth (base64 string)
$auth_data = ''
# Ostatnia aktywność w aplikacji (w sekundach)
$last_activity = 0
# Flaga informująca, że auto_logout powinien wylogować użytkownika ze względu na zalogowanego innego użytkownika.
$other_user_logout = false
# Nazwa aktualnie zalogowanego użytkownika
$username = null
$new_measurements_opened = false
# Ustawienia datepickera
$datepicker_settings =
  language: 'pl'
  pickTime: false
  maxDate: new Date()
# Używana strefa czasowa
$timezone_used = 'Europe/Warsaw'
#
# Pierwsza litera wielka
#
String::capitalize = ->
  @replace /^./, (match) ->
    match.toUpperCase()

#
# Pokazywanie/ukrywanie overlay'a
#
show_overlay = -> $('#ajaxOverlay').fadeIn 100 if not $('#ajaxOverlay').is ':visible'

#
# Pobieranie danych i statusu z serwera
#
read_with_status = ($url) ->
  $response = {}
  $.ajax
    type: 'GET'
    url: $url
    async: false
    complete: ($data) ->
      if $data.getResponseHeader('client-uuid')?
        $.ajaxSetup headers: {
          "client-uuid": $data.getResponseHeader('client-uuid')
        }
      if $auth_data != '' and $data.status == 503
        # W międzyczasie zalogował się inny użytkownik, więc wylogowujemy aktualnego.
        # (może się to zdarzyć jak przeglądarka nie będzie miała połączenia z serwerem i w międzyczasie ktoś się zaloguje)
        $other_user_logout = true
      $response =
        text: $data.responseText
        status: $data.status
  # Ukrycie overlay'a
  $('#ajaxOverlay').fadeOut 100
  $response

#
# Pobieranie danych z serwera
#
read_data = ($url) -> read_with_status($url).text

#
# Pobieranie danych JSON z serwera
#
read_json = ($url) -> $.parseJSON read_data $url

#
# Wysyłanie danych do serwera z odczytaniem treści i statusu
#
write_with_status = ($type, $url, $data) ->
  $response = null
  $status = 200
  $.ajax
    type: $type
    url: $url
    contentType: 'application/json; charset=utf-8'
    data: $data
    async: false
    complete: ($res) ->
      if $auth_data != '' and $res.status == 503
        # W międzyczasie zalogował się inny użytkownik, więc wylogowujemy aktualnego.
        # (może się to zdarzyć jak przeglądarka nie będzie miała połączenia z serwerem i w międzyczasie ktoś się zaloguje)
        $other_user_logout = true
      $status = $res.status
      try $response = $.parseJSON $res.responseText if $res.responseText.length
      catch
        $response = ''

  'content': $response,
  'status': $status

write_data = ($type, $url, $data) ->
  # Pokazanie overlay'a
  show_overlay()

  $res = write_with_status $type, $url, $data

  $('#ajaxOverlay').fadeOut 100
  bootbox.alert '<h3>Wystąpił błąd w trakcie zapisu danych.</h3>' if $res.status >= 300 and $res.status != 503

  $res.content

#
# Lista event handlerów dla aktualnej strony
#
$event_handlers = []
add_event = ($event, $selector, $function) ->
  $new =
    event: $event
    selector: $selector
  return if Lazy($event_handlers).indexOf($new) != -1

  $(document).on $event, $selector, $function
  $event_handlers.push $new

#
# Pobieranie nazwy aktualnie zalogowanego użyszkodnika (lekarza)
# Cachuje wartość na później
#
get_username = ->
# Jeśli nie ma zapisanego, pobranie
  $username = read_data 'support/myname' if $username == null
  $username

#
# Sprawdzanie czy dana zmienna jest tablicą
#
typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'

#
# Okno błędu logowania.
#
show_login_error = ($error_code) ->
  $error_message = switch $error_code
    when 401 then 'Wprowadzono błędne dane logowania.'
    when 503 then 'Zalogowany jest inny użytkownik lub serwer jest przeciążony.'
    else 'Błąd logowania wywołany wewnętrznym błędem serwera.'
  bootbox.alert '<h3 class="text-center">' + $error_message + '</h3>'
  $('#ajaxOverlay').fadeOut 100

#
# Funkcja wylogowania
#
logout = ->
  $('#subpages-content > div, #page-logged-in-content').hide().html ''
  # Czyszczenie ostatniej aktywności
  for $k, $v of $since
    $since[$k] = 0
  $('#login-page').parent('').parent('').show()
  $('li.login').removeClass('active').hide()
  # czyszczenie walidacji i formularzy
  $('form').data('bootstrapValidator').resetForm()
  $('form').trigger "reset"
  $curr_tab = $prev_tab = null
  # przerwanie requesta w razie potrzeby
  if $curr_ajax_request? # jeśli coś aktualnie idzie, kasujemy request
    $curr_ajax_request.abort()
    $curr_ajax_request = null
  # Faktyczne wylogowanie po stronie serwera
  if $auth_data != ''
    read_data 'support/logout'
  # Czyszczenie uuid klienta
  delete $.ajaxSettings.headers['client-uuid']
  # Czyszczenie danych autoryzacyjnych
  $auth_data = ''
  $.ajaxSetup headers: "Authorization": ''
  # Czyszczenie cookies-a
  document.cookie = 'JSESSIONID=;expires=Thu, 01 Jan 1970 00:00:01 GMT'
  # Czyszczenie info o ostatniej aktywności
  $last_activity = 0
  # Czyszczenie zapisanej nazwy użytkownika
  $username = null

#
# Okno dialogowe przypisania/edycji pomiaru
#
show_measurement_dialog = ($mid) ->
  $measurement = read_json 'measurements/' + $mid
  $surname = if $measurement.patient? then (if $measurement.patient.surname? then $measurement.patient.surname else '') else (if $measurement.embeddedSurname? then $measurement.embeddedSurname else '')
  $first_name = if $measurement.patient? then (if $measurement.patient.firstName? then $measurement.patient.firstName else '') else (if $measurement.embeddedFirstName? then $measurement.embeddedFirstName else '')
  $pesel = if $measurement.patient? then $measurement.patient.identityNumber else (if $measurement.embeddedIdentityNumber? then $measurement.embeddedIdentityNumber else '')
  # Nazwa aktualnie zalogowanego lekarza (jeśli jest wpisany, zostawienie; domyślnie aktualnie zalogowany)
  $doctor = if $measurement.patient? and $measurement.patient.doctor then $measurement.patient.doctor else get_username()

  # Formularz w dialogu
  $form = '<div class="row">
        <div class="col-sm-5">
          Dane wprowadzone na kardiografie
          <dl class="dl-horizontal">
            <dt>Nazwisko</dt>
            <dd>'+(if $measurement.embeddedSurname? then $measurement.embeddedSurname else '[nie wprowadzono]')+'</dd>
            <dt>Imię (imiona)</dt>
            <dd>'+(if $measurement.embeddedFirstName? then $measurement.embeddedFirstName else '[nie wprowadzono]')+'</dd>
            <dt>PESEL</dt>
            <dd>'+(if $measurement.embeddedIdentityNumber? then $measurement.embeddedIdentityNumber else '[nie wprowadzono]')+'</dd>
            <dt>Data i czas badania</dt>
            <dd>'+(if $measurement.embeddedDate? then timestamp_to_datetime($measurement.embeddedDate) else '[nie wprowadzono]')+'</dd>
          </dl>
        </div>
        <div class="col-sm-7">
          <strong>Poprawne dane</strong>
          <form class="form-horizontal measurements-to-fill" autocomplete="off">
            <div class="form-group">
                <label class="col-xs-4 control-label">Nazwisko</label>
                <div class="col-xs-7">
                  <input type="text" class="form-control" name="surname" required value="'+$surname+'">
                </div>
            </div>
            <div class="form-group">
                <label class="col-xs-4 control-label">Imię (imiona)</label>
                <div class="col-xs-7">
                  <input type="text" class="form-control" name="firstName" required value="'+$first_name+'">
                </div>
            </div>
            <div class="form-group">
                <label class="col-xs-4 control-label">PESEL</label>
                <div class="col-xs-7">
                  <input type="text" class="form-control" name="identityNumber" value="'+$pesel+'">
                </div>
            </div>
            <div class="form-group">
                <label class="col-xs-4 control-label">Data i czas badania</label>
                <div class="col-xs-7">
                  <div class="input-group datetime">
                      <input type="text" class="form-control" name="actualDate" data-bv-date="true" data-bv-date-format="YYYY-MM-DD HH:mm" required value="'+(if $measurement.actualDate? then timestamp_to_datetime($measurement.actualDate) else (if $measurement.embeddedDate? then timestamp_to_datetime($measurement.embeddedDate) else ''))+'">
                      <span class="input-group-addon"><span class="fa fa-calendar"></span></span>
                  </div>
                </div>
            </div>
            <div class="form-group">
                <label class="col-xs-4 control-label">Lekarz prowadzący</label>
                <div class="col-xs-7">
                  <input type="text" class="form-control" required name="doctor" value="'+$doctor+'">
                </div>
            </div>
          </form>
        </div>
      </div>'

  date_after_before = ($p) ->
    return {after: null, before: null} if not $p.interview?

    after   : if $p['interview']['arrivalDate']? then $p['interview']['arrivalDate'] else (if $p['interview']['strokeDate']? then $p['interview']['strokeDate'] else null)
    before : if $p['interview']['dateOfDeath']? then $p['interview']['dateOfDeath'] else (if $p['interview']['approximateDateOfDeath']? and $p['interview']['approximateDateOfDeath'].match(/\d[\-\.]\d[\-\.]\d/) != null then $p['interview']['approximateDateOfDeath'] else null)
  # Wyciąganie klucza głównego z formularza
  pk_from_form = ($form) ->
    identityNumber: $($form).find('input[name="identityNumber"]').val()
    firstName: $($form).find('input[name="firstName"]').val()
    surname: $($form).find('input[name="surname"]').val()
  $patients = Lazy(read_json 'patients')
  # Potrzebne przy sprawdzaniu daty i czasu badania
  $date_after_before = null
  $tmp_pk = pk_from_form $form
  $patient = $patients.findWhere($tmp_pk)
  if $patient?
    $date_after_before = date_after_before $patient
  # Bootbox
  $dialog = bootbox.dialog({
    title: 'Potwierdzenie tożsamości pacjenta'
    message: $form
    show: false
    buttons:
      cancel:
        label: "Anuluj"
      success:
        label: "Potwierdź"
        className: "btn-primary"
        callback: ->
          $tmp_pk = pk_from_form $dialog
          $patient = $patients.findWhere($tmp_pk)
          # taki użyszkodnik nie istnieje
          if not $patient?
            $new_user = $dialog.find('input[name="firstName"], input[name="surname"], input[name="identityNumber"], input[name="doctor"]').serializeJSON()
            $new_user.birthDate = date_to_timestamp(date_from_PESEL($new_user.identityNumber.split('')))
            $new_user.interview = sex: if (parseInt($new_user.identityNumber.split('')[9]) % 2 == 1) then 'MALE' else 'FEMALE'
            # dodanie użytkownika
            $patient = write_data 'post', 'patients/', JSON.stringify $new_user
          # update wpisu
          $measurement = write_data 'put', 'measurements/'+$mid, JSON.stringify actualDate: datetime_to_timestamp($dialog.find('input[name="actualDate"]').val())
          # przypisanie pomiaru do użyszkodnika
          write_data 'put', 'patients/'+$patient.id+'/measurements/'+$mid, null
          # przepisanie innych danych z pomiaru jeżeli pacjent ich nie miał
          $new_patient = $dialog.find('input[name="firstName"], input[name="surname"], input[name="doctor"]').serializeJSON()
          $new_patient.interview = {}
          if not $patient.interview?
            $patient.interview = {}
          if not $patient.interview.weight? and $measurement.weight?
            $new_patient.interview.weight = $measurement.weight
          if not $patient.interview.height? and $measurement.height?
            $new_patient.interview.height = $measurement.height
          if not $patient.birthDate? and $measurement.embeddedBirthDate?
            $new_patient.birthDate = $measurement.embeddedBirthDate
          # update danych użytkownika
          write_data 'put', 'patients/'+$patient.id, JSON.stringify $new_patient
          # Odświeżenie aktualnej podstrony
          $('a[href="' + $curr_tab + '"]').trigger 'click'
  }).on 'shown.bs.modal', ->
    # Kliknięcie entera w formularzu
    add_event 'keydown', '.bootbox input[type="text"]', ($e) ->
      if $e.which == 13 # enter
        $($e.target).closest('.modal-content').find('.btn-primary').trigger 'click'
        $e.preventDefault()
    # Init walidacji po pokazaniu tego
    $('.bootbox form').bootstrapValidator({
      feedbackIcons: $feedbackIcons
      fields:
        surname:
          container: 'tooltip'
        firstName:
          container: 'tooltip'
        actualDate:
          validators:
            callback:
              message: 'Data musi być pomiędzy rokiem 2005 a dniem dzisiejszym'
              callback: ($value) ->
                $basic_valid = not moment(datetime_to_timestamp $value).isAfter() and not moment($value).isBefore('2005-01-01')
                if $basic_valid and $patients.findWhere(pk_from_form $('.bootbox form'))?
                  if $date_after_before.after != null and moment($value).isBefore $date_after_before.after
                    return valid: false, message: 'Data pomiaru musi być późniejsza od daty przyjęcia'
                  else if $date_after_before.before != null and moment($value).isAfter $date_after_before.before
                    return valid: false, message: 'Data pomiaru musi być wcześniejsza od daty śmierci'
                $basic_valid
          container: 'tooltip'
        doctor:
          container: 'tooltip'
        identityNumber:
          container: 'tooltip'
          validators:
            callback:
              message: 'Błędny nr PESEL'
              callback: PESEL_validator
    }).on 'success.field.bv', ($e, $data) ->
      # Odblokowanie wysłania formularza jeśli nie ma nieprawidłowych pól
      if $($e.target).closest('form').find('.has-error').length == 0
        $($e.target).closest('.modal-content').find('.btn-primary').removeClass 'disabled'
      # Aktualizacja walidacji daty pomiaru względem pacjenta jeżeli się zmienił
      $this_form = $($e.target).attr 'name'
      if ($this_form == 'identityNumber' or $this_form == 'firstName' or $this_form == 'surname')
        $tmp_pk = pk_from_form $($e.target).closest 'form'
        $patient = $patients.findWhere($tmp_pk)
        if $patient?
          # Data po której musi być pomiar
          $date_after_before = date_after_before $patient
        else
          $date_after_before = null
        $parent = $($e.target).closest 'form'
        $($parent).bootstrapValidator 'revalidateField', 'actualDate'
      # kasowanie klasy wskazującej na sukces
      $parent = $data.element.parents '.form-group'
      $parent.removeClass 'has-success'
    .on 'error.form.bv error.field.bv', ($e) -># Blokada wysłania formularza jeśli są jakieś nieprawidłowe pola
      $($e.target).closest('.modal-content').find('.btn-primary').addClass 'disabled'
    .bootstrapValidator 'validate'

    # Init typeaheadów
    $typeahead_source = $patients.toArray()
    typeahead_patient_to_string = ($item) ->
      $item.surname + ' ' + $item.firstName + ' ' + $item.identityNumber
    typeahead_callback = ($item) ->
      Lazy(['identityNumber', 'surname', 'firstName', 'doctor']).each ($i) ->
        $field = $($dialog).find('input[name="'+$i+'"]')
        $field.val $item[$i]
      # Data po której musi być pomiar
      $date_after_before = date_after_before $item
      $('.bootbox form').bootstrapValidator('resetForm').bootstrapValidator('validate')

    $('.bootbox form input[name="surname"]').typeahead
      source: $typeahead_source
      displayText: typeahead_patient_to_string
      matcher: ($item) ->$item.surname.startsWith @.query
      afterSelect: typeahead_callback
    $('.bootbox form input[name="firstName"]').typeahead
      source: $typeahead_source
      displayText: typeahead_patient_to_string
      matcher: ($item) ->$item.firstName.startsWith @.query
      afterSelect: typeahead_callback
    $('.bootbox form input[name="identityNumber"]').typeahead
      source: $typeahead_source
      displayText: typeahead_patient_to_string
      matcher: ($item) ->$item.identityNumber.startsWith @.query
      afterSelect: typeahead_callback

    # Init datetime pickera
    $('.bootbox.in div.datetime').datetimepicker({
      pickTime: true
      language: 'pl'
      sideBySide: true
      maxDate: new Date()
    }).on 'dp.change dp.show', -> # refresh walidacji po zmianie wartości
      $(@).closest('form').bootstrapValidator 'revalidateField', $(@).find('input').attr 'name'
  .modal 'show'

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



###################################################
# Obsługa specyficzna dla poszczególnych podstron #
###################################################

#
# Strona główna/pomiary
#
measurements_page_handler = ($data, $href) ->
  $(($href += '-div')+'-tmp').empty()
  # Nie ma nic do roboty jeśli nie ma nowych danych
  return if $data.isEmpty()

  # Usuwanie pomiaru - obsługa kliknięcia przycisku
  add_event 'click', 'a[data-type="del-measurement"]', ($e) ->
    $e.preventDefault()
    $anchor = $(@)
    bootbox.confirm(
      title: "Potwierdzenie usunięcia pomiaru",
      message: "Czy na pewno usunąć pomiar?",
      callback: ($result) ->
        if $result
          write_data 'delete', 'measurements/'+$anchor.data('id'), null
          $('a[href="'+$curr_tab+'"]').trigger 'click'
    ).find("div.modal-dialog").css("width", "450px")

  $data.each ($v) ->
    # Dane użytkownika
    if $v.patient?
      $patient_name = ''
      if $v.patient.surname?
        $patient_name += $v.patient.surname+' '
      if $v.patient.firstName?
        $patient_name += $v.patient.firstName
    else
      $patient_name = '&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp-'
    $embedded_data = ''
    if $v.embeddedSurname?
      $embedded_data += $v.embeddedSurname+' '
    if $v.embeddedFirstName?
      $embedded_data += $v.embeddedFirstName
    if $embedded_data == ''
      $embedded_data = '[nie wprowadzono]'
    $date =
      if $v.actualDate? then timestamp_to_datetime($v.actualDate) else
        if $v.zboxAcquisitionDate? then timestamp_to_datetime($v.zboxAcquisitionDate) else
          if $v.embeddedDate? then timestamp_to_datetime($v.embeddedDate) else ''

    # Wiersz w tabeli
    $tmp = '<tr id="new-measurements'+$v.id+'">
              <td>'+$date+'</td>
              <td>'+$patient_name+'</td>
              <td>'+$embedded_data+'</td>
              <td>'+(if not $v.patient? then text_to_err('tożsamość niepotwierdzona') else $measurement_ok)+'</td>
              <td class="text-right"><a href="#" class="btn btn-danger btn-xs" data-id="'+$v.id+'" data-type="del-measurement">Usuń</a></td>
            </tr>'

    # Wywołanie bootbox'a
    add_event 'click', $href+' tr#new-measurements'+$v.id+' > td:not(:last-of-type)', ->
      show_measurement_dialog $v.id
    $($href+' table#measurements_all tbody').prepend $tmp

#
# Pierwsza podstrona ('do uzupełnienia'/'telefony'/'wszystkie pomiary')
#
examinations_page_handler = ($data, $href) ->
  # Nie ma nic do roboty jeśli nie ma nowych danych
  return if $data.isEmpty()

  # Usuwanie pacjenta - obsługa kliknięcia przycisku
  add_event 'click', 'a[data-type="del-person"]', ($e) ->
    $e.preventDefault()
    $anchor = $(@)
    bootbox.confirm(
      title: "Potwierdzenie usunięcia pacjenta",
      message: "Czy na pewno usunąć pacjenta: " + $anchor.data('patient') + "?",
      callback: ($result) ->
        if $result
          write_data 'delete', 'patients/'+$anchor.data('id'), null
          $('a[href="'+$curr_tab+'"]').trigger 'click'
    ).find("div.modal-dialog").css("width", "450px")

  # Edycja pomiaru - obsługa kliknięcia przycisku
  add_event 'click', 'a[data-type="edit-measurement"]', ($e) ->
    $e.preventDefault()
    show_measurement_dialog $(@).data('id')

  $href += '-div'
  $data.each ($v) ->
    # Renderowanie listy pomiarów dla pacjenta
    $pomiary = Lazy($v.measurements).reduce (($pomiary, $v2) ->
      $date = timestamp_to_datetime($v2.actualDate)
      $pomiary += '<div class="row measurement-row">
          <div class="col-xs-offset-1 col-xs-3">Pomiar '+$date+'</div>
          <div class="col-xs-2"><a href="#" data-id="'+$v2.id+'" data-type="edit-measurement" class="btn btn-primary btn-xs">EDYTUJ</a></div>
        </div>'
    ), ''
    # Numer telefonu do kontaktu jeśli jesteśmy na stronie telefonów
    $phones = []
    if $href == '#phones-div'
      $phones.push $v.interview.phoneNumber if $v.interview? and $v.interview.phoneNumber?
      $phones.push $v.interview.phoneNumber2 if $v.interview? and $v.interview.phoneNumber2?
      # Nie ma wpisanego telefonu to komunikat
      if $phones.length == 0
        $phones = '<div class="row"><div class="col-xs-offset-1 col-xs-3 text-danger"><strong>Brak wpisanego telefonu kontaktowego</strong></div></div>'
      # Jest wpisany minimum jeden telefon kontaktowy
      else
        $phones = Lazy($phones).reduce(($old, $phone) ->
            $old + '<a href="tel:'+$phone+'"><i class="fa fa-phone"></i> '+$phone+'</a> '
          , '<div class="row"><div class="col-xs-offset-1 col-xs-3 text-danger">'+(if $phones.length == 1 then 'Telefon kontaktowy' else 'Telefony kontaktowe')+': ')+'</div></div>'
    else $phones = ''

    # Bez &nbsp; przeglądarka dostaje pierdolca przy renderingu
    $ankieta_class = if -1 != $v.notes.indexOf 'niepełna ankieta' then ' text-danger' else ''
    $obserwacja_class = if -1 != $v.notes.indexOf 'brak informacji o przeżyciu' then ' text-danger' else ''
    $patient_name = ''
    if $v.surname?
      $patient_name += $v.surname+' '
    if $v.firstName?
      $patient_name += $v.firstName
    if $patient_name == ''
      $patient_name = '[nie wprowadzono]'
    $doctor = if $v.doctor? then $v.doctor else '[nie wprowadzono]'
    # Ustalanie daty przyjęcia
    $arrival_date = null
    # Data przyjęcia ustalona w ankiecie
    if $v.interview? and $v.interview.arrivalDate?
      $tmp = parseInt $v.interview.arrivalDate
      $arrival_date = timestamp_to_date $tmp if not isNaN $tmp
    # Nie ma daty przyjęcia w ankiecie - szukanie w pomiarach
    if not $arrival_date? and $v.measurements? and $v.measurements.length != 0
      $tmp = Lazy($v.measurements).pluck('actualDate').min()
      if not isNaN $tmp
        $arrival_date = if moment($tmp).isSame(moment(), 'day') then moment($tmp).format('HH:mm') else timestamp_to_date $tmp
    $arrival_date = '[brak]' if not $arrival_date?

    $tmp = '
<div class="panel panel-default" data-uid="'+$v.id+'">
  <div class="panel-heading" role="tab">
    <h4 class="panel-title">
      <a data-toggle="collapse" href="#patients'+$v.id+'" aria-expanded="true">
        <div id="patients-row'+$v.id+'">
            <div class="col-xs-1 id-col" data-type="id"><span class="fa fa-chevron-down patient-info"></span>'+$v.id+'</div>
            <div class="col-xs-2 name-col" data-type="name">'+$patient_name+'</div>
            <div class="col-xs-2 arrival-date-col" data-type="date">'+$arrival_date+'</div>
            <div class="col-xs-2 doctor-col" data-type="doctor">'+$doctor+'</div>
            <div class="col-xs-5 notes-col examination-notes">'+$v.notes+'</div>
        </div> <a href="#" class="btn btn-danger btn-xs del-person-btn" style="color: #fff" data-id="'+$v.id+'" data-type="del-person" data-patient="'+ $v.firstName + ' ' + $v.surname + ' ' + $v.identityNumber + '">Usuń</a>&nbsp;
      </a>
    </h4>
  </div>
  <div id="patients'+$v.id+'" class="panel-collapse collapse" role="tabpanel">
    <div class="panel-body">
      '+$pomiary+$phones+'
      <div class="row">
        <div class="col-xs-offset-1 col-xs-3'+$ankieta_class+'">Ankieta</div>
        <div class="col-xs-2"><a href="#patients/ankieta/'+$v.id+'" class="btn btn-primary btn-xs move-to">EDYTUJ</a></div>
      </div>
      <div class="row">
        <div class="col-xs-offset-1 col-xs-3'+$obserwacja_class+'">Obserwacja półroczna / zgon</div>
        <div class="col-xs-2"><a href="#patients/observation/'+$v.id+'" class="btn btn-primary btn-xs move-to">EDYTUJ</a></div>
      </div>
    </div>
  </div>
</div>'

    # Dopisanie kolejnej osoby
    $($href+' table#do-uzupelnienia').next().prepend $tmp
  $divs = []
  # Info dodatkowe
  $($href+' .panel').each ($id, $el) ->
    $divs.push $($el).data 'uid'
  # Zmiana sortowania
  add_event 'click', $href+' table#do-uzupelnienia a', ($e) ->
    $e.preventDefault()
    # Reset klas css
    $($href+' table#do-uzupelnienia i').removeClass('fa-sort-asc fa-sort-desc fa-sort').addClass 'fa-sort'
    # Kierunek sortowania
    $asc = $(@).data('asc') == 1
    $order = if $asc then 'asc' else 'desc'
    # Właściwe sortowanie elementów
    $(@).data('asc', if $asc then 0 else 1).find('i').addClass if $order == 'asc' then 'fa-sort-asc' else 'fa-sort-desc'
    sort_examinations $divs, $href, $(@).data('sortby'), $order

# Data przyjęcia używana w karcie pacjenta
$interview_arrival_date = null
#
# Karta pacjenta/ankieta
#
interview_page_handler = ($data) ->
  $('span#patient-name').html $data.firstName+' '+$data.surname
  $uid = $data.id
  $interview_arrival_date = arrivalDate $data
  $('[id^=detail-]').hide()
  add_event 'click', '.toggle', ->
    $target = $('#'+$(@).attr('data-toggle'))
    $target.slideToggle()

  # formularz został ukryty po kliknięciu czegoś
  form_hidden = ($this) ->
    # kasowanie info o błędzie w sekcji jeśli nie ma tam żadnych błędów
    $el = $($this).closest 'li.list-group-item'
    unless $el.find('[data-bv-result="INVALID"]:visible').length
      $el.find('.toggle').css('color', '').find('.col-xs-10').find('.err-info').remove()
    # kasowanie klasy wskazującej na sukces
    $parent = $($this).parents '.form-group'
    $parent.removeClass 'has-success'
    $('#someCreator').bootstrapValidator 'disableSubmitButtons', false

  # kasowanie info o błędzie w sekcji jeśli nie ma tam żadnych błędów
  fix_section_if_valid = ($element) =>
    $el = $element.closest('li.list-group-item')
    unless $el.find('[data-bv-result="INVALID"]').length > 0
      $el.find('.toggle').css('color', '').find('.col-xs-10').find('.err-info').remove()
    # kasowanie klasy wskazującej na sukces
    $parent = $element.parents '.form-group'
    $parent.removeClass 'has-success'

  # 'Kreator' formularza
  # Threads are evil (http://www.eecs.berkeley.edu/Pubs/TechRpts/2006/EECS-2006-1.pdf)
  # Ale dzięki temu czas renderowania spada z ~1400ms do ~700ms...
  Lazy([1]).async().each ->
    console.time "validator setup"
    # Data śmierci jeśli już była wpisana
    $death_time = if $data.interview? and $data.interview.dateOfDeath? then $data.interview.dateOfDeath else null
    arrivalDateValid = ($value) ->
      $value = date_to_timestamp $value
      if moment($value).isAfter() or moment($value).isBefore '2005-01-01'
        return valid: false, message: 'Data musi być pomiędzy rokiem 2005 a dniem dzisiejszym'
      $strokeDate = $('#inputStrokeOccur').val()
      if $strokeDate != '' and moment($value).isBefore $strokeDate
        return valid: false, message: 'Data przyjęcia musi być późniejsza od daty przyjęcia'
      if $death_time? and moment($value).isAfter $death_time
        return valid: false, message: 'Data przyjęcia musi być wcześniejsza od daty śmierci'
      true
    strokeDateValid = ($value) ->
      $value = date_to_timestamp $value
      if moment($value).isAfter() or moment($value).isBefore '2005-01-01'
        return valid: false, message: 'Data musi być pomiędzy rokiem 2005 a dniem dzisiejszym'
      $arrivalDate = $interview_arrival_date
      if $arrivalDate != '' and moment($value).isAfter $arrivalDate
        return valid: false, message: 'Data udaru musi być wcześniejsza od daty przyjęcia'
      if $death_time? and moment($value).isAfter $death_time
        return valid: false, message: 'Data udaru musi być wcześniejsza od daty śmierci'
      true
    $('#someCreator').bootstrapValidator({
      feedbackIcons: $feedbackIcons
      excluded: [':disabled']
      fields:
        identityNumber:
          validators:
            callback:
              message: 'Błędny nr PESEL'
              callback: PESEL_validator
        birthDate:
          validators:
            date: {format: 'YYYY-MM-DD'}
            callback:
              message: 'Błędna data urodzenia'
              callback: ($value) -> birthDate_validator $value, $('#inputPESEL').val()
        'interview[arrivalDate]':
          validators:
            date: {format: 'YYYY-MM-DD'}
            callback:
              callback: ($val) ->
                $interview_arrival_date = moment($val)
                $interview_arrival_date = if $interview_arrival_date.isValid() then $interview_arrival_date.valueOf() else arrivalDate $data
                arrivalDateValid $val
        'interview[strokeDate]':
          validators:
            date: {format: 'YYYY-MM-DD'}
            callback:
              callback: strokeDateValid
        'interview[rankinPoints]': { validators: {integer: {}} }
        'interview[nihssPoints]': { validators: {integer: {}} }
        'interview[gcsScale]': { validators: {integer: {}} }
        'interview[totalCholesterol]': { validators: {numeric: {}}, container: 'tooltip' }
        'interview[ldl]': { validators: {numeric: {}}, container: 'tooltip' }
        'interview[hdl]': { validators: {numeric: {}}, container: 'tooltip' }
        'interview[trg]': { validators: {numeric: {}}, container: 'tooltip' }
        'interview[rbc]': { validators: {numeric: {}}, container: 'tooltip' }
        'interview[wbc]': { validators: {numeric: {}}, container: 'tooltip' }
        'interview[hgb]': { validators: {numeric: {}}, container: 'tooltip' }
        'interview[ht]':  { validators: {numeric: {}}, container: 'tooltip' }
        'interview[mcv]': { validators: {numeric: {}}, container: 'tooltip' }
        'interview[plt]': { validators: {numeric: {}}, container: 'tooltip' }
        'interview[creatinine]': { validators: {numeric: {}} }
        'interview[tsh]': { validators: {numeric: {}} }
        'interview[potassium]': { validators: {numeric: {}} }
        'interview[inr]': { validators: {numeric: {}} }
        'interview[crp]': { validators: {numeric: {}} }
        'interview[education]': { validators: {notEmpty: {}} }
        'interview[employment]': { validators: {notEmpty: {}} }
        'interview[sex]':
          validators:
            notEmpty: {}
            callback:
              message: 'Płeć nie zgadza się z numerem PESEL'
              callback: ($value) ->
                sex_validator $('input[name="interview[sex]"]:checked').val(), $('#inputPESEL').val()
        'interview[weightAccuracy]': { validators: {notEmpty: {}} }
        'interview[symptomLesionLocation]': { validators: {notEmpty: {}} }
        'interview[screeningTypeDate]': { validators: {notEmpty: {}} }
        'interview[strokeType]': { validators: {notEmpty: {}} }
        'interview[screeningLesionLocation]': { validators: {notEmpty: {}} }
        'interview[transcranialUltrasonographyResult]': { validators: {notEmpty: {}} }
        'interview[headArteriesUltrasonographyResult]': { validators: {notEmpty: {}} }
        'interview[hypertension]': { validators: {notEmpty: {}} }
        'interview[kidneysDiseases]': { validators: {notEmpty: {}} }
        'interview[diabetes]': { validators: {notEmpty: {}} }
        'interview[ischemicHeartDisease]': { validators: {notEmpty: {}} }
        'interview[ccsClass]': { validators: {notEmpty: {}} }
        'interview[lipidsDisorders]': { validators: {notEmpty: {}} }
        'interview[atrialFibrillation]': { validators: {notEmpty: {}} }
        'interview[cigarettes]': { validators: {notEmpty: {}} }
        'interview[neckArteriesDiseases]': { validators: {notEmpty: {}} }
        'interview[heartFailure]': { validators: {notEmpty: {}} }
        'interview[nyhaClass]': { validators: {notEmpty: {}} }
        'interview[veinsThrombosis]': { validators: {notEmpty: {}} }
        'interview[hormoneTherapy]': { validators: {notEmpty: {}} }
        'interview[familyDiseasesStroke]': { validators: {notEmpty: {}} }
        'interview[familyDiseasesHeartFailure]': { validators: {notEmpty: {}} }
        'interview[familyDiseasesDiabetes]': { validators: {notEmpty: {}} }
        'interview[familyDiseasesIschemicHeart]': { validators: {notEmpty: {}} }
        'interview[familyDiseasesHypertension]': { validators: {notEmpty: {}} }
        'interview[drugsBeforeStroke][]': { validators: {notEmpty: {}} }
        'interview[drugsOnHospitalisation][]': { validators: {notEmpty: {}} }
        'interview[drugsOnDischarge][]': { validators: {notEmpty: {}} }
        # pola domyślnie nie sprawdzane/ze zmienną obowiązkowością
        'interview[pastStrokeYear]':
          validators:
            notEmpty: {}
            callback: # Sprawdzenie, czy ktoś nie wpisał roku z przyszłości
              message: 'Data wcześniejszego udaru musi być przed datą przyjęcia'
              callback: ($value) ->
                return false if not (get_year_from_timestamp($interview_arrival_date) >= parseInt $value)

                strokeInThePastValid(
                  $interview_arrival_date,
                  if $('#inputStrokeInThePast1').is(':checked') then "YES" else "NO",
                  $value,
                  $('#inputStrokeDateMonth').val()
                )
        'interview[glucoseLevelDay1]': { validators: {notEmpty: {}, numeric: {}} }
        'interview[glucoseLevelDay5to7]': {validators: {notEmpty: {}, numeric: {}} }
        'interview[afTreatedWithAnticoagulant]': { validators: {notEmpty: {}} }
    }).on 'success.form.bv', ($e) -> $e.preventDefault()
    .on 'error.form.bv', ($e) -> $e.preventDefault()
    .on 'error.field.bv', ($e, $data) => # zaznaczanie w sekcji że jest jakiś błąd
      $color = '#d11114'
      $el = $data.element.closest('li.list-group-item').find('.toggle').css('color', $color).find('.col-xs-10')
      unless $el.find('.err-info').length # jeśli nie ma ikonki
        $el.prepend('<i style="display: block; margin-right: 5px; margin-top: 3px; color: ' + $color + ';" class="pull-left fa fa-exclamation-circle err-info"></i>')
      $data.bv.disableSubmitButtons false
    .on 'success.field.bv', ($e, $data) ->
      fix_section_if_valid $data.element
      $data.bv.disableSubmitButtons false
    console.timeEnd 'validator setup'
  .onComplete ->
    # Musi być tu, bo jak jest w walidacji to powoduje rekurencję
    hospitalTakeChange = -> $('#someCreator').bootstrapValidator 'revalidateField', 'interview[strokeDate]'
    strokeOccurChange = -> $('#someCreator').bootstrapValidator 'revalidateField', 'interview[arrivalDate]'
    add_event 'keyup change', '#inputHospitalTake', hospitalTakeChange
    add_event 'keyup change', '#inputStrokeOccur',  strokeOccurChange
    $('#inputStrokeOccur').parent().datetimepicker($datepicker_settings).on 'dp.change', strokeOccurChange
    $('#inputHospitalTake').parent().datetimepicker($datepicker_settings).on 'dp.change', hospitalTakeChange

    #
    # uzupełnienie danych + rewalidacja formularza
    #
    $non_existing = []
    console.time "basic data"
    for $k, $v of $data
      # Te pola pomijamy
      continue if $k in ['id', 'measurements', 'version', 'interview']
      # ustawienie wartości
      $v = timestamp_to_date($v) if $k.indexOf('date') > -1 or $k.indexOf('Date') > -1 # timestamp to date
      $('#someCreator').find('input[name="'+$k+'"]').attr 'value', $v
    console.timeEnd "basic data"
    console.time "interview"
    # pola karty pacjenta
    for $ik, $iv of $data.interview
      # Te pola pomijamy
      continue if $ik in ['id',]
      # ustawienie wartości
      $iv = timestamp_to_date $iv if ($ik.indexOf('date') > -1 or $ik.indexOf('Date') > -1) and not isNaN parseInt $iv # timestamp to date
      # Textarea
      if $('#someCreator textarea[name="interview['+$ik+']"]').length > 0
        $('#someCreator textarea[name="interview['+$ik+']"]').text $iv
      # Formularz nie istnieje (tworzony po wykonaniu jakiegoś event handlera)
      else if $('#someCreator input[name^="interview['+$ik+'"]').length + $('#someCreator select[name^="interview['+$ik+'"]').length == 0
        $non_existing.push $ik
      # Tablica → multi select/checkboxy
      else if typeIsArray $iv
        $current = $('#someCreator select[name="interview['+$ik+'][]"]')
        # Select
        if $current.is 'select'
          for $sk, $sv of $iv
            break if isNaN parseInt($sk)
            # attr działa a prop nie O.o
            $current.find('option[value="'+$sv+'"]').attr 'selected', true
          $current.selectpicker 'refresh'
        # Checkboxy
        else
          Lazy($iv).each ($chk) ->
            $chk = $('#someCreator input[name="interview['+$ik+'][]"][value="'+$chk+'"]')
            $chk.icheck 'toggle' if not $chk.is ':checked'
      # Single select
      else if $('#someCreator select[name="interview['+$ik+']"]').length > 0
        $current = $('#someCreator select[name="interview['+$ik+']"]')
        $current.find('option[value="'+$iv+'"]').attr 'selected', true
        $current.selectpicker 'refresh'
      # Radio/checkbox button
      else if $('#someCreator input[name="interview['+$ik+']"]').attr('type') in ['radio', 'checkbox']
        $el = $('#someCreator input[name="interview['+$ik+']"][value="'+$iv+'"]')
        $el.icheck 'toggle' if not $el.is ':checked'
      else # formularz tekstowy
        $input = $('#someCreator').find('input[name="interview['+$ik+']"]')
        $input.attr 'value', $iv
    console.timeEnd "interview"

    console.time "events"
    # Wywoływanie odpowiednich event handlerów
    Lazy($event_handlers).each ($handler) ->
      return true if not $handler.event?

      # Zmiana pól tekstowych
      if $handler.event == 'change' or $handler.event == 'keyup' or ($handler.event == 'click' and $($handler.selector).prop('type') == 'text')
        $($handler.selector).trigger $handler.event
    console.timeEnd "events"
    console.time "added"
    # Uzupełnianie uprzednio nieistniejących formularzy
    while $non_existing? and $non_existing.length > 0
      $tmp = $non_existing.pop()
      $curr_form = $('#someCreator').find('input[name="interview['+$tmp+']"]')
      $curr_form.attr 'value', $data['interview'][$tmp]
      $('#someCreator').find('select[name="interview['+$tmp+']"]').selectpicker 'val', $data['interview'][$tmp] if $curr_form.length == 0
    console.timeEnd "added"

    # Dodanie eventa obsługującego zmianę numeru PESEL i aktualizującego datę urodzenia oraz płeć
    add_event 'keyup', '#inputPESEL', ($e) ->
      $identityNumber = $('#inputPESEL').val()
      if PESEL_validator($identityNumber).valid
        $identityNumber = $identityNumber.split('')
        # Data urodzenia
        $('#inputBirthDate').val(date_from_PESEL($identityNumber))
        # Płeć
        $('input[name="interview[sex]"][value="'+(if(parseInt($identityNumber[9]) % 2) then 'MALE' else 'FEMALE')+'"]').trigger 'click'
      $('#someCreator').bootstrapValidator 'revalidateField', 'birthDate'
      $('#someCreator').bootstrapValidator 'revalidateField', 'interview[sex]'

    # Jeśli nie ma nic w chorobie niedokrwiennej, CCS'a nie ma
    if $('input[name="interview[ischemicHeartDisease]"]:checked').length == 0
      $('#someCreator').bootstrapValidator 'enableFieldValidators', 'interview[ccsClass]', false
      $('#inputCcs').attr('disabled', true).closest('div.fluid-row').hide() # disabled aby nie podlegało serializacji + ukrycie
    # Jeśli nie ma nic w niewydolności serca, NYHA nie ma
    if $('input[name="interview[heartFailure]"]:checked').length == 0
      $('#someCreator').bootstrapValidator 'enableFieldValidators', 'interview[nyhaClass]', false
      $('#inputNyha').attr('disabled', true).closest('div.fluid-row').hide() # disabled aby nie podlegało serializacji + ukrycie
    # Jeśli nie ma nic w cukrzycy, poziomu glukozy nie ma
    if $('input[name="interview[diabetes]"]:checked').length == 0
      $('input[name="interview[glucoseLevelDay1]"], input[name="interview[glucoseLevelDay5to7]"]').attr('disabled', true).closest('div.fluid-row').hide()
    # Jeśli nie ma nic w migotaniu przedsionków, leczenia antykoagulantem nie ma
    if $('input[name="interview[atrialFibrillation]"]:checked').length == 0
      $('input[name="interview[afTreatedWithAnticoagulant]"]').attr('disabled', true).closest('div.fluid-row').hide()

    # Rewalidacja całego formularza
    $('#someCreator').bootstrapValidator('resetForm').bootstrapValidator 'validate'

    # Ręcznie chowamy ajax overlay'a
    $('#ajaxOverlay').fadeOut 100 if $('#ajaxOverlay').is ':visible'
    # init tooltipów
    $('input[title]').tooltip placement: 'left'
  #
  # Wysyłanie formularza
  #
  add_event 'click', '#someCreator button[type="submit"]', ->
    $form = $('#someCreator').serializeJSON parseNumbers: true
    # Konwersja daty w użytkowniku
    $form = Lazy($form).map(($v, $k) -> [$k, if $k == 'birthDate' then date_to_timestamp $v else $v]).toObject()
    # Konwersja dat w wywiadzie
    $form.interview = Lazy($form.interview).map(($v, $k) ->
      [$k, if ($k.indexOf('date') > -1 or $k.indexOf('Date') > -1) and $k != 'screeningTypeDate' then  date_to_timestamp $v else $v]
    ).toObject()
    # Wysłanie danych do serwera
    write_data 'put', 'patients/'+$uid, JSON.stringify $form
    # Powrót do poprzedniej strony
    $('a[href="'+$prev_tab+'"]').trigger 'click'

  # uzupełnianie GFR
  gfr = ($e) ->
    $(@).val ''
    $age = moment().diff $('#inputBirthDate').val(), 'years'
    $body_mass = parseFloat $('#inputBodyMass').val()
    $body_mass = 0.0 if isNaN $body_mass
    $kreatynina = parseFloat $('#inputKreatynina').val()
    $kreatynina = 0.0 if isNaN $kreatynina
    $val = 0
    # W zależności od jednostki kreatyniny ten wzór wygląda trochę inaczej
    switch $('select[name="interview[unitCreatinine]"]').val()
      when 'MG_PER_DL' then $val = (if $('#inputSexK').prop('checked') then 0.85 else 1.0) * (140 - $age) * $body_mass / (72 * $kreatynina)
      else $val = (if $('#inputSexK').prop('checked') then 1.04 else 1.23) * (140 - $age) * $body_mass / $kreatynina
    $(@).val if $val != 0 and isFinite $val then $val.toFixed(3) else ''
    $e.preventDefault() if not ($e.type == 'keypress' and $e.key == 'Tab') # Pozwalamy tabować
  add_event 'click keypress change mousedown contextmenu', '#inputGFR', gfr
  add_event 'keyup change', '#inputKreatynina', -> $('#inputGFR').trigger 'click'
  add_event 'change', 'select[name="interview[unitCreatinine]"]', -> $('#inputGFR, #inputGFRMDRD').trigger 'click'
  # uzupełnianie GFR MDRD
  gfrmdrd = ($e) ->
    $age = moment().diff $('#inputBirthDate').val(), 'years'
    $kreatynina = parseFloat $('#inputKreatynina').val()
    $kreatynina = 0.0 if isNaN $kreatynina
    $kreatynina /= 88.4 if $('select[name="interview[unitCreatinine]"]').val() == 'UMOL_PER_L'
    $val = 186.3 * Math.pow($kreatynina, -1.154) * Math.pow($age, -0.203) * (if $('#inputSexK').prop('checked') then 0.85 else 1.0)
    $(@).val if isFinite $val then $val.toFixed(3) else ''
    $e.preventDefault() if not ($e.type == 'keypress' and $e.key == 'Tab') # Pozwalamy tabować
  add_event 'click keypress change mousedown contextmenu', '#inputGFRMDRD', gfrmdrd
  add_event 'keyup change', '#inputKreatynina', -> $('#inputGFRMDRD').trigger 'click'

  #
  # Obsługa dynamicznie dodawanych/usuwanych pól
  #
  # pierwsze z pól
  add_event 'ifChecked', 'input[name="interview[symptomLesionLocation]"]', ->
    unless $(@).attr('id') == 'inputLocation5'
      $('#inputLocationText').closest('.fluid-row').remove()
      $('#someCreator').bootstrapValidator 'removeField', $('#inputLocationText').find('input')
  add_event 'ifChecked', '#inputLocation5', ->
    if $('#inputLocationText').length == 0
      $el = $($horizontal_form_row)
      $form = '<input type="text" class="form-control" id="inputLocationText" placeholder="inna lokalizacja" name="interview[otherLesionLocation]" required>'
      $el.find('.form-group').children('div').html $form
      $el.find('.form-group').children('label').html 'inna lokalizacja'
      $(@).closest('.fluid-row').after $el
      $('#someCreator').bootstrapValidator 'addField', $('#inputLocationText')
      $('#someCreator').bootstrapValidator 'revalidateField', $('#inputLocationText')

  # data wystąpienia udaru
  add_event 'ifChecked', '#inputStrokeInThePast1', ->
    $el = $($horizontal_form_row)
    $form = '<input type="text" class="form-control" id="inputStrokeInThePastYear" placeholder="Rok, w którym wystąpił udar" name="interview[pastStrokeYear]" required>'
    $el.find('.form-group').children('div').html $form
    $el.find('.form-group').children('label').html 'Rok, w którym wystąpił udar'
    $(@).closest('.fluid-row').after $el
    $('#someCreator').bootstrapValidator 'addField', $('#inputStrokeInThePastYear')
    $('#someCreator').bootstrapValidator 'revalidateField', $('#inputStrokeInThePastYear')
  add_event 'ifChecked', 'input[name="interview[strokeInThePast]"]', ->
    unless $(@).attr('id') == 'inputStrokeInThePast1'
      $('#inputStrokeInThePastYear').val('').trigger('keyup').closest('.fluid-row').remove()
      $('#someCreator').bootstrapValidator 'removeField', $('#inputStrokeInThePastYear').find('input')
      form_hidden @
  add_event 'keyup', '#inputStrokeInThePastYear', ->
    $curr_year = get_year_from_timestamp $interview_arrival_date
    # Sprawdzenie czy to nie jest aktualny rok (jeśli tak, dodanie select-a)
    if $('#inputStrokeDateMonth').length == 0 and ( $curr_year == parseInt($(@).val()) or $curr_year - 1 == parseInt($(@).val()) )
      $el = $($horizontal_form_row)
      $form = '<select name="interview[pastStrokeMonth]" id="inputStrokeDateMonth" class="form-control selectpicker" title="Miesiąc, w którym wystąpił udar" multiple data-max-options="1" required>
                <option value="1">Styczeń</option> <option value="2">Luty</option> <option value="3">Marzec</option> <option value="4">Kwiecień</option>
                <option value="5">Maj</option> <option value="6">Czerwiec</option> <option value="7">Lipiec</option> <option value="8">Sierpień</option>
                <option value="9">Wrzesień</option> <option value="10">Październik</option> <option value="11">Listopad</option> <option value="12">Grudzień</option>
              </select>'
      $el.find('label').html('Miesiąc, w którym wystąpił udar').attr 'for', 'inputStrokeDateMonth'
      $el.find('.form-group').children('div').addClass('selectContainer').html $form
      $(@).closest('.fluid-row').after $el
      # dodanie event handlera dla miesiąca i uruchomienie selectpickera
      $('#inputStrokeDateMonth').selectpicker()
      $('#someCreator').bootstrapValidator 'addField', $('#inputStrokeDateMonth')
      $('#someCreator').bootstrapValidator 'revalidateField', $('#inputStrokeDateMonth')
    # jeśli to nie jest ten/poprzedni rok → nie trzeba miesiąca
    unless ( $curr_year == parseInt($(@).val()) or $curr_year - 1 == parseInt($(@).val()) ) or $('#inputStrokeDateMonth').length == 0
      $('#someCreator').bootstrapValidator 'removeField', $('#inputStrokeDateMonth')
      $('#inputStrokeDateMonth').closest('.fluid-row').remove()
      $('#inputStrokeDateMonth').off 'change'
    # jeśli rok aktualny, zablokowanie późniejszych miesięcy
    else
      $val = parseInt $(@).val()
      $month = parseInt $('#inputStrokeDateMonth').val()
      $max_month = get_month_from_timestamp($interview_arrival_date) + 1
      # Blokowanie późniejszych miesięcy
      $('#inputStrokeDateMonth').find('option').each -> $(@).attr 'disabled', $(@).val() > $max_month and $curr_year == $val
      $('#inputStrokeDateMonth').selectpicker 'refresh'
      $('#inputStrokeDateMonth').on 'change', -> $('#someCreator').bootstrapValidator 'revalidateField', 'interview[pastStrokeYear]'

  # cukrzyca i powiązane
  add_event 'ifChecked', '#inputDiabetes1', ->
    $('input[name="interview[glucoseLevelDay1]"], input[name="interview[glucoseLevelDay5to7]"]').attr('disabled', false).closest('div.fluid-row').show()
    $('#someCreator').bootstrapValidator('enableFieldValidators', 'interview[glucoseLevelDay1]', true).bootstrapValidator 'revalidateField', 'interview[glucoseLevelDay1]'
    $('#someCreator').bootstrapValidator('enableFieldValidators', 'interview[glucoseLevelDay5to7]', true).bootstrapValidator 'revalidateField', 'interview[glucoseLevelDay5to7]'
  add_event 'ifChecked', '#inputDiabetes3, #inputDiabetes2', ->
    $('#inputDiabetesLevel2, #inputDiabetesLevel1').val '' if $(@).attr('id') == 'inputDiabetes3'
    $('input[name="interview[glucoseLevelDay1]"], input[name="interview[glucoseLevelDay5to7]"]').attr('disabled', true).closest('div.fluid-row').hide()
    form_hidden @
  add_event 'keyup', 'input[name="interview[totalCholesterol]"], input[name="interview[ldl]"], input[name="interview[hdl]"], input[name="interview[trg]"]', ->
    $('#inputZaburzenia3').icheck('toggle') if $('#inputZaburzenia3').prop 'checked'
  # Choroba niedokrwienna serca
  add_event 'ifChecked', '#inputCad1', ->
    $('#inputCcs').attr('disabled', false).closest('div.fluid-row').show() # wyłączenie disabled aby podlegało serializacji + pokazanie
    $('#someCreator').bootstrapValidator('enableFieldValidators', 'interview[ccsClass]', true).bootstrapValidator 'revalidateField', 'interview[ccsClass]'
  add_event 'ifChecked', '#inputCad2, #inputCad3', ->
    $('#someCreator').bootstrapValidator 'enableFieldValidators', 'interview[ccsClass]', false
    $('#inputCcs').attr('disabled', true).closest('div.fluid-row').hide() # disabled aby nie podlegało serializacji + ukrycie
    form_hidden @
  # Migotanie przedsionków/leczone antykoagulantem
  add_event 'ifChecked', '#inputMigotanie', ->
    $('input[name="interview[afTreatedWithAnticoagulant]"]').attr('disabled', false).closest('div.fluid-row').show()
    $('#someCreator').bootstrapValidator 'revalidateField', 'interview[afTreatedWithAnticoagulant]'
  add_event 'ifChecked', '#inputMigotanie2, #inputMigotanie3', ->
    $('input[name="interview[afTreatedWithAnticoagulant]"]').attr('disabled', true).closest('div.fluid-row').hide()
    form_hidden @
  # Palenie tytoniu
  add_event 'ifChecked', 'input[name="interview[cigarettes]"]', ->
    $exists = $('#inputPaczkoLata').length != 0
    if $(@).val() == 'ACTIVE_SMOKING' and not $exists
      $form = '<div class="col-xs-5">
                 <input type="text" class="form-control" id="inputPaczkoLata" placeholder="paczkolata" title="paczkolata" name="interview[cigarettesPacksPerYear]" required data-bv-numeric="true">
               </div>'
      $(@).closest('.form-group').append $form
      $('#inputPaczkoLata').tooltip placement: 'right'
      $('#someCreator').bootstrapValidator('addField', $('#inputPaczkoLata')).bootstrapValidator('revalidateField', 'interview[cigarettesPacksPerYear]')
    else if $(@).val() != 'ACTIVE_SMOKING' and $exists
      $('#someCreator').bootstrapValidator 'removeField', $('#inputPaczkoLata')
      $('#inputPaczkoLata').closest('div').remove()
  # Klasa NYHA
  add_event 'ifChecked ifUnchecked', '#inputNiewydolnosc', ($e) ->
    if $e.type == 'ifChecked'
      $('#inputNyha').attr('disabled', false).closest('div.fluid-row').show() # wyłączenie disabled aby podlegało serializacji + pokazanie
      $('#someCreator').bootstrapValidator 'enableFieldValidators', 'interview[nyhaClass]', $e.type == 'ifChecked'
      $('#someCreator').bootstrapValidator 'revalidateField', 'interview[nyhaClass]'
  add_event 'ifChecked', '#inputNiewydolnosc2, #inputNiewydolnosc3', ->
    $('#someCreator').bootstrapValidator 'enableFieldValidators', 'interview[nyhaClass]', false
    $('#someCreator').bootstrapValidator 'revalidateField', 'interview[nyhaClass]'
    $('#inputNyha').attr('disabled', true).closest('div.fluid-row').hide() # disabled aby nie podlegało serializacji + ukrycie
    form_hidden @

  # Handler dla wyboru leków
  drugs_handler = ($this, $e, $name, $id, $new_name, $id_prefix) ->
    add_form_after_checkbox 'input[name="interview['+$name+'][]"]', $id, 'interview['+$new_name+']', 'OTHER', 'inne leki'
    $val = $($this).val()
    # użyszkodnik wybrał "bez leków" lub "brak danych"
    if ($val == 'NONE' or $val == 'DATA_UNAVAILABLE') and $e.type == 'ifChecked'
      $($this).closest('.col-xs-5').find('input:checked:not([value="'+$val+'"])').icheck 'toggle'
      return
    # Niedostępne jest tylko dla leków przed udarem
    if $name == 'drugsBeforeStroke' and $e.type == 'ifChecked' and $val != 'DATA_UNAVAILABLE' and $val != 'NONE' and $('#'+$id_prefix+'14').is ':checked'
      # użyszkodnik wybrał coś innego niż "brak danych"
      $('#'+$id_prefix+'14').icheck 'toggle'
    # użyszkodnik wybrał coś innego niż "bez leków"
    $('#'+$id_prefix+'13').icheck 'toggle' if $e.type == 'ifChecked' and $val != 'DATA_UNAVAILABLE' and $val != 'NONE' and $('#'+$id_prefix+'13').is ':checked'
  # Przyjmowane leki przed incydentem udarowym
  add_event 'ifChecked ifUnchecked', 'input[name="interview[drugsBeforeStroke][]"]', ($e) ->
    drugs_handler @, $e, 'drugsBeforeStroke', 'inputLekiInne', 'otherDrugsBeforeStroke', 'inputLeki'
    fix_section_if_valid $(@)
  # Przyjmowane leki w czasie pobytu w szpitalu
  add_event 'ifChecked ifUnchecked', 'input[name="interview[drugsOnHospitalisation][]"]', ($e) ->
    drugs_handler @, $e, 'drugsOnHospitalisation', 'inputLekiSzpitalInne', 'otherDrugsOnHospitalisation', 'inputLekiSzpital'
    fix_section_if_valid $(@)
  # Zmodyfikowane leczenie przy wypisie ze szpitala
  add_event 'ifChecked ifUnchecked', 'input[name="interview[drugsOnDischarge][]"]', ($e) ->
    drugs_handler @, $e, 'drugsOnDischarge', 'inputLekiWypisInne', 'otherDrugsOnDischarge', 'inputLekiWypis'
    fix_section_if_valid $(@)

#
# Informacja o losach pacjenta/obserwacja półroczna/zgon
#
observation_page_handler = ($data) ->
  $('span#patient-name').html $data.firstName+' '+$data.surname
  $('#inputDateOfDeath, #inputApproximateDateOfDeath').closest('div.form-group').hide()
  # Śmierć pacjenta
  add_event 'ifChecked', 'input[name="interview[finalPatientsState]"]', ->
    $show = $(@).val() == 'DIED_IN_HOSPITAL' or $(@).val() == 'DIED_IN_6_MONTHS'
    $el = (if $(@).val() == 'DIED_IN_HOSPITAL' then $('#inputDateOfDeath') else $('#inputApproximateDateOfDeath')).closest('div.form-group')
    if $show
      $el.show()
      $('#observationForm').bootstrapValidator 'revalidateField', (if $(@).val() == 'DIED_IN_HOSPITAL' then 'interview[dateOfDeath]' else 'interview[approximateDateOfDeath]')
      # Ukrycie tego drugiego formularza
      (if $(@).val() == 'DIED_IN_HOSPITAL' then $('#inputApproximateDateOfDeath') else $('#inputDateOfDeath')).val('').closest('div.form-group').hide()
    else $('#inputDateOfDeath, #inputApproximateDateOfDeath').val('').closest('div.form-group').hide()
  # Zapis formularza
  add_event 'click', '#observationForm #submit-button', ->
# Zapis zmodyfikowanych danych
    $form = $('#observationForm').serializeJSON()
    $form['interview']['dateOfFinalStateEstablishment'] = moment().valueOf() # Data zapisania tego
    write_data 'put', 'patients/'+$data.id, JSON.stringify $form
    # Powrócenie do poprzeniej strony lub przejście do strony głównej (jeśli nie było z jakiegoś powodu poprzedniej)
    if $prev_tab != null then $('a[href="'+$prev_tab+'"]').trigger 'click' else $('li.login:first a').trigger 'click'

  # Data przybycia do szpitala / data zawału
  if $data.interview?
    $date_after = if $data['interview']['arrivalDate']? then $data['interview']['arrivalDate'] else (if $data['interview']['strokeDate']? then $data['interview']['strokeDate'] else null)
  else $date_after = null

  # Wykonanie asynchroniczne, aby wykonanie nastąpiło po wyświetleniu formularza (inaczej BootstrapValidator nic nie waliduje)
  Lazy([1]).async().each ->
    # Walidacja
    $('#observationForm').bootstrapValidator
      feedbackIcons: $feedbackIcons
      fields:
        'interview[finalPatientsState]':
          validators:
            notEmpty: {}
  # Przybliżona data zgonu jeśli ktoś umarł poza szpitalem
        'interview[approximateDateOfDeath]':
          validators:
            callback:
              callback: ($value) ->
                # Jeśli to nie jest data, pomijamy walidację jej
                return true if $value.match(/\d{1,2}\-\d{1,2}\-\d{1,2}/) == null

                # Data śmierci jest w przyszłości
                if moment($value).isAfter()
                  return valid: false, message: 'Wprowadzono datę z przyszłości'

                # Data śmierci jest przed datą przybycia do szpitala / datą zawału
                if $date_after != null and moment($value).isBefore $date_after
                  return valid: false, message: 'Data zgonu jest zbyt wczesna względem daty przyjęcia do szpitala'
                return true
        'interview[dateOfDeath]':
          validators:
            notEmpty: {}
            date: {format: 'YYYY-MM-DD'}
            callback:
              callback: ($value) ->
                # Jeśli to nie jest data, pomijamy walidację jej
                return true if $value.match(/\d{1,2}\-\d{1,2}\-\d{1,2}/) == null

                $timestamp = date_to_timestamp $value
                # Data śmierci jest w przyszłości
                if moment($value).isAfter()
                  return valid: false, message: 'Wprowadzono datę z przyszłości'

                # Data śmierci jest przed datą przybycia do szpitala / datą zawału
                if $date_after != null and moment($value).isBefore $date_after
                  return valid: false, message: 'Data zgonu jest zbyt wczesna względem daty przyjęcia do szpitala'
                return true
    .on 'success.field.bv', ($e, $data) ->
  # kasowanie klasy wskazującej na sukces
      $parent = $data.element.parents '.form-group'
      $parent.removeClass 'has-success'
    .on 'success.form.bv', ($e) ->
      $e.preventDefault()
      $('#observationForm').find('#submit-button').prop 'disabled', false
    $('#observationForm').find('#submit-button').prop 'disabled', false

    # Wypełnienie formularza
    if $data.interview?
      $('input[name="interview[finalPatientsState]"][value="'+$data.interview.finalPatientsState+'"]').icheck 'toggle'
      $('#inputFinalStateNote').attr 'value', $data.interview.finalStateNote
      # Jeśli zmiarł - wpisanie daty śmierci
      if $data.interview.finalPatientsState == 'DIED_IN_HOSPITAL'
        $('#inputDateOfDeath').closest('div.form-group').show()
        $('#inputDateOfDeath').attr 'value', timestamp_to_date $data.interview.dateOfDeath if $data.interview.dateOfDeath? # jeśli jest wpisana data śmierci
      else if $data.interview.finalPatientsState == 'DIED_IN_6_MONTHS'
        $('#inputApproximateDateOfDeath').closest('div.form-group').show()
        # jeśli jest wpisana data śmierci
        $('#inputApproximateDateOfDeath').attr 'value', $data.interview.approximateDateOfDeath if $data.interview.approximateDateOfDeath?

    # Rewalidacja całego formularza
    $('#observationForm').bootstrapValidator('resetForm').bootstrapValidator 'validate'

#
# Ustawienie kodowania utf8
#
$.base64.utf8encode = true

# Ładowane/uruchamiane na starcie skryptu
$ ->
  requirejs(['workers/common'])

  $('body').popover
    placement: 'left'
    selector: '.examination-notes'
    html : true
    trigger: 'hover'
    content: -> $(@).html()

  # Lokalizacja dla dataTables
  try $datatables_lang = read_json '/ipmed/media/js/vendor/dataTables.json'
  catch
    null

  # Sprawdzanie auto-wylogowania co 1s
  comet [auto_logout], null, 1

  # Po każdym kliknięciu update ostatniej aktywności
  $(document).on 'click keypress', ($event) ->
    if $event.hasOwnProperty('originalEvent') and not $logout_info
        $last_activity = moment().unix()

  $('a.navbar-brand').click ($e) ->
    $e.preventDefault()
    bootbox.alert '<h3 class="heading text-center">Projekt IPMed - Informacje</h3>
      <h4>Aplikacja internetowa stworzona w technologiach:</h4>
      <ul>
        <li>Java EE/Spring</li>
        <li>CoffeScript/jQuery</li>
        <li>HTML 5/Bootstrap</li>
        <li>Perl/.bat do ułatwienia startu serwera</li>
      </ul>
      <h4>Trochę statystyk:</h4>
      <ul>
        <li>Ilość commitów wg. GIT-a: 39</li>
        <li>CoffeScript: ~1,5k LoC / 74 kB</li>
        <li>JavaScript: ~1,9k LoC / 76 kB</li>
        <li>HTML: ~1,5k LoC / 70 kB</li>
        <li>JEE/Spring: ~100 LoC / 4 kB ;)</li>
        <li>Kod obsługi ankiety: 420 LoC CoffeScript (27%) + 1270 LoC HTML (85%)</li>
		    <li>Po 4h działania: ~460 requestów/13,9 MB przy ~250 pomiarach</li>
      </ul>
      <p>Testowane w przeglądarkach: Mozilla Firefox 35 / Google Chrome 39 / kIEpski 11 (Windows 8.1 Pro)</p>
      <p>Minimalna szerokość ekranu: 768 px</p>'

  # Walidacja logowania
  $('#login-page').bootstrapValidator
    feedbackIcons: $feedbackIcons
    fields:
      login:
        validators:
          notEmpty: {message: 'Login nie może być pusty'}
      passwd:
        validators:
          notEmpty: {message: 'Hasło nie może być puste'}
          stringLength: {min: 3, message: 'Hasło nie może być krótsze niż 3 znaki'}
  # logowanie
  .on 'success.form.bv', ($e) =>
    $e.preventDefault()
    $('#ajaxOverlay').fadeIn 100

    # Trochę po chamsku, ale działa - sprawdzenie server-side czy da się zalogować
    $can_login = write_with_status 'POST', 'trylogin', JSON.stringify [$('#login').val(), $('#passwd').val()]
    # Jeśli nie można się zalogować z tymi danymi
    if $can_login.status != 204
      $username = null
      show_login_error($can_login.status)
      return
    # Można się zalogować z tymi danymi - idziemy dalej
    # Dane autoryzacyjne
    $other_user_logout = false
    $auth_data = $.base64.encode $('#login').val() + ":" + $('#passwd').val()
    $.ajaxSetup headers: "Authorization": "Basic " + $auth_data
    $username = read_with_status 'support/myname'
    if $username.status != 200
      $auth_data = ''
      $.ajaxSetup headers: "Authorization": ''
      show_login_error($username.status)
      $username = null
      return

    $('#login, #passwd').val('')

    $('#username').html $username = $username.text
    # Ładowanie ekranu dostępnego po zalogowaniu
    $('li.login:first a').trigger 'click' # załadowanie 1. strony
    $($e.target).closest('div.row').hide().next().show() # ukrycie logowania, pokazanie treści po zalogowaniu
    $('li.login').show() # pokazanie menu
    # Inicjalizacja pseudo-cometa
    comet [measurements_updater, examinations_updater], $auth_data, $updaters_refresh_after
  .on 'success.field.bv', ($e, $data) ->
    # kasowanie klasy wskazującej na sukces
    $parent = $data.element.parents '.form-group'
    $parent.removeClass 'has-success'

  #
  # Wyjście z aplikacji (zamknięcie okna)
  #
  $(window).unload -> logout

  #
  # Wylogowanie
  #
  $('a[href="#logout"]').bind 'click', logout

  #
  # Kliknięcie linka z menu
  #
  $(document). on 'click', 'li.login a, a.move-to', ($event) ->
    $event.preventDefault()
    $href = $(@).attr 'href'
    return if $href == '#logout' or $(@).hasClass 'dropdown-toggle'

    # Pokazanie overlaya jeśli nie jest jeszcze widoczny
    show_overlay()

    # Czyszczenie uprzednich event handlerów
    $tmps = []
    while($event_handlers.length > 0)
      $tmp = $event_handlers.pop()
      if not $tmp.page? # jeśli nie ma wpisanej strony - to jest form
        $(document).off $tmp.event, $tmp.selector
      else $tmps.push $tmp
    $event_handlers = $tmps

    # Link kierujący do poprzedniej strony
    add_event 'click', 'a[href="#go-back"]', -> $('a[href="'+$prev_tab+'"]').trigger 'click'

    # Adres strony do której się odwołujemy
    $uri = route_uri $href
    ajax_request $uri, null, ($data) =>
      console.time "ajax handler"

      # Formularz → operujemy bezpośrednio
      if $href.indexOf('/') != -1
        $('#page-logged-in-content').html $data.html
      else $($href+'-div').html $data.html

#      # Init iCheck'a
#      $('input').icheck('destroy').icheck
#        checkboxClass: "icheckbox_minimal"
#        radioClass: "iradio_minimal"
      # Inicjalizacja selectpickera
      $('.selectpicker').selectpicker()

      # Ostatni czas pobierania danych dla tej strony
      $since[$href] = moment().valueOf() if $since[$href]?
      # Handlery requestów dla określonych podstron
      $new_measurements_opened = false
      switch $href
        # pomiary
        when '#new-measurements', '#all-measurements'
          $data = fix_measurements Lazy $data.data
          # jeśli to jest nowy pomiar - nie ma ustawionego pacjenta
          if $(@).attr('href') == '#new-measurements'
            $data = $data.filter ($v) -> not $v.patient?
            $new_measurements_opened = true
          measurements_page_handler $data, $href
        # badania
        when '#to-fill', '#all-examinations'
          $data = Lazy(map_examinations $data.data).filter ($v) -> typeof $v is "object"
          # jeśli to lista do uzupełnienia, dodatkowe filtrowanie (zostają te przy których są problemy)
          $data = $data.filter(($v) -> $v.to_complete) if $(@).attr('href') == '#to-fill'
          examinations_page_handler $data, $href
        when '#phones'
          examinations_page_handler Lazy(phones_filter $data.data), $href
      # ankieta (nie może być w switchu, bo ma ID)
      if $href.lastIndexOf('#patients/ankieta') == 0
        interview_page_handler $data.data
      # obserwacja półroczna
      else if $(@).attr('href').lastIndexOf('#patients/observation') == 0
        observation_page_handler $data.data

      # Ukrywanie/pokazywanie odpowiedniej strony
      if $href.indexOf('/') == -1
        $('#subpages-content > div:not('+$href+'-div):not('+$href+'-div-tmp), #page-logged-in-content').empty().hide()
        $($href+'-div').show()
      else
        $('#page-logged-in-content').show()
        $('#subpages-content > div').empty().hide()

      $('.login').removeClass 'active'
      $(@).parent().addClass 'active'
      $prev_tab = $curr_tab
      $curr_tab = $href

      #
      # Reboot pluginów
      #
      # Inicjalizacja date/time pickera
      $('div.date').datetimepicker($datepicker_settings).on 'dp.change dp.show', -> # refresh walidacji po zmianie wartości
        $(@).closest('form').bootstrapValidator 'revalidateField', $(@).find('input').attr 'name'
      # Try/catch bo pole może nie być walidowane
      $(document).on 'change', '.selectpicker', ->
        try $(@).closest('form').bootstrapValidator 'revalidateField', $(@).attr 'name'
        catch
          null
      $('table:not(.dataTable):not(#do-uzupelnienia):visible').DataTable
        paging: false
        autoWidth: false
        language: $datatables_lang
        order: [0, 'desc']
      # Init iCheck'a
      $('input').icheck('destroy').icheck
        checkboxClass: "icheckbox_minimal"
        radioClass: "iradio_minimal"

      #
      # Czyszczenie walidacji i formularzy
      #
      $('form').data('bootstrapValidator').resetForm()
      $('form').trigger "reset"

      console.timeEnd "ajax handler"
      # Ukrywanie jeśli nie jesteśmy na stronie ankiety (gdzie jest to ukrywane ręcznie)
      $('#ajaxOverlay').fadeOut 100 if not $curr_tab? or $curr_tab.lastIndexOf('#patients/ankieta') != 0


