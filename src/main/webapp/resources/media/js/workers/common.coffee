#
# Funkcje współdzielone przez skrypty (wokery, przeglądarkowe etc.)
#

#
# Konwersja daty jako string na timestamp
#
date_to_timestamp = ($date, $separator = '-') ->
  return '' if $date == ''
  moment.tz($date, $timezone_used).valueOf()

#
# Konwersja daty i czasu jako string na timestamp
#
datetime_to_timestamp = ($date, $separator = '-') ->
  return '' if $date == ''
  moment.tz($date, $timezone_used).valueOf()

#
# Konwersja timestamp → prawidłowy format daty
#
timestamp_to_date = ($date) -> moment.tz($date, $timezone_used).format("YYYY-MM-DD")

#
# Konwersja timestamp → prawidłowy format daty i czasu
#
timestamp_to_datetime = ($date) -> moment.tz($date, $timezone_used).format("YYYY-MM-DD HH:mm")

#
# Pełen rok z timestampu, z uwzględnieniem strefy czasowej
#
get_year_from_timestamp = ($timestamp) -> moment.tz($timestamp, $timezone_used).year()

#
# Pełen rok z timestampu, z uwzględnieniem strefy czasowej
#
get_month_from_timestamp = ($timestamp) -> moment.tz($timestamp, $timezone_used).month()


# Stringi pomocnicze
$err_sign = '<i style="display: block; margin-right: 3px; margin-top: 1px;" class="pull-left fa fa-warning err-info"></i>'
text_to_err = ($val) -> '<p class="text-danger error-text">'+$err_sign+$val+'</p>'
text_to_warn = ($val) -> '<p class="text-warning error-text">'+$err_sign+$val+'</p>'
# Tekst jeśli brakuje jedynie informacji o przeżyciu i należy ją uzupełnić później
$final_patient_state_later = '<p class="text-success" style="display: inline-block; margin-bottom: 0;">Informacja o przeżyciu do uzupełnienia później</p>'
# Tekst jeśli wszystko jest OK
$everything_ok = '<p class="text-success" style="display: inline-block; margin-bottom: 0;">Dane kompletne</p>'
# Tekst jeśli wszystko jest OK
$measurement_ok = '<p class="text-success" style="display: inline-block; margin-bottom: 0;">OK</p>'

# Odczytywanie daty urodzenia z PESELu
date_from_PESEL = ($tmp) ->
  $year = 1900 + parseInt($tmp[0])*10 + parseInt($tmp[1])
  $year += Math.floor(parseInt($tmp[2]) / 2)*100 if parseInt($tmp[2]) >= 2 or parseInt($tmp[2]) <= 7
  $year -= 100 if parseInt($tmp[2]) >= 8
  # miesiąc i dzień urodzenia
  $month = (parseInt($tmp[2]) % 2)*10+parseInt($tmp[3])
  $month = '0'+$month.toString() if $month < 10
  $day = parseInt($tmp[4])*10+parseInt($tmp[5])
  $day = '0'+$day.toString() if $day < 10
  # Zwrócenie daty
  $date = $year.toString()+'-'+$month+'-'+$day
  # Jeśli data jest nieprawidłowa, zwracamy false
  return false if not moment($date, 'YYYY-MM-DD').isValid()

  $date

# Walidacja PESEL'u
PESEL_validator = ($value) ->
  # Sprawdzenie długości
  if not $value? or $value == ''
    return valid: false, message: 'Pole jest obowiązkowe'
  if $value.length < 11
    return valid: false, message: 'Wprowadzony numer PESEL jest zbyt krótki'
  if $value.length > 11
    return valid: false, message: 'Wartość niepoprawna'
  if not Lazy($value).every((v) -> v >= '0' and v <= '9')
    return valid: false, message: 'Wartość niepoprawna'

  # Podstawowe sprawdzenie dat
  $tmp = $value.split('')
  $date = date_from_PESEL $tmp
  if not $date
    return valid: false, message: 'Błędna data urodzenia'

  # Sprawdzanie sumy
  $weights = [1,3,7,9,1,3,7,9,1,3,1]
  $sum = 0
  for $n in [0..10]
    $sum += $tmp[$n]*$weights[$n]
  $checksum_ok = $sum % 10 == 0 # jeśli jest 0 tzn, że jest OK
  if not $checksum_ok
    return valid: false, message: 'Błędna suma kontrolna'

  # Sprawdzenie, czy data urodzenia nie jest z przyszłości
  if not moment.tz($date, $timezone_used).isBefore()
    return valid: false, message: 'Data urodzenia z przyszłości'

  return valid: true

