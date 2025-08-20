// hack to use stderr to print stats while allowing piping the dot content
@preconcurrency import Glibc
import Foundation 

class Kapitola {
  var cislo = 0
  var text = ""
  var odkazy: [Int] = []
  var mozna_odkazy: [Int] = []
  var dostupnost = false

  init(_ cislo: Int, _ text: String, _ odkazy: [Int], _ mozna_odkazy : [Int], _ dostupnost: Bool) {
    self.cislo = cislo
    self.text = text
    self.odkazy = odkazy
    self.mozna_odkazy = mozna_odkazy
    self.dostupnost = dostupnost
  }
}

class Statistika {
  var chybi_odkaz: [Int] = []
  var nedostupny: [Int] = []
  var koncovy: [Int] = []
  var prazdny: [Int] = []
  var uvolnitelny: [Int] = []
  var smrt: [Int] = []
  var poznamka: [Int] = []
  var boj: [Int] = []
}

class Gamebook {
  var kapitoly: [String] = []
  var graf_kapitol: [Kapitola] = []
  var nazev = ""
  var statistika = Statistika()

  init() {
    guard CommandLine.arguments.count >= 2 else {
      preconditionFailure("Chybí soubor ke zpracování.")
    }
    
    nazev = CommandLine.arguments[1]
    kapitoly = nacti_kapitoly_ze_souboru(nazev)
    vytvor_graf()
  }

  func nacti_kapitoly_ze_souboru(_ soubor: String) -> [String] {
    var text = ""
    var kapitoly: [String] = []
    var cislo = 0
    var radky: [String]
    var vse: String

    do {
      vse = try String(contentsOfFile: soubor, encoding: .utf8)
    } catch {
      preconditionFailure("Nemůžu načíst soubor: \(error)")
    }
    radky = vse.components(separatedBy: .newlines)
    
    let hashAndNumber = /(?m)^\W*##\W+(\d+)\W*$/

    radky.forEach { line in
      if let m = line.firstMatch(of: hashAndNumber) {
        kapitoly.append(text)

        text = ""
        cislo += 1
        // zkontrolovat, ze cisla kapitol navazuji
        guard Int(m.1) == cislo else {
          preconditionFailure("Chybí kapitola: \(cislo).")
        }
      } else {
        text += line + "\n"
      }
    }

    kapitoly.append(text)
    return kapitoly
  }

  // vytvor graf (seznam sousedu) z textu
  func vytvor_graf() {
    for (cislo, text) in kapitoly.enumerated() { 
      let odkazy_regex = /\*\*(\d+)\*\*/
      let mozna_regex = /\*\*(\d+) ?\?\*\*/

      // TODO: poradne zjistit co s Optionals
      let odkazy = text.matches(of: odkazy_regex).compactMap { Int($0.output.1) }
      let mozna_odkazy = text.matches(of: mozna_regex).compactMap { Int($0.output.1) }

      let kap = Kapitola(cislo, text, odkazy, mozna_odkazy, false)
      graf_kapitol.append(kap)
    }
    spocitej_dostupnost()
  }

  func spocitej_dostupnost() {
    graf_kapitol.forEach { kap in
      (kap.odkazy + kap.mozna_odkazy).forEach { odkaz in
        guard 1 <= odkaz && odkaz < graf_kapitol.count else {
          preconditionFailure("Špatné číslo odkazu: \(odkaz). Musí být mezi 1 a \(graf_kapitol.count - 1).")
        }
        graf_kapitol[odkaz].dostupnost = true
      }
    }
  }

  // vygeneruje dot soubor
  func vykresli() {
    print("digraph \"\(nazev)\" {")

    graf_kapitol.forEach { kap in
      // escape tooltip text
      let escaped_text = kap.text.replacingOccurrences(of: "\"", with: "\\\"")
      let tooltip = "tooltip=\"\(escaped_text)\""

      // obarvit specialni odkazy
      obarvi_uzel(kap, tooltip)
      vykresli_odkazy(kap.cislo, kap.odkazy, kap.mozna_odkazy)
    }

    print("}")
  }

