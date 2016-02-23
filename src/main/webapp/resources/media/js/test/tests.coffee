# Używana strefa czasowa
$timezone_used = 'Europe/Warsaw'

# Sprawdzenie poprawności ankiety przy mapowaniu pacjentów
QUnit.module "Ankieta"
QUnit.test "ankieta - wywiad/3. sekcja", ($assert) ->
  $record =
    strokeInThePast: 'YES'
    pastStrokeYear: new Date().getFullYear()
    pastStrokeMonth: 1
  $arrivalDate = moment({month: 0, day: 1}).valueOf()
  $validator = new StrictValidation $record

  # Obie daty tego samego dnia
  $assert.ok $validator.thirdSection($arrivalDate), "Ten sam dzień"
  # Zawał nastąpił rok przed przyjęciem
  $record.pastStrokeYear = new Date().getFullYear() - 1
  $validator.setInterview $record
  $assert.ok $validator.thirdSection($arrivalDate), "Zawał rok przed przyjęciem"
  # Zawał nastąpił miesiąc przed przyjęciem
  $record.pastStrokeYear = new Date().getFullYear()
  $arrivalDate = moment({month: 1, day: 1}).valueOf()
  $validator.setInterview $record
  $assert.ok $validator.thirdSection($arrivalDate), "Zawał miesiąc przed przyjęciem"
  # Zawał nastąpił miesiąc po przyjęciu
  $record.pastStrokeMonth = 3
  $validator.setInterview $record
  $assert.notOk $validator.thirdSection($arrivalDate), "Zawał miesiąc po przyjęciu"
  # Zawał rok po przyjęciu
  $arrivalDate = moment({year: $record.pastStrokeYear - 1, month: 1, day: 1}).valueOf()
  $validator.setInterview $record
  $assert.notOk $validator.thirdSection($arrivalDate), "Zawał rok po przyjęciu"
  # Nie było wcześniej zawału
  $record.strokeInThePast = 'NO'
  $validator.setInterview $record
  $assert.ok $validator.thirdSection($arrivalDate), "Nie było wcześniejszego zawału"
  # Nie ma info o tym czy był wcześniej zawał
  delete $record.strokeInThePast
  $validator.setInterview $record
  $assert.notOk $validator.thirdSection($arrivalDate), "Brak informacji o zawale"

  # Pozostałe opcje
  # Cukrzyca - brak
  $record =
    strokeInThePast: 'NO'
    diabetes: 'NO'
  $validator.setInterview $record
  $assert.ok $validator.thirdSection($arrivalDate), "Brak cukrzycy"
  # Cukrzyca - brak pomiarów glukozy
  $record.diabetes = 'YES'
  $validator.setInterview $record
  $assert.notOk $validator.thirdSection($arrivalDate), "Brak pomiarów glukozy"
  # Cukrzyca - brak 1. pomiaru glukozy
  $record.glucoseLevelDay5to7 = 12
  $validator.setInterview $record
  $assert.notOk $validator.thirdSection($arrivalDate), "Brak 1. pomiaru glukozy"
  # Cukrzyca - wszystko ok
  $record.glucoseLevelDay1 = 12
  $validator.setInterview $record
  $assert.ok $validator.thirdSection($arrivalDate), "Cukrzyca - wszystko jest"
  # Cukrzyca - brak 2. pomiaru glukozy
  delete $record.glucoseLevelDay5to7
  $validator.setInterview $record
  $assert.notOk $validator.thirdSection($arrivalDate), "Brak 2. pomiaru glukozy"
  # Ccs - nie
  $record =
    strokeInThePast: 'NO'
    ischemicHeartDisease: 'NO'
  $validator.setInterview $record
  $assert.ok $validator.thirdSection($arrivalDate), "CCS - nie"
  # Ccs - tak, brak klasy
  $record.ischemicHeartDisease = 'YES'
  $validator.setInterview $record
  $assert.notOk $validator.thirdSection($arrivalDate), "CCS - brak klasy"
  # CCS - wszystko jest
  $record.ccsClass = 'I'
  $validator.setInterview $record
  $assert.ok $validator.thirdSection($arrivalDate), "CCS - wszystko jest"

# 5/6 sekcja ankiety jest testowana tak samo więc nie ma co się powtarzać
QUnit.test "ankieta - leczenie szpitalne/5. sekcja", ($assert) ->
  $record =
    drugsOnHospitalisation: null
    otherDrugsOnHospitalisation: null
  $validator = new StrictValidation $record
  # Brak leków
  $assert.notOk $validator.fifthSection(), 'Brak leków'
  # Brak leków - tablica
  $record.drugsOnHospitalisation = []
  $validator.setInterview $record
  $assert.notOk $validator.fifthSection(), 'Brak leków - tablica'
  # Zwykłe leki
  $record.drugsOnHospitalisation = ['ARB', 'B_BLOCKER', 'CALCIUM_CHANNELS_BLOCKER']
  $validator.setInterview $record
  $assert.ok $validator.fifthSection(), 'Zwykłe leki'
  # Inne leki - nieokreślone
  $record.drugsOnHospitalisation = ['OTHER',]
  $validator.setInterview $record
  $assert.notOk $validator.fifthSection(), 'Inne leki - nieokreślone'
  # Inne leki - określone
  $record.otherDrugsOnHospitalisation = 'ibuprom'
  $validator.setInterview $record
  $assert.ok $validator.fifthSection(), 'Inne leki - określone'