# Walidacja daty urodzenia
birthDate_validator = ($value, $identityNumber) ->
  if not $value?
    return valid: false, message: 'Pole jest obowiązkowe'
  $date = moment.tz($value, $timezone_used)
  if not $date.isBefore()
    return valid: false, message: 'Wprowadzono datę z przyszłości'
  if PESEL_validator($identityNumber).valid
    if not $date.isSame(moment.tz(date_from_PESEL($identityNumber.split('')), $timezone_used))
      return valid: false, message: 'Data urodzenia nie zgadza się z numerem PESEL'

  return valid: true

# Walidacja płci względem PESEL
sex_validator = ($value, $identityNumber) ->
  if PESEL_validator($identityNumber).valid
    $correctSex = if (parseInt($identityNumber.split('')[9]) % 2 == 1) then 'MALE' else 'FEMALE'
    return $correctSex == $value
  return true

#
# Uproszczony routing
#
route_uri = ($href) ->
  switch $href
    when '#new-measurements', '#all-measurements' then return 'measurements/webapi/measurements'
    when '#to-fill', '#all-examinations', '#phones' then return 'patients/webapi/examinations'
  $href.substr(1)

# Sprawdzanie statusu odpowiedzi na potrzeby fetch.js
check_status = (resp) ->
  if 200 <= resp.status < 300
    return resp
  else
    error = new Error(resp.statusText)
    error.response = resp
    throw error

# Liczenie daty przyjęcia do szpitala
arrivalDate = ($v) ->
  # data przyjęcia wg. ankiety
  if $v.interview? and $v.interview.arrivalDate?
    $tmp = parseInt $v.interview.arrivalDate
    return $tmp if not isNaN $tmp
  # pierwszy pomiar
  else
    # nie ma pomiarów
    return moment().valueOf() if not $v.measurements? or $v.measurements.length == 0

    $tmp = Lazy($v.measurements).filter(($v) -> typeof $v is "object").sortBy('actualDate').first()
    return moment().valueOf() if not $tmp?
    # Czas pomiaru
    $tmp = parseInt $tmp.actualDate
    return $tmp if not isNaN $tmp
  return moment().valueOf()

# Sprawdzenie zawału w przeszłości
strokeInThePastValid = ($arrivalDate, $strokeInThePast, $pastStrokeYear, $pastStrokeMonth) ->
  if $strokeInThePast == 'YES'
    # Nie ma wpisanego roku albo rok jest z przyszłości
    $year = parseInt $pastStrokeYear
    $curr_year = get_year_from_timestamp $arrivalDate
    return false if not $pastStrokeYear? or $pastStrokeYear == '' or $year > $curr_year
    # Ten/poprzedni rok - wymagany miesiąc
    $stroke_date = moment
      year: $year
      month: 0
      day: 1
    if $year >= $curr_year - 1
      $pastStrokeMonth = '1' if not $pastStrokeMonth?
      return false if $pastStrokeMonth < 1 or $pastStrokeMonth > 12

      $stroke_date = moment
        year: $year
        month: parseInt($pastStrokeMonth) - 1
        day: 1
    return $stroke_date.valueOf() <= $arrivalDate
  true

# Szczegółowa walidacja poszczególnych części ankiety (używane przy mapowaniu)
class StrictValidation
  constructor: (@interview) -> null

  # Sprawdzenie poprawności leków
  drugsValid = ($chosen, $other) ->
    return false if not $chosen? or $chosen.length == 0 # są jakieś leki
    return false if 'OTHER' in $chosen and not $other? # inne prawidłowo wypełnione
    true

  # Setter, głównie użyteczny dla unit testów
  setInterview: ($interview) -> @interview = $interview

  firstMeasurement: ->
    null

# Sprawdzenie poprawności 3. sekcji ankiety ('wywiad')
  thirdSection: ($arrivalDate) ->
    return false if not @interview?
    # Zawał w przeszłości
    return false if not @interview.strokeInThePast?
    return false if not strokeInThePastValid $arrivalDate, @interview['strokeInThePast'], @interview['pastStrokeYear'], @interview['pastStrokeMonth']
    # Pacjent ma cukrzycę, sprawdzenie, czy jest wpisany poziom glukozy
    return false if @interview['diabetes'] == 'YES' and not (@interview['glucoseLevelDay1']? and @interview['glucoseLevelDay5to7']?)
    # Pacjent ma chorobę niedokrwienną serca - wymagana klasa CCS
    return false if @interview['ischemicHeartDisease'] == 'YES' and not @interview['ccsClass']?
    # Migotanie przedsionków - wymagane leczenie antykoagulantem
    return false if @interview['atrialFibrillation'] == 'YES' and not @interview['afTreatedWithAnticoagulant']?
    # Pali czynnie - wymagane paczko lata
    return false if @interview['cigarettes'] == 'ACTIVE_SMOKING' and not @interview['cigarettesPacksPerYear']?
    # Niewydolność serca - wymagana klasa NYHA
    return false if @interview['heartFailure'] == 'YES' and not @interview['nyhaClass']?
    true

