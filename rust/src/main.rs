extern crate regex;

use std::env;
use std::fs::read_to_string;
use regex::Regex;
use std::collections::HashSet;
use std::collections::VecDeque;

#[derive(Debug)]
struct Kapitola {
    cislo: u32,
    text: String,
    odkazy: Vec<u32>,
    mozna_odkazy: Vec<u32>,
    dostupnost: bool,
}

impl Kapitola {
    fn new(cislo: u32, text: &str, odkazy: &[u32], mozna_odkazy : &[u32], dostupnost: bool) -> Kapitola {
        Kapitola {
            cislo: cislo,
            text: text.to_string(),
            odkazy: odkazy.to_vec(),
            mozna_odkazy: mozna_odkazy.to_vec(),
            dostupnost: dostupnost,
        }
    }
}

struct Statistika {
    chybi_odkaz: Vec<u32>,
    nedostupny: Vec<u32>,
    koncovy: Vec<u32>,
    prazdny: Vec<u32>,
    uvolnitelny: Vec<u32>,
    smrt: Vec<u32>,
    poznamka: Vec<u32>,
    boj: Vec<u32>,
    stesti: Vec<u32>,
}

impl Statistika {
    fn new() -> Self {
        Self {
            chybi_odkaz: vec![],
            nedostupny: vec![],
            koncovy: vec![],
            prazdny: vec![],
            uvolnitelny: vec![],
            smrt: vec![],
            poznamka: vec![],
            boj: vec![],        
            stesti: vec![],
        }
    }

    fn add_boj(&mut self, cislo: u32) {
        self.boj.push(cislo);
    }
    fn add_nedostupny(&mut self, cislo: u32) {
        self.nedostupny.push(cislo);
    }
    fn add_koncovy(&mut self, cislo: u32) {
        self.koncovy.push(cislo);
    }
    fn add_prazdny(&mut self, cislo: u32) {
        self.prazdny.push(cislo);
    }
    fn add_uvolnitelny(&mut self, cislo: u32) {
        self.uvolnitelny.push(cislo);
    }
    fn add_smrt(&mut self, cislo: u32) {
        self.smrt.push(cislo);
    }
    fn add_chybi_odkaz(&mut self, cislo: u32) {
        self.chybi_odkaz.push(cislo);
    }
    fn add_poznamka(&mut self, cislo: u32) {
        self.poznamka.push(cislo);
    }
    fn add_stesti(&mut self, cislo: u32) {
        self.stesti.push(cislo);
    }
}

struct Gamebook {
    graf_kapitol: Vec<Kapitola>,
    nazev: String,
    lang: String,
}

impl Gamebook {
    fn new() -> Self {
        let args: Vec<String> = env::args().collect();
        if args.len() < 2 {
            panic!("Chybí soubor ke zpracování.")
        }
        let nazev = &args[1];
        let lang = "cz";
        let kapitoly = Self::nacti_kapitoly_ze_souboru(nazev);
        let graf_kapitol = Self::vytvor_graf(&kapitoly);

        Self {
            graf_kapitol: graf_kapitol,
            nazev: nazev.to_string(),
            lang: lang,
        }
    }
    
    fn nacti_kapitoly_ze_souboru(soubor: &str) -> Vec<String> {
        let mut text: String = String::new();
        let mut kapitoly: Vec<String> = vec![];
        let mut cislo = 0;
    
        let chapter_number = Regex::new(r"(?m)^\W*##\W+(\d+)\W*$").unwrap();

        for line in read_to_string(soubor).unwrap().lines() {
            //panic!("Nemůžu načíst soubor: \(error)")
            let m = chapter_number.captures(line);
            if m.is_some() {
                kapitoly.push(text.to_string());

                text = String::new();
                cislo += 1;
                // zkontrolovat, ze cisla kapitol navazuji
                // TODO: vyresit lip unwrapy
                if m.unwrap().get(1).unwrap().as_str().parse::<u32>() != Ok(cislo) {
                    panic!("Chybí kapitola: {}.", cislo);
                }
            } else {
                text += line;
                text += "\n";
            }
        }

        kapitoly.push(text.to_string());
        kapitoly
    }
    
