#!/usr/bin/python

# WARNING: Not really tested. May mess up the text.
# Randomize the chapters in the markdown while preserving the chapter links

import re
import sys
from random import randrange

def nacti_soubor(sou):
  with open(sou) as f:
    return f.readlines()

def nasekej_na_kapitoly(s):
  text = []
  kapitoly = dict()
  cislo = 0
  for line in s:
    match = re.match("^\W*##\W+(\d+)\W*", line)
    if match:
      kapitoly[cislo] = text
      text = []
      cislo = int(match.group(1))
    else:
      text.append(line)

  kapitoly[cislo] = text
  #print(kapitoly[0])

  return kapitoly

def ukradni_kapitolu(cislo, kapitoly):
  return kapitoly.pop(cislo)

def vloz_kapitolu(cislo, odkaz, kapitoly):
  kapitoly[cislo] = odkaz

def nahrad_odkazy(stare, nove, kapitoly):
  for kapitoly.items():
    
    re.replace()

def znahodni(cislo, max, stare, nove):
  nove_cislo = randrange(2, max)
  nahrad_odkazy(cislo, nove_cislo, stare)
  nahrad_odkazy(cislo, nove_cislo, nove)
  return nove_cislo

def zprehazej_kapitoly(kapitoly):
  pocet = len(kapitoly)
  nove_kapitoly = dict()

  odkaz = ukradni_kapitolu(0, kapitoly)
  vloz_kapitolu(0, odkaz, nove_kapitoly)
  odkaz = ukradni_kapitolu(1, kapitoly)
  vloz_kapitolu(1, odkaz, nove_kapitoly)

  for cislo in xrange(2, pocet):
    odkaz = ukradni_kapitolu(cislo, kapitoly)
    nove_cislo = znahodni(cislo, pocet, kapitoly, nove_kapitoly)
    vloz_kapitolu(nove_cislo, odkaz, nove_kapitoly)

obsah = nacti_soubor(sys.argv[1])
kapitoly = nasekej_na_kapitoly(obsah)
print(kapitoly)
