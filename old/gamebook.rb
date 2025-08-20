#!/usr/bin/ruby

Kapitola = Struct.new(:cislo, :text, :odkazy, :mozna_odkazy, :dostupnost)
Statistika = Struct.new(:celkem, :chybi_odkaz, :nedostupny, :koncovy, :prazdny, :uvolnitelny, :smrt, :poznamka, :boj)

class Gamebook
  def initialize(soubor)
    nacti_ze_souboru(soubor)
    vytvor_graf()
    @nazev = soubor
    @statistika = Statistika.new([], [], [], [], [], [], [], [], [])
  end

  def zkontroluj_kapitoly
    @kapitoly.each_with_index do |kapitola, cislo|
      abort "Chybí kapitola #{cislo}." if kapitola.nil?
    end
  end

  def nacti_ze_souboru(soubor)
    radky = File.readlines(soubor)
    @kapitoly = nasekej_na_kapitoly(radky)
    zkontroluj_kapitoly()
  end

  def vypis
    uvod = @kapitoly[0]
    puts uvod.to_s

    @kapitoly.each_with_index do |kapitola, cislo|
      if cislo.positive?
        puts "## #{cislo}"
        puts kapitola.to_s
      end
    end
  end

  # TODO: dlouho neotestovane
  def zamichej_kapitoly
    pocet = @kapitoly.size
    nove_kapitoly = Array.new(pocet)
    mapa_zmen = Array.new(pocet)

    mapa_zmen[0] = 0
    mapa_zmen[1] = 1
    mapa_zmen[pocet - 1] = pocet - 1

    # Nechat uvod, prvni a posledni odkaz
    odkaz = ukradni_kapitolu(0, @kapitoly)
    vloz_kapitolu(0, odkaz, nove_kapitoly)
    odkaz = ukradni_kapitolu(1, @kapitoly)
    vloz_kapitolu(1, odkaz, nove_kapitoly)
    odkaz = ukradni_kapitolu(pocet - 1, @kapitoly)
    vloz_kapitolu(pocet - 1, odkaz, nove_kapitoly)

    (2..pocet - 2).each do |cislo|
      nove_cislo = znahodni(cislo, pocet - 2, @kapitoly, nove_kapitoly)
      odkaz = ukradni_kapitolu(cislo, @kapitoly)
      vloz_kapitolu(nove_cislo, odkaz, nove_kapitoly)
      mapa_zmen[cislo] = nove_cislo
      #puts "stare #{kapitoly}"
      #puts "nove #{nove_kapitoly}"
    end

    smaz_prefix_odkazu(nove_kapitoly)
    mapa_zmen.each_with_index do |cislo, index|
      puts "#{index} -> #{cislo}"
    end
    @kapitoly = nove_kapitoly
  end

  # vytvor graf (seznam sousedu) z textu
  def vytvor_graf
    @graf_kapitol = []

    @kapitoly.each_with_index do |kapitola, cislo|
      odkazy = kapitola.scan(/\*\*(\d+)\*\*/).map { |num| num[0].to_i }
      mozna_odkazy = kapitola.scan(/\*\*(\d+) ?\?\*\*/).map { |num| num[0].to_i }
      kap = Kapitola.new(cislo, kapitola, odkazy, mozna_odkazy, false)
      @graf_kapitol.append(kap)
    end

    spocitej_dostupnost()
  end

  # vygeneruje dot soubor
  def vykresli
    puts "digraph \"#{@nazev}\" {"

    @graf_kapitol.each do |kap|
      # escape tooltip text
      escaped_text = kap.text.gsub('"', '\"')
      tooltip = "tooltip=\"#{escaped_text}\""

      # obarvit specialni odkazy
      obarvi_uzel(kap, tooltip)
      vykresli_odkazy(kap.cislo, kap.odkazy, kap.mozna_odkazy)
    end

    puts '}'
  end

  def spocitej_dostupnost
    @graf_kapitol.each do |kap|
      (kap.odkazy + kap.mozna_odkazy).each do |odkaz|
        @graf_kapitol[odkaz].dostupnost = true
      end
    end
  end

  def stat_puts(popis, seznam)
    mozna_seznam = ''
    # nevypisovat prazdne a prilis dlouhe seznamy
    if !seznam.empty? && seznam.size < 40
      mozna_seznam = ": #{seznam}"
    end
    warn("#{popis}: #{seznam.size}#{mozna_seznam}")
  end

  def vypis_statistiky
    stat_puts('Odkazů celkem', @graf_kapitol)
    stat_puts('Prázdných', @statistika.prazdny)
    stat_puts('Nenapsaných', @statistika.chybi_odkaz)
    stat_puts('Nedostupných', @statistika.nedostupny)
    stat_puts('Koncových', @statistika.koncovy)
    stat_puts('Smrtí', @statistika.smrt)
    stat_puts('Uvolnitelných', @statistika.uvolnitelny)
    stat_puts('Poznámek', @statistika.poznamka)
    stat_puts('Bojů', @statistika.boj)
    stat_puts('Nejkratší cesta do cíle', najdi_cestu())
    stat_puts('Nejdelší cesta do cíle', []) # bfs neumi kruhy
  end

  def najdi_cestu
    # projdi graf a vrat seznam predchudcu
    predchudci = bfs()

    # zacnu poslednim odkazem a pujdu po predchudcich k zacatku
    cislo = @graf_kapitol.size - 1
    cesta = [cislo]

    # sestav cestu do cile
    while cislo && cislo != 1
      cislo = predchudci[cislo]
      cesta.prepend(cislo)
      #puts "#{cesta}"
    end

    if cislo != 1
      warn('Cesta k cíli nenalezena! Nedokončeno nebo zapomenuté skryté odkazy?')
      return []
    end

    return cesta
  end

  def bfs
    navstivene = Set.new
    fronta = [1]
    predchudci = []
    navstivene.add(1)

    # pridej odkazy z 1
    fronta.concat(@graf_kapitol[1].odkazy).concat(@graf_kapitol[1].mozna_odkazy)

    while (cislo = fronta.shift)
      # jsme v cili, hotovo
      return predchudci if cislo == @graf_kapitol.size - 1

      # prozkoumam odkazy z aktualniho cisla
      (@graf_kapitol[cislo].odkazy + @graf_kapitol[cislo].mozna_odkazy).each do |odkaz|
        next if navstivene.include?(odkaz)

        navstivene.add(odkaz)
        predchudci[odkaz] = cislo
        fronta.append(odkaz)
      end
    end

    # nedoslo se do cile, vrat prazdnou cestu
    return []
  end

