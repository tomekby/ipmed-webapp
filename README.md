# ipmed-webapp
Aplikacja webowa dla projektu IPMED  
  
Projekt na którym się uczyłem w dużej mierze CoffeScript/jQuery więc wygląda jak wygląda.
Pliki których autorem nie jestem nie są udostępnione w projekcie, więc nie jest to działający przykład.
Początkowo miał być to PoC pokazujący jak wg. mnie będzie wyglądała aplikacja webowa, ale ze względu na 
**początkową** stabilność rozwiązania, brak czasu na przepisanie od początku i późniejsze komplikacje (bałagan)
niestety pozostało jak jest. Można powiedzieć, że ten projekt jest przykładem jak **nie powinno** się tworzyć
oprogramowania. Nie ma tu udostępnionych, ale istnieją jeszcze testy *Selenium*. W katalogu *media/js/test*
znajdują się testy jednostkowe dla testowania ankiety. REST/JSON API było już istniejące.  
  
Główne problemy w chwili obecnej:  
* kod jest podzielony na niewiele plików, przez co nawigacja jest mocno utrudniona  
* nie mogłem znaleźć pluginu do mavena który pozwoliłby na preprocessing plików, więc ustawienia z pliku properties
  są aktualnie wstawiane przez skrypt pythona  
* ww. skrypt zajmuje się równocześnie zamianą kodu Coffe na czysty JS i łączeniem plików (po części już przerzucone
  na require.js)  
* god objects - poszczególne funkcje mają znacznie za dużą odpowiedzialność, ale są tak powiązane, że ciężko to dzielić
  bez testów jednostkowych  
* brak frameworka (np. angulara) - kod jest *teoretycznie* podzielony na poszczególne warstwy abstrakcji:  
	- front controler, który reaguje na kliknięcie linków i wywołuje obsługę poszczególnych podstron (i zajmuje się
	  ustawianiem/kasowaniem event-handlerów, inicjalizacją pluginów itp.)  
	- kontrolery obsługujące poszczególne podstrony -> tu znajduje się większość kodu  
	- funkcje pomocnicze (głównie w utils.coffee) odpowiedzialne za najczęstsze operacje  
	- web-workers pełniące po części rolę modeli (w trakcie implementacji) - komunikują się z REST API, pobierają dane
	  i je wstępnie przetwarzają  
  brak frameworka jest też utrapieniem przy zarządzaniu event-handlerami ponieważ zmusza do pamiętania i ręcznego ich
  ustawiania/kasowania
* testy, a raczej ich brak. Początkowo nie znałem żadnej biblioteki do testów jednostkowych, a ze względu na dużą ilość
  bibliotek do zaznajomienia się przełożyłem to na później. To był **zły** pomysł.  
* API - do teraz mnie zastanawia, dlaczego np. po stronie serwera nie jest cachowany stan ankiety, skoro i tak jest ona
  aktualizowana tylko wtedy, gdy jej stan jest znany (a odczytów jest znacznie więcej niż zapisów). IMO spowalnia to tylko
  aplikację.  

  Skoro API istnieje tylko dla 2 aplikacji które robią to samo (tabletowa i webowa) filtrowanie danych też mogłoby się
  odbywać server-side. Jaki jest sens trzymania danych w bazie danych jeśli wyciąga się zawsze wszystkie rekordy?
* w momencie gdy musiałem zmienić większe fragmenty kodu, zaczął się robić większy i większy bałagan w organizacji kodu

Aplikacja internetowa napisana głównie w CoffeScript/jQuery z dużą ilością bibliotek pomocniczych.