#!/usr/bin/env python
# -*- coding: utf-8 -*-

from subprocess import check_output, CalledProcessError
import os.path
from sys import exit, argv

# Stałe
JS_PATH = 'src/main/webapp/resources/media/js/'
COFFEE_CMD = 'C:\\Program Files\\nodejs\\coffee.cmd'
RES_FILE_NAME = 'scripts.coffee'
RES_FILE = '%s%s' % (JS_PATH, RES_FILE_NAME)
COFFEE_PARAMS = [COFFEE_CMD, '--bare', '--compile', '--map', RES_FILE_NAME, 'config.coffee']
#COFFEE_PARAMS = [COFFEE_CMD, '--bare', '--compile', RES_FILE_NAME, 'config.coffee']
PROPERTIES_FILE = 'src/main/resources/zbox.properties'
# Lista plików do połączenia
files = ['config.coffee', 'utils.coffee', 'main.coffee', 'page_handlers.coffee', 'start_loaded.coffee']
# Konfiguracja
config = {}

# Czytanie konfiguracji z pliku properties
def read_conf():
    with open(PROPERTIES_FILE) as prop:
        lines = [line.rstrip('\n') for line in prop]
    for line in lines:
        line.lower()
        if line.startswith('webapp'):
            parts = line.split('=', 2)
            key, value = parts[0], parts[1]
            config[key[7:]] = value
    return config

# Łączenie plików i transpilacja do JS
def transpile():
    # Przetwarzanie ich
    res = ''
    for file_name in files:
        path = '%s%s' % (JS_PATH, file_name)
        with open(path, encoding="utf-8") as content_file:
            content = content_file.read()
        res+=content
        res+="\n"
    # Wszystkie pliki połączone w jeden - można transpilować
    with open(RES_FILE, 'w+', encoding="utf-8") as result_coffee:
        # Zapis konfiguracji do coffee
        for key, val in config.items():
            result_coffee.write("$%s = %s\n" % (key, val))
        result_coffee.write(res)

    # Wywołanie coffee
    try:
        os.chdir(JS_PATH)
        coffe_res = check_output(COFFEE_PARAMS)
    except CalledProcessError as e:
        print(e.output)

# Sprawdzenie czy coffee jest w odpowiedniej ścieżce
if not os.path.isfile(COFFEE_CMD) or (len(argv) == 2 and argv[1] == RES_FILE_NAME):
    exit()
read_conf()
transpile()