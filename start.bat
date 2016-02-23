@echo off
set JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF-8
rem stderr przekierowany do NUL, stdout sprawdzane tylko ze względu na to czy serwer już wystartował
rem łatwiej tak sprawdzać niż szukać wśród miliarda wyjątków i stack trace'ów
mvn jetty:run 2> NUL | perl -e "while(<>){if(/started jetty/i){ system('add_measurements.pl 5'); print $_; break }}" 2> NUL