    // vytvor graf (seznam sousedu) z textu
    fn vytvor_graf(kapitoly: &[String]) -> Vec<Kapitola> {
        let mut graf_kapitol: Vec<Kapitola> = vec!();
        for (cislo, text) in kapitoly.iter().enumerate() {
            let odkazy_regex = Regex::new(r"\*\*(\d+)\*\*").unwrap();
            let mozna_regex = Regex::new(r"\*\*(\d+) ?\?\*\*").unwrap();
            /*
            // TODO: use filter_map
            let mut odkazy: Vec<u32> = vec!();
            for (_, [cislo_str]) in odkazy_regex.captures_iter(text).map(|cap| cap.extract()) {
                let cislo_odkazu = cislo_str.parse::<u32>().ok().expect("spatne cislo odkazu");
                odkazy.push(cislo_odkazu);
            }
            
            let mut odkazy: Vec<u32> = vec!();
            for i in odkazy_regex.captures_iter(text) {
                let (_, [cislo_str]) = i.extract();
                //println!("cislo str {cislo_str}");
                let cislo_odkazu = cislo_str.parse::<u32>().ok().expect("spatne cislo odkazu");
                odkazy.push(cislo_odkazu);
                // i.iter().filter_map(|c| c.as_str());
            }*/
            //let mozna_odkazy = mozna_regex.find_iter(text).filter_map( |odkaz| odkaz.as_str().parse::<u32>().ok()).collect::<Vec<u32>>();

            let odkazy: Vec<u32> = odkazy_regex.captures_iter(text).map(|cap| cap.extract()).map(|(_, [cislo_str])| cislo_str.parse::<u32>().unwrap()).collect();
            let mozna_odkazy: Vec<u32> = mozna_regex.captures_iter(text).map(|cap| cap.extract()).map(|(_, [cislo_str])| cislo_str.parse::<u32>().unwrap()).collect();
                    
            let kap = Kapitola::new(cislo as u32, text, &odkazy, &mozna_odkazy, false);
            graf_kapitol.push(kap);
        }
        Self::spocitej_dostupnost(&mut graf_kapitol);
        graf_kapitol
    }

    fn spocitej_dostupnost(graf_kapitol: &mut [Kapitola]) {
        let maxlen = graf_kapitol.len();
        // TODO: How to write this using iterators?
        for i in 0..graf_kapitol.len() {
            for odkaz in [graf_kapitol[i].odkazy.as_slice(), graf_kapitol[i].mozna_odkazy.as_slice()].concat() {
                if odkaz < 1 || odkaz >= maxlen as u32 {
                    panic!("Špatné číslo odkazu: {}. Musí být mezi 1 a {}.", odkaz, maxlen - 1)
                }
                graf_kapitol[odkaz as usize].dostupnost = true;
            }
        }
    }

    fn vykresli(&self, stat: &mut Statistika) {
        println!("digraph \"{}\" {{", self.nazev);

        for kap in self.graf_kapitol.iter() {
          // escape tooltip text
          let escaped_text = kap.text.replace("\"", "\\\"");
          // TODO: find a better way to interpolate strings
          let tooltip = "tooltip=\"".to_owned() + &escaped_text + "\"";
    
          // obarvit specialni odkazy
          Self::obarvi_uzel(kap, &tooltip, stat);
          Self::vykresli_odkazy(kap.cislo, &kap.odkazy, &kap.mozna_odkazy);
        }
    
        println!("}}");
    }
    
    fn vykresli_odkazy(cislo: u32, odkazy: &[u32], mozna_odkazy: &[u32]) {
        for odkaz in odkazy.iter() {
            println!("{cislo} -> {odkaz};")
        }
        for odkaz in mozna_odkazy.iter() {
            println!("{cislo} -> {odkaz} [style=dotted];")
        }
    }

