# TODO: prelozit? jen komentare nebo i nazvy promennych?

class Kapitola
  property cislo, text, odkazy, mozna_odkazy, dostupnost

  def initialize(
    @cislo : UInt16,
    @text : String,
    @odkazy : Array(UInt16),
    @mozna_odkazy : Array(UInt16),
    @dostupnost : Bool,
  )
  end
end

class Statistika
  property chybi_odkaz, nedostupny, koncovy, prazdny, uvolnitelny, smrt, poznamka, boj

  def initialize
    @chybi_odkaz = [] of UInt16
    @nedostupny = [] of UInt16
    @koncovy = [] of UInt16
    @prazdny = [] of UInt16
    @uvolnitelny = [] of UInt16
    @smrt = [] of UInt16
    @poznamka = [] of UInt16
    @boj = [] of UInt16
  end
end

class Gamebook
  @kapitoly : Array(String)
  @graf_kapitol : Array(Kapitola)
  @nazev : String

  def initialize
    @nazev = ARGV[0]
    abort "Chybí soubor ke zpracování." if @nazev.empty?

    @kapitoly = nacti_kapitoly_ze_souboru(@nazev)
    @graf_kapitol = [] of Kapitola
    vytvor_graf()

    @statistika = Statistika.new
  end

  def nacti_kapitoly_ze_souboru(soubor)
    text = ""
    kapitoly = [] of String
    cislo = 0_u16

    begin
      radky = File.read_lines(soubor)
    rescue
      abort("Nemůžu načíst soubor.")
    end

    radky.each do |line|
      m = /^\W*##\W+(\d+)\W*$/.match(line)
      if m
        kapitoly << text
        text = ""
        cislo += 1
        # zkontrolovat, ze cisla kapitol navazuji
        if m[1].to_u16 != cislo
          abort "Chybí kapitola: #{cislo}."
        end
      else
        text += line + "\n"
      end
    end

    kapitoly << text
    return kapitoly
  end

  # vytvor graf (seznam sousedu) z textu
  def vytvor_graf
    @kapitoly.each_with_index do |kapitola, cislo|
      odkazy = kapitola.scan(/\*\*(\d+)\*\*/).map { |num| num[1].to_u16 }
      mozna_odkazy = kapitola.scan(/\*\*(\d+) ?\?\*\*/).map { |num| num[1].to_u16 }
      kap = Kapitola.new(cislo.to_u16, kapitola, odkazy, mozna_odkazy, false)
      @graf_kapitol << kap
    end

    spocitej_dostupnost()
  end

  def spocitej_dostupnost
    @graf_kapitol.each do |kap|
      (kap.odkazy + kap.mozna_odkazy).each do |odkaz|
        abort "Špatné číslo odkazu: #{odkaz}. Musí být mezi 1 a #{@graf_kapitol.size - 1}." if !odkaz.positive? || odkaz >= @graf_kapitol.size
        @graf_kapitol[odkaz].dostupnost = true
      end
    end
  end

  # vygeneruje dot soubor
  def vykresli
    puts "digraph \"#{@nazev}\" {"

    @graf_kapitol.each do |kap|
      # escape tooltip text
      escaped_text = kap.text.gsub('"', "\\\"")
      tooltip = "tooltip=\"#{escaped_text}\""

      # obarvit specialni odkazy
      obarvi_uzel(kap, tooltip)
      vykresli_odkazy(kap.cislo, kap.odkazy, kap.mozna_odkazy)
    end

    puts '}'
  end

  def stat_puts(popis, seznam)
    mozna_seznam = ""
    # nevypisovat prazdne a prilis dlouhe seznamy
    if !seznam.empty? && seznam.size < 100
      mozna_seznam = ": #{seznam}"
    end
    STDERR.puts "#{popis}: #{seznam.size}#{mozna_seznam}"
  end

  def vypis_statistiky
    stat_puts("Odkazů celkem", @graf_kapitol)
    stat_puts("Napsaných", (0..@graf_kapitol.size - 1).to_a - @statistika.prazdny)
    stat_puts("Prázdných", @statistika.prazdny)
    stat_puts("Nedopsaných", @statistika.chybi_odkaz)
    stat_puts("Nedostupných", @statistika.nedostupny)
    stat_puts("Koncových", @statistika.koncovy)
    stat_puts("Smrtí", @statistika.smrt)
    stat_puts("Uvolnitelných", @statistika.uvolnitelny)
    stat_puts("Poznámek", @statistika.poznamka)
    stat_puts("Bojů", @statistika.boj)
    stat_puts("Odkazů do draků", odkazu_pred(283))
    stat_puts("Nejkratší cesta do cíle", najdi_cestu())
    stat_puts("Nejdelší cesta do cíle", [] of String) # bfs neumi kruhy
  end

  def najdi_cestu
    # projdi graf do cile (odkaz s nejvyssim cislem) a vrat seznam predchudcu
    predchudci, _ = bfs(@graf_kapitol.size - 1)

    if predchudci.empty?
      STDERR.puts "Cesta k cíli nenalezena! Nedokončeno nebo neuvedené skryté odkazy?"
      return [] of UInt16
    end

    # zacnu poslednim odkazem a pujdu po predchudcich k zacatku
    cislo = @graf_kapitol.size - 1
    cesta = [cislo]

    # sestav cestu do cile
    # musi existovat, jinak by bfs vratilo prazdne predchudce
    while cislo != 1
      cislo = predchudci[cislo]
      cesta.unshift(cislo)
    end

    return cesta
  end

  def odkazu_pred(cil)
    # projdi graf a ziskej seznam navstivenych odkazu 
    _, navstivene = bfs(cil)
    return navstivene.to_a
  end

  # projdi graf do ciloveho odkazu
  def bfs(cil)
    navstivene = Set{1_u16}
    fronta = [1_u16]
    predchudci = Array.new(@graf_kapitol.size, 0_u16)

    # pridej odkazy z 1
    fronta.concat(@graf_kapitol[1].odkazy).concat(@graf_kapitol[1].mozna_odkazy)

    while (cislo = fronta.shift?)
      # jsme v cili, hotovo
      return {predchudci, navstivene} if cislo == cil

      # prozkoumam odkazy z aktualniho cisla
      (@graf_kapitol[cislo].odkazy + @graf_kapitol[cislo].mozna_odkazy).each do |odkaz|
        next if navstivene.includes?(odkaz)
        navstivene.add(odkaz)
        predchudci[odkaz] = cislo
        fronta << odkaz
      end
    end

    # nedoslo se do cile, vrat prazdnou cestu
    return {[] of UInt16, [] of UInt16}
  end

  def obarvi_uzel(kap, tooltip)
    barva_dvojita_hrana = " style=filled fillcolor=orange"
    barva_chybi_odkaz = " style=filled fillcolor=lightgreen"
    barva_nedostupny = " style=filled fillcolor=yellow"
    barva_koncovy = " style=filled fillcolor=lightcoral"
    barva_prazdny = " style=filled fillcolor=lightblue"
    barva_uvolnitelny = " style=filled fillcolor=pink"
    barva_smrt = " style=filled fillcolor=lightgrey"
    barva_poznamka = " style=filled fillcolor=plum"
    barva_pres400 = " style=filled fillcolor=aquamarine"

    tvar = ""
    barva = ""

    if obsahuje_boj?(kap.text)
      @statistika.boj << kap.cislo
      tvar = "shape = box"
    end

    # TODO: obarvit zkouseni stesti, posileni/ztraty UB/ST

    # obarvit dvojite hrany
    if dvojita_hrana?(kap.odkazy)
      barva = barva_dvojita_hrana
    end

    # obarvit koncovy stav
    if kap.odkazy.empty? && kap.mozna_odkazy.empty?
      @statistika.koncovy << kap.cislo
      barva = barva_koncovy
    end

    # obarvit nedostupne
    if !kap.dostupnost
      @statistika.nedostupny << kap.cislo
      barva = barva_nedostupny
    end

    # obarvit prazdny
    if prazdny_text?(kap.text)
      @statistika.prazdny << kap.cislo
      barva = barva_prazdny
    end

    # obarvit smrti
    if kap.text.match(/💀/)
      @statistika.smrt << kap.cislo
      barva = barva_smrt
    end

    # obarvit poznamky
    if obsahuje_poznamku?(kap.text)
      @statistika.poznamka << kap.cislo
      barva = barva_poznamka
    end

    # obarvit chybejici odkazy
    # String.scan() vraci prazdne pole ne false kdyz neuspeje
    chybejici = chybejici_odkaz?(kap.text)
    if !chybejici.empty?
      # pridat odkaz tolikrat, kolik ma nedopsanych odkazu
      chybejici.size.times { @statistika.chybi_odkaz << kap.cislo }
      barva = barva_chybi_odkaz
    end

    # obarvit uvolnitelne
    if mozna_uvolnitelny?(kap.text)
      @statistika.uvolnitelny << kap.cislo
      barva = barva_uvolnitelny
    end

    # obarvit pres 400
    if pres_400?(kap.odkazy + kap.mozna_odkazy)
      barva = barva_pres400
    end

    # vypis kapitolu pro dot
    puts "#{kap.cislo} [#{tooltip} #{barva} #{tvar}];"
  end
end # Gamebook

def vykresli_odkazy(cislo, odkazy, mozna_odkazy)
  odkazy.each do |odkaz|
    puts "#{cislo}-> #{odkaz};"
  end
  mozna_odkazy.each do |odkaz|
    puts "#{cislo}-> #{odkaz} [style=dotted];"
  end
end

# TODO: pouzit konstanty pro UB/ST, hodi se na moznost prekladu na AJ
def obsahuje_boj?(text)
  return text.match(/^\s.*UMĚNÍ BOJE\s+\d+\s+STAMINA\s+\d+\s*$/m)
end

def obsahuje_poznamku?(text)
  return text.match(/\(.*\)/)
end

def prazdny_text?(text)
  return text.match(/\A\s*(EMPTY|VOLNO|VOLNE)*\s*\z/m)
end

def mozna_uvolnitelny?(text)
  return text.match(/(EMPTY|VOLNO|VOLNE)\??\s*$/m)
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

kniha = Gamebook.new
kniha.vykresli
kniha.vypis_statistiky