  func stat_puts(_ popis: String, _ seznam: [Any]) {
    var mozna_seznam = ""
    // nevypisovat prazdne a prilis dlouhe seznamy
    if !seznam.isEmpty && seznam.count < 100 {
      mozna_seznam = ": \(seznam)"
    }
    fputs(" \(popis): \(seznam.count)\(mozna_seznam)\n", Glibc.stderr)
  }

  func vypis_statistiky() {
    stat_puts("Odkazů celkem", graf_kapitol)
    let napsane = Array(Set(0..<graf_kapitol.count).subtracting(Set(statistika.prazdny)))
    stat_puts("Napsaných", napsane)
    stat_puts("Prázdných", statistika.prazdny)
    stat_puts("Nedopsaných", statistika.chybi_odkaz)
    stat_puts("Nedostupných", statistika.nedostupny)
    stat_puts("Koncových", statistika.koncovy)
    stat_puts("Smrtí", statistika.smrt)
    stat_puts("Uvolnitelných", statistika.uvolnitelny)
    stat_puts("Poznámek", statistika.poznamka)
    stat_puts("Bojů", statistika.boj)
    stat_puts("Odkazů do draků", odkazu_pred(283))
    stat_puts("Nejkratší cesta do cíle", najdi_cestu())
    stat_puts("Nejdelší cesta do cíle", []) // bfs neumi kruhy
  }

  func najdi_cestu() -> [Int] {
    // projdi graf do cile (odkaz s nejvyssim cislem) a vrat seznam predchudcu
    let (predchudci, _) = bfs(graf_kapitol.count - 1)

    if predchudci.isEmpty {
      puts("Cesta k cíli nenalezena! Nedokončeno nebo neuvedené skryté odkazy?")
      return []
    }

    // zacnu poslednim odkazem a pujdu po predchudcich k zacatku
    var cislo = graf_kapitol.count - 1
    var cesta = [cislo]

    // sestav cestu do cile
    // musi existovat, jinak by bfs vratilo prazdne predchudce
    while cislo != 1 {
      cislo = predchudci[cislo]
      cesta.insert(cislo, at: 0)
    }

    return cesta
  }

  func odkazu_pred(_ cil: Int) -> [Int] {
    // projdi graf a ziskej seznam navstivenych odkazu 
    let (_, navstivene) = bfs(cil)
    return navstivene
  }

  // projdi graf do ciloveho odkazu
  func bfs(_ cil: Int) -> ([Int], [Int]) {
    var navstivene: Set = [1]
    var fronta = [1]
    var predchudci = Array(repeating: 0, count: graf_kapitol.count)
    var cislo: Int

    // pridej odkazy z 1
    fronta += graf_kapitol[1].odkazy + graf_kapitol[1].mozna_odkazy

    cislo = fronta.removeFirst()
    while (cislo != 0) {
      // jsme v cili, hotovo
      if cislo == cil {
        return (predchudci, Array(navstivene)) 
      }

      // prozkoumam odkazy z aktualniho cisla
      for odkaz in (graf_kapitol[cislo].odkazy + graf_kapitol[cislo].mozna_odkazy) {
        if navstivene.contains(odkaz) { continue }
        navstivene.insert(odkaz)
        predchudci[odkaz] = cislo
        fronta.append(odkaz)
      }
      cislo = fronta.removeFirst()
    }

    // nedoslo se do cile, vrat prazdnou cestu
    return ([], [])
  }