    fn obarvi_uzel(kap: &Kapitola, tooltip: &str, stat: &mut Statistika) {
        // SVG colors: https://graphviz.org/doc/info/colors.html
        let barva_dvojita_hrana = " style=filled fillcolor=orange";
        let barva_chybi_odkaz = " style=filled fillcolor=lightgreen";
        let barva_nedostupny = " style=filled fillcolor=yellow";
        let barva_koncovy = " style=filled fillcolor=lightcoral";
        let barva_prazdny = " style=filled fillcolor=lightblue";
        let barva_uvolnitelny = " style=filled fillcolor=pink";
        let barva_smrt = " style=filled fillcolor=lightgrey";
        let barva_poznamka = " style=filled fillcolor=plum";
        let barva_pres400 = " style=filled fillcolor=aquamarine";
        let barva_uroven = " style=filled fillcolor=gold";

        let mut tvar = "";
        let mut barva = "";
    
        if obsahuje_boj(&kap.text) {
            stat.add_boj(kap.cislo);
            tvar = "shape = box";
        }
    
        // TODO: obarvit zkouseni stesti, posileni/ztraty UB/ST
    
        // obarvit dvojite hrany
        if dvojita_hrana(&kap.odkazy) {
            barva = barva_dvojita_hrana;
        }
    
        // obarvit koncovy stav
        if kap.odkazy.is_empty() && kap.mozna_odkazy.is_empty() {
            // smrti a prazdne nepovazovat za koncove
            if !prazdny_text(&kap.text) && !kap.text.contains("💀") {
                stat.add_koncovy(kap.cislo);
                barva = barva_koncovy;
            }
        }
    
        // obarvit nedostupne
        if !kap.dostupnost {
            stat.add_nedostupny(kap.cislo);
            barva = barva_nedostupny;
        }
    
        // obarvit prazdny
        if prazdny_text(&kap.text) {
            stat.add_prazdny(kap.cislo);
            barva = barva_prazdny;
        }
    
        // obarvit smrti
        if kap.text.contains("💀") {
            stat.add_smrt(kap.cislo);
            barva = barva_smrt;
        }
    
        // obarvit chybejici odkazy
        let chybejicich = chybejici_odkaz(&kap.text);
        if chybejicich > 0 {
            barva = barva_chybi_odkaz;
            // pridat odkaz tolikrat, kolik ma nedopsanych odkazu
            for _ in 0..chybejicich {
                stat.add_chybi_odkaz(kap.cislo);
            }
        }
    
        // obarvit uvolnitelne
        if mozna_uvolnitelny(&kap.text) {
            stat.add_uvolnitelny(kap.cislo);
            barva = barva_uvolnitelny;
        }
    
        // obarvit odkazy nad 400
        if pres_400(&[kap.odkazy.as_slice(), kap.mozna_odkazy.as_slice()].concat()) {
            barva = barva_pres400;
        }
    
        // obarvit poznamky
        if zmena_urovne(&kap.text) {
            //stat.add_uroven(kap.cislo);
            barva = barva_uroven;
        }

        // (zatim ne) obarvit pouziti stesti
        if pouziti_stesti(&kap.text) {
            stat.add_stesti(kap.cislo);
            //barva = barva_stesti;
        }
        
        // obarvit poznamky
        if obsahuje_poznamku(&kap.text) {
            stat.add_poznamka(kap.cislo);
            barva = barva_poznamka;
        }

        // vypis kapitolu pro dot
        println!("{} [{tooltip} {barva} {tvar}];", kap.cislo);
    }
}

// TODO: pouzit konstanty pro UB/ST, hodi se na moznost prekladu na AJ
fn obsahuje_boj(text: &str) -> bool {
    let re = Regex::new(r"(?m)^\s.*UMĚNÍ BOJE\s+\d+\s+STAMINA\s+\d+\s*$").unwrap();
    return re.is_match(text);
}
  
fn obsahuje_poznamku(text: &str) -> bool {
    let re = Regex::new(r"\(.*\)").unwrap();
    let info = Regex::new(r"INFO").unwrap();

    return re.is_match(text) || info.is_match(text);
}
  
fn prazdny_text(text: &str) -> bool {
    let re = Regex::new(r"(?m)\A\s*(EMPTY|VOLNO|VOLNE)*\s*\z").unwrap();
    return re.is_match(text);
}
  
fn mozna_uvolnitelny(text: &str) -> bool {
    let re = Regex::new(r"(?m)(EMPTY|VOLNO|VOLNE)\??\s*$").unwrap();
    return re.is_match(text);
}
  
fn pres_400(odkazy: &[u32]) -> bool {
    for cislo in odkazy.iter() { 
        if *cislo > 400 { return true; }
    }
    false
}
  
fn chybejici_odkaz(text: &str) -> u32 {
    let re = Regex::new(r"\*{4}").unwrap();
    let num_captures = re.captures_iter(text).count();
    num_captures as u32
}

fn dvojita_hrana(odkazy: &[u32]) -> bool {
    let set: HashSet<u32> = HashSet::from_iter(odkazy.iter().cloned());
    return set.len() != odkazy.len();
}

fn zmena_urovne(text: &str) -> bool {
    let re = Regex::new(r"si ÚROVEŇ o").unwrap();
    return re.is_match(text);
}

fn pouziti_stesti(text: &str) -> bool {
    let re = Regex::new(r"\*štěstí\*").unwrap();
    return re.is_match(text);
}

// accepts array of any type and prints the array or the size if too big
fn stat_puts<T: std::fmt::Debug>(popis: &str, seznam: &[T]) {
    // nevypisovat prazdne a prilis dlouhe seznamy
    if !seznam.is_empty() && seznam.len() < 100 {
        eprintln!(" {popis}: {} {seznam:?}", seznam.len());
    } else {
        eprintln!(" {popis}: {}", seznam.len());
    }
}

// prints a stat
fn stat_put_num(popis: &str, num: usize) {
    eprintln!(" {popis}: {}", num);
}
    
