import 'package:flutter/material.dart';

import '../../game/catalog.dart';
import '../../game/deck_rules.dart';
import '../../theme/kardrune_theme.dart';

class DeckBuilder extends StatefulWidget {
  const DeckBuilder({
    super.key,
    required this.owned,
    required this.initial,
    required this.onSave,
  });
  final List<String> owned, initial;
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: Column(
      children: [
        const Text(
          'MY DECK · 1–9 CARDS',
          style: TextStyle(
            color: KardRuneTheme.gold,
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
                    duration: const Duration(milliseconds: 160),
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
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => widget.onSave(slots.whereType<String>().toList()),
            child: const Text('SAVE DECK'),
          ),
        ),
      ],
    ),
  );
  Widget _draggable(
    String id, {
    required VoidCallback onTap,
    required bool slot,
  }) {
    final image = Image.asset(asset(id), fit: BoxFit.contain);
    return Draggable<String>(
      data: id,
      feedback: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          key: const Key('deck-drag-feedback'),
          width: 72,
          height: 98,
          child: Image.asset(asset(id), fit: BoxFit.contain),
        ),
      ),
      childWhenDragging: Opacity(opacity: .25, child: image),
      child: InkWell(
        key: slot ? Key('slot-card-$id') : Key('inventory-$id'),
        onTap: onTap,
        child: image,
      ),
    );
  }
}