end # Gamebook

def obarvi_uzel(kap, tooltip)
  barva_standard = ''
  barva_dvojita_hrana = ' style=filled fillcolor=orange'
  barva_chybi_odkaz = ' style=filled fillcolor=lightgreen'
  barva_nedostupny = ' style=filled fillcolor=yellow'
  barva_koncovy = ' style=filled fillcolor=lightcoral'
  barva_prazdny = ' style=filled fillcolor=lightblue'
  barva_uvolnitelny = ' style=filled fillcolor=pink'
  barva_smrt = ' style=filled fillcolor=lightgrey'
  barva_poznamka = ' style=filled fillcolor=plum'
  barva_pres400 = ' style=filled fillcolor=aquamarine'
  tvar = ''

  if obsahuje_boj?(kap.text)
    # TODO: proc je tahle class instance variable dostupna?
    @statistika.boj.append(kap.cislo)
    tvar = 'shape = box'
  end

  # TODO: obarvit zkouseni stesti, posileni/ztraty UB/ST

  # obarvit dvojite hrany
  if dvojita_hrana?(kap.odkazy)
    puts "#{kap.cislo} [#{tooltip} #{barva_dvojita_hrana} #{tvar}];"
  end

  # obarvit koncovy stav
  if kap.odkazy.empty? && kap.mozna_odkazy.empty?
    @statistika.koncovy.append(kap.cislo)
    puts "#{kap.cislo} [#{tooltip} #{barva_koncovy} #{tvar}];"
  end

  # obarvit nedostupne
  if !kap.dostupnost
    @statistika.nedostupny.append(kap.cislo)
    puts "#{kap.cislo} [#{tooltip} #{barva_nedostupny} #{tvar}];"
  else # normalni barva
    puts "#{kap.cislo} [#{tooltip} #{barva_standard} #{tvar}];"
  end

  # obarvit prazdny
  if prazdny_text?(kap.text)
    @statistika.prazdny.append(kap.cislo)
    puts "#{kap.cislo} [#{tooltip} #{barva_prazdny} #{tvar}];"
  end

  # obarvit smrti
  if kap.text.match('💀')
    @statistika.smrt.append(kap.cislo)
    puts "#{kap.cislo} [#{tooltip} #{barva_smrt} #{tvar}];"
  end

  # obarvit poznamky
  if obsahuje_poznamku?(kap.text)
    @statistika.poznamka.append(kap.cislo)
    puts "#{kap.cislo} [#{tooltip} #{barva_poznamka} #{tvar}];"
  end

  # obarvit chybejici odkazy
  # String.scan() vraci prazdne pole ne false kdyz neuspeje
  chybejici = chybejici_odkaz?(kap.text)
  if !chybejici.empty? 
    # pridat odkaz tolikrat, kolik ma nedopsanych odkazu
    chybejici.size.times { @statistika.chybi_odkaz.append(kap.cislo) }
    puts "#{kap.cislo} [#{tooltip} #{barva_chybi_odkaz} #{tvar}];"
  end

  # obarvit uvolnitelne
  if mozna_uvolnitelny?(kap.text)
    @statistika.uvolnitelny.append(kap.cislo)
    puts "#{kap.cislo} [#{tooltip} #{barva_uvolnitelny} #{tvar}];"
  end

  # obarvit pres 400
  if pres_400?(kap.odkazy + kap.mozna_odkazy)
    puts "#{kap.cislo} [#{tooltip} #{barva_pres400} #{tvar}];"
  end
