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

