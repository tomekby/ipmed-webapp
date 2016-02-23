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