# Sprawdzenie poprawności 5. sekcji ankiety ('leczenie szpitalne')
  fifthSection: -> drugsValid @interview['drugsOnHospitalisation'], @interview['otherDrugsOnHospitalisation']

# Sprawdzenie poprawności 6. sekcji ankiety ('Wypis')
  sixthSection: -> drugsValid @interview['drugsOnDischarge'], @interview['otherDrugsOnDischarge']

#
# Dodawanie uwag do osób ('do uzupełnienia' / 'telefony' / 'wszystkie badania')
#
map_examinations = ($data) ->
  $data.map ($v) ->
    $v.arrivalDate = arrivalDate $v

    # Lista uwag dla określonej osoby
    $uwagi = []
    $notes = [] # powinno być na żółto
    $to_fill_later = 'ankieta do uzupełnienia później'
    $should_be_filled_later = false
    # Data pierwszego pomiaru
    $date = Lazy($v.measurements).sortBy('actualDate').first()
    $date = if $date? then $date.actualDate else ''
    # Pomiary
    if not $v.interview? or $v.interview.finalPatientsState != 'DIED_IN_HOSPITAL'
      $problem = false
      # Pierwszy pomiar
      if not $v.measurements?
        $uwagi.push 'nie przypisano pomiarów'
        $problem = true
      else if $v.arrivalDate + moment.duration(2, 'days').asMilliseconds() < parseInt($date) or $v.arrivalDate > parseInt $date
        $uwagi.push 'pierwszy pomiar wykonano w złym czasie'
        $problem = true

      # Drugi pomiar
      $second_ok = false
      if $v.measurements?
        $second_start = $v.arrivalDate + moment.duration(4, 'days').asMilliseconds()
        $second_end   = $v.arrivalDate + moment.duration(8, 'days').asMilliseconds()
        $second_ok = Lazy($v.measurements).reduce ($old, $m) ->
          $tmp = parseInt $m.actualDate
          return ($tmp >= $second_start and $tmp <= $second_end) or $old
        , false
      # jeśli 2. pomiar był w złym czasie
      if not $second_ok and $v.measurements? and $v.measurements.length >= 2
        $uwagi.push 'drugi pomiar wykonano w złym czasie'
        $problem = true
      else if not $second_ok and $v.arrivalDate + moment.duration(4, 'days').asMilliseconds() < moment().valueOf()
        $uwagi.push 'brak drugiego pomiaru'
        $problem = true
      # Jeśli nie ma ww. problemów ale nie ma 2 pomiarów
      if not $problem and (not $v.measurements? or $v.measurements.length < 2)
        $notes.push 'pomiar do uzupełnienia później'

    # Ankieta
    $interview_valid = $v.interview?
    # Czas jaki minął od czasu przyjęcia jako float
    $time_since_arrival = moment.duration(moment().valueOf() - $v.arrivalDate, 'ms').asDays()
    # Sprawdzenie, czy pacjent zmarł w szpitalu
    $died_in_hospital = $v.interview? and $v.interview.finalPatientsState == 'DIED_IN_HOSPITAL'
    # Sprawdzanie określonych pól z wywiadu
    check_interview = ($required) -> Lazy($required).reduce (($old, $el) -> $old and $v.interview? and $v['interview'][$el]? and $v['interview'][$el] != ''), true
    #
    # Do wypełnienia przy przyjęciu
    #
    if $interview_valid
      $required_user = ['surname', 'firstName', 'identityNumber', 'birthDate', 'doctor',]
      $required_interview = ['sex', 'weight', 'weightAccuracy', 'height', 'arrivalDate', 'strokeDate', 'phoneNumber', 'education', 'employment',]
      $interview_valid = Lazy($required_user).reduce((($old, $el) -> $old and $v[$el]? and $v[$el] != ''), true) and check_interview($required_interview) and PESEL_validator($v.identityNumber).valid and birthDate_validator($v.birthDate, $v.identityNumber).valid and sex_validator($v.interview.sex, $v.identityNumber)
    #
    # Do wypełnienia pierwszego dnia
    #
    $required_interview = ['rankinPoints', 'nihssPoints', 'symptomLesionLocation', 'screeningTypeDate', 'strokeType', 'screeningLesionLocation', 'transcranialUltrasonographyResult', 'headArteriesUltrasonographyResult',]
    $tmp = check_interview $required_interview
    if $interview_valid and not $tmp
      if $time_since_arrival >= 1 or $died_in_hospital
        $interview_valid = $tmp
      else if not $should_be_filled_later
        $should_be_filled_later = true

    #
    # Do wypełnienia w ciągu tygodnia - wywiad / 3. sekcja ankiety i dalsze z wyjątkiem ostatniej
    #
    $required_interview = ['strokeInThePast', 'hypertension', 'kidneysDiseases', 'diabetes', 'ischemicHeartDisease', 'lipidsDisorders', 'atrialFibrillation', 'cigarettes',
      'neckArteriesDiseases', 'heartFailure', 'veinsThrombosis', 'hormoneTherapy', 'familyDiseasesStroke', 'familyDiseasesHeartFailure', 'familyDiseasesDiabetes',
      'familyDiseasesIschemicHeart', 'familyDiseasesHypertension', 'drugsBeforeStroke', 'drugsOnHospitalisation',]
    $tmp = check_interview $required_interview
    # Dokładniejsza walidacja
    $validator = new StrictValidation $v.interview
    $tmp = $tmp and $validator.thirdSection($v.arrivalDate) and $validator.fifthSection()
    if $interview_valid and not $tmp
      if $time_since_arrival >= 7 or $died_in_hospital
        $interview_valid = $tmp
      else if not $should_be_filled_later
        $should_be_filled_later = true

    $required_interview = ['drugsOnDischarge']
    $tmp = check_interview($required_interview) and $validator.sixthSection()
    if $interview_valid and not $tmp
      if $time_since_arrival >= 7 and not $died_in_hospital
        $interview_valid = $tmp
      else if not $should_be_filled_later and not $died_in_hospital
        $should_be_filled_later = true

    # Dodanie uwagi
    if $should_be_filled_later
      $notes.push $to_fill_later
    else if not $interview_valid
      $uwagi.push 'niepełna ankieta'

    # Sprawdzenie informacji o stanie końcowym
    $is_half_year = moment.duration(moment().valueOf() - $v.arrivalDate, 'ms').asMonths() >= 6 # Minęł pół roku od przyjęcia
    $state_valid = true
    # Sprawdzenie dla śmierci w szpitalu (nieprawidłowo, jeśli nie jest wpisana/wpisana błędnie data śmierci)
    if $died_in_hospital
      if not $v.interview.dateOfDeath?
        $state_valid = false
      else
        $state_valid = not moment($v.interview.dateOfDeath).isBefore($v.arrivalDate) and not moment($v.interview.dateOfDeath).isAfter(moment())
    # Jeśli po prostu minęło pół roku od przyjęcia
    else if $is_half_year
      # Nie ma w ogóle ankiety lub nie ma stanu
      if not $v.interview? or not $v.interview.finalPatientsState?
        $state_valid = false
      # Zmarł w ciągu 6 miesięcy - data
      else if $v.interview? and $v.interview.finalPatientsState == 'DIED_IN_6_MONTHS' and $v.interview.approximateDateOfDeath? and $v.interview.approximateDateOfDeath.match(/\d{1,2}\-\d{1,2}\-\d{1,2}/) != null
        $state_valid = not moment($v.interview.approximateDateOfDeath).isBefore($v.arrivalDate) and not moment($v.interview.approximateDateOfDeath).isAfter(moment())
    # Jeśli pacjent zmarł w szpitalu/minęło pół roku
    $v.qualifiesForPhone = false
    if ($died_in_hospital or $is_half_year) and not $state_valid
      $uwagi.push 'brak informacji o przeżyciu'
      $v.qualifiesForPhone = true
    # Sklejenie całości uwag do kupy
    $v.notes = Lazy($uwagi).reduce (($uwagi, $curr) -> $uwagi += text_to_err $curr), ''
    $v.notes += Lazy($notes).reduce (($notes, $curr) -> $notes += text_to_warn $curr), ''

    # Nie ma problemów
    $v.to_complete = true
    if $uwagi.length == 0 and $notes.length == 0
      $v.to_complete = false
      if not $v.interview.finalPatientState?
        $v.notes = $final_patient_state_later
      else
        $v.notes = $everything_ok

    return $v

# Fix pomiarów jeśli jest wysłane tylko ID
fix_measurements = ($measurements) ->
  $patients = []
  $measurements.sortBy(($v) -> typeof $v != 'object').map ($v) ->
    # jeśli to normalnie wpisany user, zapisanie na później
    if typeof $v is 'object' and $v.patient?
      $patients.push $v.patient
    else if typeof $v != 'object' # jeśli to tylko ID pomiaru - podmiana
      Lazy($patients).each ($user) ->
        $tmp = Lazy($user.measurements).find ($m) -> $m.id == $v
        # Czy znaleziono użytkownika?
        if $tmp?
          $v = $tmp
          $v.patient = $user
          return false
    $v
