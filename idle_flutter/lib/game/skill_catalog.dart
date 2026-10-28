// GENERATED from shared/skill_catalog.js. Run node tool/generate_skill_catalog.mjs.
import 'package:flutter/material.dart';

class SkillDefinition {
  const SkillDefinition({required this.id, required this.name, required this.rarity, required this.description, required this.trigger, required this.limit, required this.vfx});
  final String id, name, rarity, description, trigger, limit, vfx;
  int get version => SkillCatalog.version;
  Color get color => switch (rarity) {
    'common' => const Color(0xffaeb6c4),
    'uncommon' => const Color(0xff35d98a),
    'rare' => const Color(0xff4da6ff),
    'epic' => const Color(0xffb76cff),
    'legendary' => const Color(0xffff4d5e),
    _ => const Color(0xffffd767),
  };
}

abstract final class SkillCatalog {
  static const version = 1;
  static const rarities = ['common', 'uncommon', 'rare', 'epic', 'legendary', 'ultra'];
  // Weights are parts per 1,000; each stage sums to exactly 1,000.
  static const weights = <int, List<int>>{
    1: [550, 270, 120, 50, 8, 2],
    2: [0, 600, 280, 100, 15, 5],
    3: [0, 0, 700, 230, 60, 10],
  };
  static const skills = <SkillDefinition>[
    SkillDefinition(id: "C1", name: "Colpo preciso", rarity: "common", description: "Il primo attacco diretto infligge +8 danni.", trigger: "Primo attacco", limit: "Una volta per duello", vfx: "slash"),
    SkillDefinition(id: "C2", name: "Pelle dura", rarity: "common", description: "Riduce di 8 il primo danno diretto ricevuto.", trigger: "Primo colpo subito", limit: "Una carica", vfx: "shield"),
    SkillDefinition(id: "C3", name: "Resistenza", rarity: "common", description: "Inizia il duello con +15 HP massimi e attuali.", trigger: "Inizio duello", limit: "Passiva", vfx: "shield"),
    SkillDefinition(id: "C4", name: "Tenacia", rarity: "common", description: "Sotto il 50% HP, il prossimo colpo infligge +10 danni.", trigger: "Prima volta sotto metà HP", limit: "Una volta", vfx: "power"),
    SkillDefinition(id: "C5", name: "Mira stabile", rarity: "common", description: "+3 punti percentuali al CRIT effettivo, fino al 25%.", trigger: "Sempre attiva", limit: "Passiva", vfx: "power"),
    SkillDefinition(id: "N1", name: "Furia", rarity: "uncommon", description: "Sotto il 50% HP, gli attacchi diretti infliggono +15% danni.", trigger: "Ogni attacco sotto metà HP", limit: "Finché la condizione vale", vfx: "power"),
    SkillDefinition(id: "N2", name: "Veleno", rarity: "uncommon", description: "Il primo colpo riuscito applica 6 danni per 2 azioni nemiche.", trigger: "Primo colpo riuscito", limit: "2 tick; non si riapplica", vfx: "poison"),
    SkillDefinition(id: "N3", name: "Ripicca", rarity: "uncommon", description: "Alla prima perdita di HP diretta restituisce 15 danni.", trigger: "Primo danno diretto subito", limit: "Una reazione", vfx: "counter"),
    SkillDefinition(id: "N4", name: "Meditazione", rarity: "uncommon", description: "Dopo il terzo attacco recupera 20 HP, senza superare il massimo.", trigger: "Terzo attacco proprio", limit: "Una volta", vfx: "heal"),
    SkillDefinition(id: "N5", name: "Colpo indebolente", rarity: "uncommon", description: "Il primo colpo riuscito riduce ATK nemico del 10% per 2 attacchi.", trigger: "Primo colpo riuscito", limit: "2 attacchi nemici", vfx: "curse"),
    SkillDefinition(id: "R1", name: "Vampirismo", rarity: "rare", description: "Recupera il 12% del danno diretto effettivamente inflitto.", trigger: "Ogni colpo diretto", limit: "HP massimi", vfx: "heal"),
    SkillDefinition(id: "R2", name: "Schivata", rarity: "rare", description: "25% di probabilità di annullare un colpo diretto.", trigger: "Colpo diretto in arrivo", limit: "Un proc per duello", vfx: "dodge"),
    SkillDefinition(id: "R3", name: "Scudo arcano", rarity: "rare", description: "Riduce del 40% il primo danno diretto ricevuto.", trigger: "Primo colpo non schivato", limit: "Una carica", vfx: "shield"),
    SkillDefinition(id: "R4", name: "Sanguinamento", rarity: "rare", description: "Il primo CRIT riuscito applica 12 danni per 2 azioni nemiche.", trigger: "Primo CRIT riuscito", limit: "2 tick; max 24", vfx: "bleed"),
    SkillDefinition(id: "R5", name: "Punizione", rarity: "rare", description: "Se il nemico ha più HP attuali, infligge +20% danni diretti.", trigger: "Prima del colpo", limit: "Finché la condizione vale", vfx: "power"),
    SkillDefinition(id: "E1", name: "Doppio colpo", rarity: "epic", description: "35% di probabilità di un secondo colpo al 50% di ATK.", trigger: "Attacco diretto", limit: "Un proc; colpo extra non critico", vfx: "double"),
    SkillDefinition(id: "E2", name: "Barriera runica", rarity: "epic", description: "Riduce del 30% i primi 2 danni diretti ricevuti.", trigger: "Colpo diretto in arrivo", limit: "2 cariche", vfx: "shield"),
    SkillDefinition(id: "E3", name: "Ritorsione", rarity: "epic", description: "Dopo il primo CRIT subito, il prossimo attacco è CRIT garantito.", trigger: "Primo CRIT subito", limit: "Una volta", vfx: "counter"),
    SkillDefinition(id: "E4", name: "Spaccascudi", rarity: "epic", description: "Il primo attacco infligge +20% danni e ignora gli scudi.", trigger: "Primo attacco", limit: "Una volta; non ignora Schivata", vfx: "break"),
    SkillDefinition(id: "E5", name: "Carica Arcana", rarity: "epic", description: "Ogni colpo non critico carica +10 danni, fino a +30; scarica su CRIT o quinto attacco.", trigger: "Colpi non critici", limit: "Una scarica per duello", vfx: "magic"),
    SkillDefinition(id: "L1", name: "Maledizione eterna", rarity: "legendary", description: "Il primo colpo riuscito riduce ATK base nemico del 25% per il duello.", trigger: "Primo colpo riuscito", limit: "Non cumulabile", vfx: "curse"),
    SkillDefinition(id: "L2", name: "Esecuzione", rarity: "legendary", description: "Contro nemici sotto 30% HP massimi, un attacco infligge +50% danni.", trigger: "Bersaglio sotto 30% HP", limit: "Una volta", vfx: "execute"),
    SkillDefinition(id: "L3", name: "Sigillo del Silenzio", rarity: "legendary", description: "Il primo colpo riuscito sopprime le skill attivabili per 2 azioni nemiche.", trigger: "Primo colpo riuscito", limit: "2 azioni; passivi e DoT persistono", vfx: "silence"),
    SkillDefinition(id: "L4", name: "Sabotaggio", rarity: "legendary", description: "Il primo colpo riuscito riduce il CRIT nemico di 10 punti.", trigger: "Primo colpo riuscito", limit: "Resto del duello; minimo 0%", vfx: "curse"),
    SkillDefinition(id: "L5", name: "Congelamento", rarity: "legendary", description: "Il primo CRIT riuscito salta il prossimo attacco nemico; altrimenti il quarto colpo riuscito.", trigger: "CRIT o quarto colpo riuscito", limit: "Un salto per duello", vfx: "freeze"),
    SkillDefinition(id: "U1", name: "Tempesta runica", rarity: "ultra", description: "Ogni terzo attacco aggiunge un colpo non critico al 70% di ATK.", trigger: "Ogni terzo attacco", limit: "2 attivazioni; no catene", vfx: "storm"),
    SkillDefinition(id: "U2", name: "Destino", rarity: "ultra", description: "Annulla il primo CRIT nemico e contrattacca con il 100% di ATK.", trigger: "Primo CRIT nemico", limit: "Una volta; contrattacco non critico", vfx: "counter"),
    SkillDefinition(id: "U3", name: "Fiamma cosmica", rarity: "ultra", description: "Il primo colpo applica bruciatura del 10% HP massimi per 3 azioni.", trigger: "Primo colpo riuscito", limit: "Max 35 per tick; 3 tick", vfx: "burn"),
    SkillDefinition(id: "U4", name: "Scudo divino", rarity: "ultra", description: "Riduce del 60% i primi 2 danni diretti ricevuti.", trigger: "Colpo diretto in arrivo", limit: "2 cariche", vfx: "shield"),
    SkillDefinition(id: "U5", name: "Ascensione", rarity: "ultra", description: "Dopo ogni attacco, ATK cresce del 15% fino a +60%.", trigger: "Fine di ogni attacco", limit: "4 stack; fino a fine duello", vfx: "ascend"),
  ];
  static SkillDefinition? byId(String? id) {
    for (final skill in skills) { if (skill.id == id) return skill; }
    return null;
  }
  static bool validForStage(String? id, int stage) {
    final skill = byId(id);
    if (skill == null || stage < 1 || stage > 3) return false;
    return rarities.indexOf(skill.rarity) >= stage - 1;
  }
  static SkillDefinition roll(int stage, double rarityRoll, double skillRoll) {
    final table = weights[stage] ?? weights[1]!;
    var ticket = (rarityRoll.clamp(0.0, .999999999) * 1000).floor();
    var rarity = 0;
    while (rarity < 5 && ticket >= table[rarity]) {
      ticket -= table[rarity];
      rarity++;
    }
    final options = skills.where((s) => s.rarity == rarities[rarity]).toList();
    return options[(skillRoll.clamp(0.0, .999999999) * 5).floor()];
  }
}
