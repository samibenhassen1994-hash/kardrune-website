import 'package:flutter/material.dart';

import '../../game/catalog.dart';
import '../../game/deck_rules.dart';
import '../../game/combat_rules.dart';
import '../../game/skill_catalog.dart';
import '../../theme/kardrune_theme.dart';
import 'card_stat_badges.dart';
import 'skill_preview.dart';

class DeckBuilder extends StatefulWidget {
  const DeckBuilder({
    super.key,
    required this.owned,
    required this.initial,
    required this.onSave,
    this.attacks = const {},
    this.crits = const {},
    this.skills = const {},
  });
  final List<String> owned, initial;
  final Map<String,int> attacks, crits;
  final Map<String,String> skills;
  final ValueChanged<List<String>> onSave;
  @override
  State<DeckBuilder> createState() => _DeckBuilderState();
}

class _DeckBuilderState extends State<DeckBuilder> {
  late List<String?> slots;
  int? hover;
  @override
  void initState() {
    super.initState();
    slots = DeckRules.normalize(widget.initial, widget.owned);
  }

  void put(String id, int? index) =>
      setState(() => slots = DeckRules.put(slots, id, index, widget.owned));
  String asset(String id) {
    final parts = id.split(':');
    final hero = KardRuneCatalog.heroes.firstWhere((h) => h.id == parts[0]);
    return hero.cardAsset(hero.stages[int.parse(parts[1]) - 1]);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Container(
    decoration: const BoxDecoration(
      gradient: RadialGradient(center: Alignment(0, -.8), colors: [Color(0xff253b60), Color(0xff0c1528)]),
    ),
    child: Padding(
    padding: const EdgeInsets.all(8),
    child: Column(
      children: [
        const Text(
          'PVP LOADOUT · MY DECK',
          style: TextStyle(
            color: KardRuneTheme.gold,
            fontFamily: 'Georgia',
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            childAspectRatio: 1.45,
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
            children: [
              for (var index = 0; index < 9; index++)
                DragTarget<String>(
                  key: ValueKey('deck-slot-$index'),
                  onWillAcceptWithDetails: (_) {
                    setState(() => hover = index);
                    return true;
                  },
                  onLeave: (_) => setState(() => hover = null),
                  onAcceptWithDetails: (details) {
                    put(details.data, index);
                    setState(() => hover = null);
                  },
                  builder: (context, candidates, rejected) => AnimatedContainer(
                    key: const Key('deck-slot'),
                    duration: reduced ? Duration.zero : const Duration(milliseconds: 160),
                    decoration: BoxDecoration(
                      color: hover == index
                          ? Colors.blue.withValues(alpha: .35)
                          : const Color(0x66153b66),
                      border: Border.all(
                        color: hover == index
                            ? Colors.lightBlueAccent
                            : KardRuneTheme.gold,
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: slots[index] == null
                        ? Center(child: Text('${index + 1}'.padLeft(2, '0')))
                        : _draggable(
                            slots[index]!,
                            onTap: () => setState(
                              () => slots = DeckRules.remove(
                                slots,
                                index,
                                widget.owned,
                              ),
                            ),
                            slot: true,
                          ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.owned.length,
            separatorBuilder: (context, index) => const SizedBox(width: 6),
            itemBuilder: (context, index) => SizedBox(
              width: 64,
              child: _draggable(
                widget.owned[index],
                onTap: () => put(widget.owned[index], null),
                slot: false,
              ),
            ),
          ),
        ),
        GestureDetector(
          key: const Key('save-deck'),
          onTap: () => widget.onSave(slots.whereType<String>().toList()),
          child: Container(
            width: double.infinity,
            height: 45,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xfff8dd9d), Color(0xffbc8a3b)]),
              border: Border.all(color: const Color(0x9cf6dd9b)),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Text('SAVE DECK', style: TextStyle(color: Color(0xff251a0c), fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    ),
  ),
  );
  }
  Widget _draggable(
    String id, {
    required VoidCallback onTap,
    required bool slot,
  }) {
    final stage = int.parse(id.split(':').last);
    final image = CharacterCardArt(asset: asset(id),hp:CombatRules.hpForStage(stage),
      attack:widget.attacks[id],crit:widget.crits[id],skillId:widget.skills[id],compact:true);
    return Draggable<String>(
      data: id,
      feedback: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          key: const Key('deck-drag-feedback'),
          width: 72,
          height: 98,
          child: CharacterCardArt(asset: asset(id),hp:CombatRules.hpForStage(stage),
            attack:widget.attacks[id],crit:widget.crits[id],skillId:widget.skills[id],compact:true),
        ),
      ),
      childWhenDragging: Opacity(opacity: .25, child: image),
      child: InkWell(
        key: slot ? Key('slot-card-$id') : Key('inventory-$id'),
        onTap: () => _inspect(id),
        onDoubleTap: onTap,
        child: image,
      ),
    );
  }

  void _inspect(String id) {
    final skill = SkillCatalog.byId(widget.skills[id]);
    final stage = int.parse(id.split(':').last);
    showDialog<void>(context:context,builder:(dialogContext)=>Dialog(
      backgroundColor:const Color(0xff111e35),
      child:SizedBox(width:350,height:MediaQuery.sizeOf(context).height*.75,
        child:SingleChildScrollView(padding:const EdgeInsets.all(14),child:Column(children:[
          SizedBox(height:240,child:CharacterCardArt(asset:asset(id),
            hp:CombatRules.hpForStage(stage),attack:widget.attacks[id],
            crit:widget.crits[id],skillId:widget.skills[id])),
          Text(id.toUpperCase(),style:const TextStyle(color:KardRuneTheme.gold,fontWeight:FontWeight.w900)),
          if(skill!=null)...[
            Text('${skill.name.toUpperCase()} · ${skill.rarity.toUpperCase()}',
              style:TextStyle(color:skill.color,fontWeight:FontWeight.w900)),
            Text(skill.description,textAlign:TextAlign.center),
            Text('${skill.trigger} · ${skill.limit}',textAlign:TextAlign.center),
            SkillPreviewButton(skill:skill),
          ],
          TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('CLOSE')),
        ])))));
  }
}
