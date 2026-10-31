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
    this.italian = false,
    this.attacks = const {},
    this.crits = const {},
    this.skills = const {},
  });
  final List<String> owned, initial;
  final bool italian;
  final Map<String, int> attacks, crits;
  final Map<String, String> skills;
  final ValueChanged<List<String>> onSave;
  @override
  State<DeckBuilder> createState() => _DeckBuilderState();
}

class _DeckBuilderState extends State<DeckBuilder> {
  late List<String?> slots;
  late final List<String?> _initialSlots;
  final ScrollController _ownedScroll = ScrollController();
  int? hover;
  bool _allowExit = false, _showingExitPrompt = false;
  String _searchText = '',
      _filterStage = 'all',
      _filterRarity = 'all',
      _filterSkill = 'all',
      _sortCards = 'default';
  bool _onlyDeckCards = false;

  String _t(String it, String en) => widget.italian ? it : en;
  bool get _hasUnsavedChanges => List.generate(
    DeckRules.size,
    (i) => slots[i] != _initialSlots[i],
  ).contains(true);

  bool get _hasActiveFilters =>
      _searchText.isNotEmpty ||
      _filterStage != 'all' ||
      _filterRarity != 'all' ||
      _filterSkill != 'all' ||
      _sortCards != 'default' ||
      _onlyDeckCards;

  List<String> _visibleCards() {
    final search = _searchText.trim().toLowerCase();
    final filtered = widget.owned.where((id) {
      final parts = id.split(':');
      final skill = SkillCatalog.byId(widget.skills[id]);
      if (_filterStage != 'all' && parts.last != _filterStage) return false;
      if (_filterRarity != 'all' && skill?.rarity != _filterRarity) {
        return false;
      }
      if (_filterSkill != 'all' && skill?.id != _filterSkill) return false;
      if (_onlyDeckCards && !slots.contains(id)) return false;
      if (search.isEmpty) return true;
      final hero = KardRuneCatalog.heroes.firstWhere(
        (item) => item.id == parts.first,
      );
      return hero.name.toLowerCase().contains(search) ||
          (skill?.name.toLowerCase().contains(search) ?? false) ||
          (skill?.description.toLowerCase().contains(search) ?? false);
    }).toList();
    switch (_sortCards) {
      case 'attack':
        filtered.sort(
          (a, b) =>
              (widget.attacks[b] ?? -1).compareTo(widget.attacks[a] ?? -1),
        );
      case 'crit':
        filtered.sort(
          (a, b) => (widget.crits[b] ?? -1).compareTo(widget.crits[a] ?? -1),
        );
      case 'rarity':
        filtered.sort((a, b) {
          final rankA = SkillCatalog.rarities.indexOf(
            SkillCatalog.byId(widget.skills[a])?.rarity ?? '',
          );
          final rankB = SkillCatalog.rarities.indexOf(
            SkillCatalog.byId(widget.skills[b])?.rarity ?? '',
          );
          return rankB.compareTo(rankA);
        });
      case 'stage':
        filtered.sort(
          (a, b) =>
              int.parse(b.split(':').last)
                  .compareTo(int.parse(a.split(':').last)),
        );
      case 'name':
        filtered.sort((a, b) => a.compareTo(b));
    }
    return filtered;
  }