fn najdi_cestu(graf: &[Kapitola]) -> Vec<u32> {
    // projdi graf do cile (odkaz s nejvyssim cislem) a vrat seznam predchudcu
    let delka = (graf.len() - 1) as u32;
    let (predchudci, _) = bfs(graf, delka);

    if predchudci.is_empty() {
      println!("Cesta k cíli nenalezena! Nedokončeno nebo neuvedené skryté odkazy?");
      return vec!();
    }

    // zacnu poslednim odkazem a pujdu po predchudcich k zacatku
    let mut cislo = delka;
    let mut cesta = VecDeque::from([cislo]);

    // sestav cestu do cile
    // musi existovat, jinak by bfs vratilo prazdne predchudce
    while cislo != 1 {
      cislo = predchudci[cislo as usize];
      cesta.push_front(cislo);
    }

    Vec::from(cesta)
}

fn odkazu_pred(graf: &[Kapitola], cil: u32) -> Vec<u32> {
    // projdi graf a ziskej seznam navstivenych odkazu 
    let (_, navstivene) = bfs(graf, cil);
    navstivene
}

// projdi graf do ciloveho odkazu
fn bfs(graf: &[Kapitola], cil: u32) -> (Vec<u32>, Vec<u32>) {
    let mut navstivene: HashSet<u32> = vec![1].into_iter().collect();
    let mut fronta = VecDeque::from([1]);
    let mut predchudci: Vec<u32> = vec![0; graf.len()];
    let mut cislo: u32;

    // pridej odkazy z 1
    fronta.append(&mut VecDeque::from_iter(graf[1].odkazy.clone()));
    fronta.append(&mut VecDeque::from_iter(graf[1].mozna_odkazy.clone()));

    cislo = fronta.pop_front().unwrap_or(0);
    while cislo != 0 {
        // jsme v cili, hotovo
        if cislo == cil {
            //cislo = fronta.pop_front().unwrap_or(0);
            //continue
            return (predchudci, Vec::from_iter(navstivene)); 
        }

        // prozkoumam odkazy z aktualniho cisla
        let mut vsechny_odkazy = graf[cislo as usize].odkazy.clone();
        vsechny_odkazy.append(&mut graf[cislo as usize].mozna_odkazy.clone());
        for odkaz in vsechny_odkazy.iter() {
            if navstivene.contains(odkaz) { continue }
            navstivene.insert(*odkaz);
            predchudci[*odkaz as usize] = cislo;
            fronta.push_back(*odkaz);
        }
        cislo = fronta.pop_front().unwrap_or(0);
    }

    // nedoslo se do cile, vrat prazdnou cestu
    //return (predchudci, Vec::from_iter(navstivene)); 
    return (vec!(), vec!())
}

fn vypis_statistiky(graf: &[Kapitola], statistika: &Statistika) {
    let pocet = graf.len();
    let vse: HashSet<u32> = HashSet::from_iter((0..pocet).map(|num| num as u32));
    let prazdne: HashSet<u32> = statistika.prazdny.clone().into_iter().collect();
    let napsane: Vec<u32> = vse.difference(&prazdne).map(|i| *i).collect();
    let odkazu_celkem = graf.iter().fold(0, |acc, odkaz| acc + odkaz.odkazy.len() + odkaz.mozna_odkazy.len());
    let odkazu_pevnych = graf.iter().fold(0, |acc, odkaz| acc + odkaz.odkazy.len());
    let odkazu_skrytych = graf.iter().fold(0, |acc, odkaz| acc + odkaz.mozna_odkazy.len());

    stat_put_num("Kapitol celkem", pocet);
    stat_puts("Napsaných", &napsane);
    stat_puts("Prázdných", &statistika.prazdny);
    stat_puts("Nedopsaných", &statistika.chybi_odkaz);
    stat_puts("Nedostupných", &statistika.nedostupny);
    stat_puts("Koncových", &statistika.koncovy);
    stat_puts("Smrtí", &statistika.smrt);
    stat_puts("Uvolnitelných", &statistika.uvolnitelny);
    stat_puts("Poznámek", &statistika.poznamka);
    stat_puts("Bojů", &statistika.boj);
    stat_puts("Dodělaných kapitol", &odkazu_pred(graf, 174));
    stat_puts("Kapitol do draků", &odkazu_pred(graf, 283));
    stat_put_num("Odkazů celkem", odkazu_celkem);
    stat_put_num("Pevných odkazů", odkazu_pevnych);
    stat_put_num("Skrytých odkazů", odkazu_skrytych);
    stat_puts("Zkoušení štěstí", &statistika.stesti);
    stat_puts("Nejkratší cesta do cíle", &najdi_cestu(graf));
    stat_puts("Nejdelší cesta do cíle", &[] as &[u32]) // bfs neumi kruhy
}

fn main() {
    let kniha = Gamebook::new();
    let mut statistika = Statistika::new();
    kniha.vykresli(&mut statistika);
    vypis_statistiky(&kniha.graf_kapitol, &statistika);
}
