import 'package:flutter/material.dart';

import '../localization/kr_localizations.dart';
import '../services/local_save_service.dart';

/// The guides are independent and do not change game progression.
enum IdleTutorialSection { arena, cards, summon }

class IdleTutorialProgress {
  const IdleTutorialProgress(this.storage);
  final KeyValueStorage? storage;

  static String keyFor(IdleTutorialSection section) =>
      'idle-tutorial-${section.name}-v1';

  bool unseen(IdleTutorialSection section) =>
      storage != null && storage!.read(keyFor(section)) != 'seen';

  void complete(IdleTutorialSection section) =>
      storage?.write(keyFor(section), 'seen');
}

/// Localized labels are painted over the empty boxes in the supplied artwork,
/// so the same image can be used in all seven languages.
class IdleFirstVisitTutorial extends StatelessWidget {
  const IdleFirstVisitTutorial({
    super.key,
    required this.section,
    required this.onDone,
  });

  final IdleTutorialSection section;
  final VoidCallback onDone;

  static const _gold = Color(0xffffd78b);
  static const _baseWidth = 941.0;
  static const _baseHeight = 1672.0;

  String get imagePath => switch (section) {
    IdleTutorialSection.cards => 'assets/idle/tutorial/cards.webp',
    IdleTutorialSection.summon => 'assets/idle/tutorial/summon.webp',
    IdleTutorialSection.arena => 'assets/idle/tutorial/arena.webp',
  };

  String get title => switch (section) {
    IdleTutorialSection.cards => 'CARD STATISTICS',
    IdleTutorialSection.summon => 'SUMMON PORTALS',
    IdleTutorialSection.arena => 'ARENA BATTLES',
  };

  List<String> get explanations => switch (section) {
    IdleTutorialSection.cards => const [
      'Attack is the damage your card can deal in battle.',
      'Crit is the chance of landing a critical strike.',
      'HP is your card\'s health during a PvP battle.',
      'Skill is the card\'s special effect. Check its details before fighting.',
    ],
    IdleTutorialSection.summon => const [
      'Choose Standard, Featured, or Event to see the available summons.',
      'Standard costs 300 Shards or a free charge. Free charges renew over time.',
      'Featured and Event have different rewards and rates. Read INFO before spending.',
    ],
    IdleTutorialSection.arena => const [
      'Arena matches have up to three rounds. Win two rounds to win the match.',
      'Drag a card from your hand into YOUR CARD SLOT before the timer ends.',
      'Each card can be played only once per match. Plan your next round carefully.',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final texts = explanations.map(context.tr).toList();
    return Material(
      key: const Key('idle-first-visit-tutorial'),
      color: const Color(0xf5030919),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: _baseWidth,
                      height: _baseHeight,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.asset(
                              imagePath,
                              fit: BoxFit.fill,
                              errorBuilder: (_, __, ___) => DecoratedBox(
                                decoration: BoxDecoration(
                                  color: const Color(0xff10274a),
                                  border: Border.all(color: _gold, width: 3),
                                  borderRadius: BorderRadius.circular(32),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.auto_stories,
                                    size: 220,
                                    color: _gold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _text(
                            context.tr(title),
                            left: .18, top: .111, width: .71, height: .049,
                            size: 37, align: TextAlign.center,
                            bold: true,
                          ),
                          if (section == IdleTutorialSection.cards) ...[
                            for (var index = 0; index < 4; index++)
                              _text(
                                texts[index],
                                left: .28, top: [.545, .639, .738, .839][index],
                                width: .665,
                                height: index == 3 ? .09 : .075,
                                size: 27,
                              ),
                          ] else if (section == IdleTutorialSection.summon) ...[
                            for (var index = 0; index < 3; index++)
                              _text(
                                texts[index],
                                left: .156, top: [.793, .844, .898][index],
                                width: .75, height: .052, size: 27,
                              ),
                          ] else ...[
                            for (var index = 0; index < 3; index++)
                              _text(
                                texts[index],
                                left: .166, top: [.787, .835, .884][index],
                                width: .76, height: .05, size: 24,
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      key: const Key('idle-tutorial-done'),
                      onPressed: onDone,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xffd4a353),
                        foregroundColor: const Color(0xff101a30),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16,
                        ),
                      ),
                      child: Text(context.tr('GOT IT')),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _text(
    String value, {
    required double left,
    required double top,
    required double width,
    required double height,
    required double size,
    TextAlign align = TextAlign.left,
    bool bold = false,
  }) => Positioned(
    left: _baseWidth * left,
    top: _baseHeight * top,
    width: _baseWidth * width,
    height: _baseHeight * height,
    child: Align(
      alignment: align == TextAlign.center
          ? Alignment.center
          : Alignment.centerLeft,
      child: Text(
        value,
        textAlign: align,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: _gold,
          fontSize: size,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          height: 1.16,
          shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
        ),
      ),
    ),
  );
}
