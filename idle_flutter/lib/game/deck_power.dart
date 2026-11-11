import 'card_stat_limits.dart';
import 'skill_catalog.dart';
/// Display-only deck rating, never a combat or matchmaking input.
abstract final class DeckPower {
 static int calculate(Iterable<String> deck,Iterable<String> owned,Map<String,int> attacks,Map<String,int> crits,Map<String,String> skills){
  var total=0;
  for(final id in deck.toSet().where(owned.contains).take(9)){
   if(!RegExp(r'^(sam|lira|rhea|dren|tor|aria|kael|neris|nyra):[123]$|^(zeus|poseidon|hades|athena|ares|apollo):3.hasMatch(id))continue;
   final stage=int.parse(id.split(':').last),range=CardStatLimits.forStage(int.parse(id.split(':').last));
   final stats=CardStatLimits.effective(stage,attacks[id]??range.minAttack,crits[id]??range.minCrit);
   final skill=SkillCatalog.byId(skills[id]);
   final rank=skill==null?-1:SkillCatalog.rarities.indexOf(skill.rarity);
   final bonus=rank>=stage-1?const [10,20,35,50,75,100][rank]:0;
   total+=stage*100+(stats.attack*(100+stats.crit)+50)~/100+bonus;
  }
  return total;
 }
}

).hasMatch(id))continue;
   final stage=int.parse(id.split(':').last),range=CardStatLimits.forStage(int.parse(id.split(':').last));
   final stats=CardStatLimits.effective(stage,attacks[id]??range.minAttack,crits[id]??range.minCrit);
   final skill=SkillCatalog.byId(skills[id]);
   final rank=skill==null?-1:SkillCatalog.rarities.indexOf(skill.rarity);
   final bonus=rank>=stage-1?const [10,20,35,50,75,100][rank]:0;
   total+=stage*100+(stats.attack*(100+stats.crit)+50)~/100+bonus;
  }
  return total;
 }
}