end

def vykresli_odkazy(cislo, odkazy, mozna_odkazy)
  odkazy.each do |odkaz|
    puts "#{cislo}-> #{odkaz};"
  end
  mozna_odkazy.each do |odkaz|
    puts "#{cislo}-> #{odkaz} [style=dotted];"
  end
end

def obsahuje_boj?(text)
  return text.match(/^\s.*UMĚNÍ BOJE\s+\d+\s+STAMINA\s+\d+\s*$/)
end

def obsahuje_poznamku?(text)
  return text.match(/\(.*\)/)
end

def prazdny_text?(text)
  return text.match(/\A\s*(EMPTY|VOLNO|VOLNE)*\s*\z/)
end

def mozna_uvolnitelny?(text)
  return text.match(/(EMPTY|VOLNO|VOLNE)\??\s*$/)
end

def pres_400?(odkazy)
  odkazy.each do |cislo|
    return true if cislo > 400
  end
  return false
end

def chybejici_odkaz?(text)
  return text.scan(/\*{4}/)
end

def dvojita_hrana?(odkazy)
  return odkazy.uniq.size != odkazy.size
end

def nasekej_na_kapitoly(s)
  text = ''
  kapitoly = []
  cislo = 0
  s.each do |line|
    m = line.match(/^\W*##\W+(\d+)\W*$/)
    if m
      kapitoly[cislo] = text
      text = ''
      cislo = m[1].to_i
    else
      text.concat(line)
    end
  end

  kapitoly[cislo] = text
  return kapitoly
end

def ukradni_kapitolu(cislo, kapitoly)
  kapitola = kapitoly[cislo]
  kapitoly[cislo] = nil
  return kapitola
end

def vloz_kapitolu(cislo, odkaz, kapitoly)
  kapitoly[cislo] = odkaz
end

# Nahradim s prefixem, aby nedoslo k opakovanemu nahrazeni
def nahrad_s_prefixem(stare, nove, kap)
  if kap
    kap = kap.gsub(/\*\*#{stare}\*\*/, "*@*#{nove}*@*")
  end
  return kap
end

def nahrad_odkazy(stare, nove, kapitoly)
  #puts "nahrazene #{stare} -> #{nove}"
  kapitoly.map! { |kap| nahrad_s_prefixem(stare, nove, kap) }
end

def smaz_prefix_odkazu(kapitoly)
  kapitoly.map! { |kap| kap.gsub(/\*@\*(\d+)\*@\*/, '**\1**') }
end

def nahodne_cislo(max, pole)
  cislo = rand(2..max)
  while pole[cislo]
    cislo = rand(2..max)
  end
  return cislo
end

def znahodni(cislo, max, stare, nove)
  nove_cislo = nahodne_cislo(max, nove)
  #puts "pred nahrad stare #{stare}"
  nahrad_odkazy(cislo, nove_cislo, stare)
  #puts "po nahrad stare #{stare}"
  #puts "pred nahrad nove #{nove}"
  nahrad_odkazy(cislo, nove_cislo, nove)
  #puts "po nahrad nove #{nove}"
  return nove_cislo
end

# ARGV[0] is the first argument, not program name
kniha = Gamebook.new(ARGV[0])
kniha.vykresli()
kniha.vypis_statistiky()

#kniha.vypis() # puvodni
#kniha.zamichej_kapitoly()
#kniha.vypis() # zamichana