  Widget _filterSelect(
    String label,
    String value,
    List<(String, String)> options,
    ValueChanged<String> changed,
  ) => Row(
    children: [
      SizedBox(
        width: 78,
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xfff5d28b),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      Expanded(
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: value,
            dropdownColor: const Color(0xff1b2c48),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            items: [
              for (final option in options)
                DropdownMenuItem(
                  value: option.$1,
                  child: Text(
                    option.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (next) {
              if (next != null) changed(next);
            },
          ),
        ),
      ),
    ],
  );

  Future<void> _openFilters() async {
    final search = TextEditingController(text: _searchText);
    var stage = _filterStage,
        rarity = _filterRarity,
        skillId = _filterSkill,
        order = _sortCards;
    var onlyDeck = _onlyDeckCards;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: const Color(0xff111f38),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, sheetSetState) => Padding(
            padding: EdgeInsets.fromLTRB(
              17,
              12,
              17,
              14 + MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _t('FILTRA LE CARTE', 'FILTER CARDS'),
                          style: const TextStyle(
                            color: KardRuneTheme.gold,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: _t('Chiudi', 'Close'),
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                  TextField(
                    key: const Key('deck-filter-search'),
                    controller: search,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.search,
                        color: KardRuneTheme.gold,
                      ),
                      hintText: _t(
                        'Cerca personaggio o abilità',
                        'Search hero or skill',
                      ),
                      hintStyle: const TextStyle(color: Color(0xffa8b6cc)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 7),
                  _filterSelect('STAGE', stage, const [
                    ('all', 'TUTTI / ALL'),
                    ('1', 'STAGE 1'),
                    ('2', 'STAGE 2'),
                    ('3', 'STAGE 3'),
                  ], (value) => sheetSetState(() => stage = value)),
                  _filterSelect(
                    _t('RARITÀ', 'RARITY'),
                    rarity,
                    [
                      ('all', _t('TUTTE', 'ALL')),
                      ('common', _t('COMUNE', 'COMMON')),
                      ('uncommon', _t('NON COMUNE', 'UNCOMMON')),
                      ('rare', _t('RARA', 'RARE')),
                      ('epic', _t('EPICA', 'EPIC')),
                      ('legendary', _t('LEGGENDARIA', 'LEGENDARY')),
                      ('ultra', 'ULTRA'),
                    ],
                    (value) => sheetSetState(() {
                      rarity = value;
                      skillId = 'all';
                    }),
                  ),
                  _filterSelect(_t('ABILITÀ', 'SKILL'), skillId, [
                    ('all', _t('TUTTE', 'ALL')),
                    for (final skill in SkillCatalog.skills)
                      if (rarity == 'all' || skill.rarity == rarity)
                        (skill.id, skill.name.toUpperCase()),
                  ], (value) => sheetSetState(() => skillId = value)),
                  _filterSelect(_t('ORDINA', 'SORT'), order, [
                    ('default', _t('PREDEFINITO', 'DEFAULT')),
                    ('attack', 'ATK ↓'),
                    ('crit', 'CRIT ↓'),
                    ('rarity', _t('RARITÀ ↓', 'RARITY ↓')),
                    ('stage', 'STAGE ↓'),
                    ('name', _t('NOME A–Z', 'NAME A–Z')),
                  ], (value) => sheetSetState(() => order = value)),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: KardRuneTheme.gold,
                    title: Text(
                      _t('Solo carte nel mazzo', 'Only cards in deck'),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    value: onlyDeck,
                    onChanged: (value) =>
                        sheetSetState(() => onlyDeck = value ?? false),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => sheetSetState(() {
                            search.clear();
                            stage = 'all';
                            rarity = 'all';
                            skillId = 'all';
                            order = 'default';
                            onlyDeck = false;
                          }),
                          child: Text(_t('AZZERA', 'RESET')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          key: const Key('deck-filter-apply'),
                          onPressed: () {
                            setState(() {
                              _searchText = search.text.trim();
                              _filterStage = stage;
                              _filterRarity = rarity;
                              _filterSkill = skillId;
                              _sortCards = order;
                              _onlyDeckCards = onlyDeck;
                            });
                            if (_ownedScroll.hasClients) {
                              _ownedScroll.jumpTo(0);
                            }
                            Navigator.pop(sheetContext);
                          },
                          child: Text(_t('APPLICA', 'APPLY')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } finally {
      search.dispose();
    }
  }

  Future<void> _confirmUnsavedExit() async {
    if (_showingExitPrompt) return;
    _showingExitPrompt = true;
    try {
      final choice = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xff14243e),
          title: Text(
            _t('Modifiche non salvate', 'Unsaved changes'),
            style: const TextStyle(color: KardRuneTheme.gold),
          ),
          content: Text(
            _t(
              'Hai modificato il mazzo. Vuoi salvarlo prima di uscire?',
              'Your deck has changed. Save before leaving?',
            ),
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              key: const Key('deck-exit-cancel'),
              onPressed: () => Navigator.pop(dialogContext, 'cancel'),
              child: Text(_t('ANNULLA', 'CANCEL')),
            ),
            TextButton(
              key: const Key('deck-exit-discard'),
              onPressed: () => Navigator.pop(dialogContext, 'discard'),
              child: Text(_t('ESCI SENZA SALVARE', 'DISCARD')),
            ),
            ElevatedButton(
              key: const Key('deck-exit-save'),
              onPressed: () => Navigator.pop(dialogContext, 'save'),
              child: Text(_t('SALVA', 'SAVE')),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (choice == 'save') {
        _saveDeck();
      } else if (choice == 'discard') {
        setState(() => _allowExit = true);
        Navigator.of(context).pop();
      }
    } finally {
      _showingExitPrompt = false;
    }
  }

  void _saveDeck() {
    _allowExit = true;
    widget.onSave(slots.whereType<String>().toList());
  }

  void _removeSlot(int index) =>
      setState(() => slots = DeckRules.remove(slots, index, widget.owned));

  void _clearDeck() =>
      setState(() => slots = List<String?>.filled(DeckRules.size, null));

  void _autoDeck() => setState(() {
    final selected = DeckRules.auto(widget.owned, widget.attacks);
    slots = DeckRules.normalize(selected, widget.owned);
  });

  void _toggleCard(String id) {
    final index = slots.indexOf(id);
    if (index >= 0) {
      _removeSlot(index);
    } else {
      _addToDeck(id);
    }
  }

  void _addToDeck(String id) {
    if (slots.contains(id)) return;
    if (!slots.contains(null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Il mazzo è pieno. Rimuovi una carta.',
              'Deck full. Remove a card first.',
            ),
          ),
        ),
      );
      return;
    }
    put(id, null);
  }

  @override
  void initState() {
    super.initState();
    slots = DeckRules.normalize(widget.initial, widget.owned);
    _initialSlots = List<String?>.of(slots);
  }

  @override
  void dispose() {
    _ownedScroll.dispose();
    super.dispose();
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
    final visibleCards = _visibleCards();
    return PopScope<void>(
      canPop: !_hasUnsavedChanges || _allowExit,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _hasUnsavedChanges) _confirmUnsavedExit();
      },
      child: LayoutBuilder(
        builder: (context, limits) {
          final slotsHeight = (limits.maxHeight * .44).clamp(188.0, 415.0);
          final cardColumns = limits.maxWidth >= 650 ? 4 : 2;
          return Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -.8),
                colors: [Color(0xff253b60), Color(0xff0c1528)],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_t('MAZZO PVP', 'PVP DECK')}  ${slots.whereType<String>().length}/9',
                          style: const TextStyle(
                            color: KardRuneTheme.gold,
                            fontFamily: 'Georgia',
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('auto-deck'),
                        tooltip: _t('Mazzo automatico', 'Auto Deck'),
                        onPressed: widget.owned.isEmpty ? null : _autoDeck,
                        icon: const Icon(Icons.auto_awesome, size: 20),
                        color: const Color(0xffffd58b),
                      ),
                      TextButton.icon(
                        key: const Key('clear-deck'),
                        onPressed: slots.any((id) => id != null)
                            ? _clearDeck
                            : null,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: Text(_t('SVUOTA TUTTO', 'CLEAR ALL')),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xffffbdac),
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: slotsHeight,
                    child: GridView.builder(
                      key: const Key('deck-slots-grid'),
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisExtent: (slotsHeight - 10) / 3,
                        mainAxisSpacing: 5,
                        crossAxisSpacing: 5,
                      ),
                      itemCount: DeckRules.size,
                      itemBuilder: (context, index) {
                        final id = slots[index];
                        return DragTarget<String>(
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
                          builder: (context, candidates, rejected) =>
                              AnimatedContainer(
                                key: const Key('deck-slot'),
                                duration: reduced
                                    ? Duration.zero
                                    : const Duration(milliseconds: 160),
                                decoration: BoxDecoration(
                                  color: hover == index
                                      ? Colors.blue.withValues(alpha: .35)
                                      : const Color(0x66153b66),
                                  border: Border.all(
                                    color: hover == index
                                        ? Colors.lightBlueAccent
                                        : KardRuneTheme.gold,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: id == null
                                    ? Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.add_circle_outline,
                                            color: KardRuneTheme.gold,
                                            size: 20,
                                          ),
                                          Text(
                                            'SLOT ${index + 1}',
                                            style: const TextStyle(
                                              color: Color(0xffffd993),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          _draggable(
                                            id,
                                            onTap: () => _removeSlot(index),
                                            slot: true,
                                          ),
                                          Positioned(
                                            top: 1,
                                            right: 1,
                                            child: InkWell(
                                              key: Key(
                                                'remove-deck-slot-$index',
                                              ),
                                              onTap: () => _removeSlot(index),
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  2,
                                                ),
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Color(0xe0a53b45),
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 15,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _t('LE TUE CARTE', 'YOUR CARDS'),
                          style: const TextStyle(
                            color: KardRuneTheme.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .7,
                          ),
                        ),
                      ),
                      Text(
                        '${visibleCards.length}/${widget.owned.length} ${_t('CARTE', 'CARDS')}',
                        style: const TextStyle(
                          color: Color(0xffb9c9dd),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        key: const Key('deck-filter-open'),
                        tooltip: _t('Filtra carte', 'Filter cards'),
                        onPressed: _openFilters,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 34,
                        ),
                        icon: Icon(
                          Icons.tune,
                          color: _hasActiveFilters
                              ? const Color(0xffffd58b)
                              : const Color(0xffb9c9dd),
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Scrollbar(
                      controller: _ownedScroll,
                      thumbVisibility: true,
                      child: GridView.builder(
                        controller: _ownedScroll,
                        key: const Key('deck-owned-scroll-grid'),
                        padding: const EdgeInsets.fromLTRB(2, 2, 9, 14),
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cardColumns,
                          childAspectRatio: .73,
                          mainAxisSpacing: 9,
                          crossAxisSpacing: 9,
                        ),
                        itemCount: visibleCards.length,
                        itemBuilder: (context, index) {
                          final id = visibleCards[index];
                          final hero = KardRuneCatalog.heroes.firstWhere(
                            (h) => h.id == id.split(':').first,
                          );
                          return Column(
                            children: [
                              Expanded(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    _draggable(
                                      id,
                                      onTap: () => _toggleCard(id),
                                      slot: false,
                                    ),
                                    Center(
                                      child: IgnorePointer(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 9,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xbb08162b),
                                            border: Border.all(
                                              color: slots.contains(id)
                                                  ? const Color(0xffffa2a2)
                                                  : KardRuneTheme.gold,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              9,
                                            ),
                                          ),
                                          child: Text(
                                            slots.contains(id)
                                                ? 'REMOVE'
                                                : 'ADD',
                                            style: TextStyle(
                                              color: slots.contains(id)
                                                  ? const Color(0xffffc5c5)
                                                  : const Color(0xffffdc95),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                height: 29,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${hero.name.toUpperCase()} · S${id.split(':').last}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xffe8d9b1),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      key: Key('add-deck-card-$id'),
                                      onTap: () => _toggleCard(id),
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: Icon(
                                          slots.contains(id)
                                              ? Icons.remove_circle
                                              : Icons.add_circle,
                                          color: KardRuneTheme.gold,
                                          size: 23,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 46,
                    width: double.infinity,
                    child: ElevatedButton(
                      key: const Key('save-deck'),
                      onPressed: _saveDeck,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffe6be77),
                        foregroundColor: const Color(0xff241b12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      child: Text(
                        _t('SALVA MAZZO', 'SAVE DECK'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _draggable(
    String id, {
    required VoidCallback onTap,
    required bool slot,
  }) {
    final stage = int.parse(id.split(':').last);
    final image = CharacterCardArt(
      asset: asset(id),
      hp: CombatRules.hpForStage(stage),
      attack: widget.attacks[id],
      crit: widget.crits[id],
      skillId: widget.skills[id],
      compact: slot,
      imageCacheWidth: slot ? 220 : 420,
    );
    return LongPressDraggable<String>(
      data: id,
      feedback: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          key: const Key('deck-drag-feedback'),
          width: 72,
          height: 98,
          child: CharacterCardArt(
            asset: asset(id),
            hp: CombatRules.hpForStage(stage),
            attack: widget.attacks[id],
            crit: widget.crits[id],
            skillId: widget.skills[id],
            compact: true,
          ),
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
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xff111e35),
        child: SizedBox(
          width: 350,
          height: MediaQuery.sizeOf(context).height * .75,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                SizedBox(
                  height: 240,
                  child: CharacterCardArt(
                    asset: asset(id),
                    hp: CombatRules.hpForStage(stage),
                    attack: widget.attacks[id],
                    crit: widget.crits[id],
                    skillId: widget.skills[id],
                  ),
                ),
                Text(
                  id.toUpperCase(),
                  style: const TextStyle(
                    color: KardRuneTheme.gold,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (skill != null) ...[
                  Center(child: SkillRarityBadge(skill: skill)),
                  Text(skill.description, textAlign: TextAlign.center),
                  Text(
                    '${skill.trigger} · ${skill.limit}',
                    textAlign: TextAlign.center,
                  ),
                  SkillPreviewButton(skill: skill),
                ],
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('CLOSE'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