  func obarvi_uzel(_ kap: Kapitola, _ tooltip: String) {
    let barva_dvojita_hrana = " style=filled fillcolor=orange"
    let barva_chybi_odkaz = " style=filled fillcolor=lightgreen"
    let barva_nedostupny = " style=filled fillcolor=yellow"
    let barva_koncovy = " style=filled fillcolor=lightcoral"
    let barva_prazdny = " style=filled fillcolor=lightblue"
    let barva_uvolnitelny = " style=filled fillcolor=pink"
    let barva_smrt = " style=filled fillcolor=lightgrey"
    let barva_poznamka = " style=filled fillcolor=plum"
    let barva_pres400 = " style=filled fillcolor=aquamarine"

    var tvar = ""
    var barva = ""

    if obsahuje_boj(kap.text) {
      statistika.boj.append(kap.cislo)
      tvar = "shape = box"
    }

    // TODO: obarvit zkouseni stesti, posileni/ztraty UB/ST

    // obarvit dvojite hrany
    if dvojita_hrana(kap.odkazy) {
      barva = barva_dvojita_hrana
    }

    // obarvit koncovy stav
    if kap.odkazy.isEmpty && kap.mozna_odkazy.isEmpty {
      statistika.koncovy.append(kap.cislo)
      barva = barva_koncovy
    }

    // obarvit nedostupne
    if !kap.dostupnost {
      statistika.nedostupny.append(kap.cislo)
      barva = barva_nedostupny
    }

    // obarvit prazdny
    if prazdny_text(kap.text) {
      statistika.prazdny.append(kap.cislo)
      barva = barva_prazdny
    }

    // obarvit smrti
    if kap.text.firstMatch(of: /💀/) != nil {
      statistika.smrt.append(kap.cislo)
      barva = barva_smrt
    }

    // obarvit poznamky
    if obsahuje_poznamku(kap.text) {
      statistika.poznamka.append(kap.cislo)
      barva = barva_poznamka
    }

    // obarvit chybejici odkazy
    let chybejicich = chybejici_odkaz(kap.text)
    if chybejicich > 0 {
      barva = barva_chybi_odkaz
      // pridat odkaz tolikrat, kolik ma nedopsanych odkazu
      for _ in 1...chybejicich { statistika.chybi_odkaz.append(kap.cislo) }
    }

    // obarvit uvolnitelne
    if mozna_uvolnitelny(kap.text) {
      statistika.uvolnitelny.append(kap.cislo)
      barva = barva_uvolnitelny
    }

    // obarvit odkazy nad 400
    if pres_400(kap.odkazy + kap.mozna_odkazy) {
      barva = barva_pres400
    }

    // vypis kapitolu pro dot
    print("\(kap.cislo) [\(tooltip) \(barva) \(tvar)];")
  }
} // Gamebook

func vykresli_odkazy(_ cislo: Int, _ odkazy: [Int], _ mozna_odkazy: [Int]) {
  odkazy.forEach { odkaz in
    print("\(cislo)-> \(odkaz);")
  }
  mozna_odkazy.forEach { odkaz in
    print("\(cislo)-> \(odkaz) [style=dotted];")
  }
}

// TODO: pouzit konstanty pro UB/ST, hodi se na moznost prekladu na AJ
func obsahuje_boj(_ text: String) -> Bool {
  return text.firstMatch(of: /(?m)^\s.*UMĚNÍ BOJE\s+\d+\s+STAMINA\s+\d+\s*$/) != nil
}

func obsahuje_poznamku(_ text: String) -> Bool {
  return text.firstMatch(of: /\(.*\)/) != nil
}

func prazdny_text(_ text: String) -> Bool {
  return text.firstMatch(of: /(?m)\A\s*(EMPTY|VOLNO|VOLNE)*\s*\z/) != nil
}

func mozna_uvolnitelny(_ text: String) -> Bool {
  return text.firstMatch(of: /(?m)(EMPTY|VOLNO|VOLNE)\??\s*$/) != nil
}

func pres_400(_ odkazy: [Int]) -> Bool {
  for cislo in odkazy { 
    if cislo > 400 { return true }
  }
  return false
}

func chybejici_odkaz(_ text: String) -> Int {
  return text.matches(of: /\*{4}/).compactMap { $0.output }.count
}

func dvojita_hrana(_ odkazy: [Int]) -> Bool {
  let set = Set(odkazy)
  return set.count != odkazy.count
}

let kniha = Gamebook()
kniha.vykresli()
kniha.vypis_statistiky()
