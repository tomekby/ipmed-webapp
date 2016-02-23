
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
