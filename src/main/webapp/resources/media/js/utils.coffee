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
