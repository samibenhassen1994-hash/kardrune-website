import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../services/local_save_service.dart';
import '../../game/catalog.dart';
import '../../game/combat_rules.dart';
import '../../game/skill_catalog.dart';
import '../../localization/kr_localizations.dart';
import '../../localization/skill_localizations.dart';
import '../cards/card_stat_badges.dart';
import 'forge_video.dart';

class ForgeScreen extends StatefulWidget {
  const ForgeScreen({
    super.key,
    this.api,
    this.uid,
    this.storage,
    required this.active,
    required this.onLogin,
    required this.onSave,
    this.accountCurrent,
    this.header,
  });
  final Widget? header;
  final ApiClient? api;
  final String? uid;
  final KeyValueStorage? storage;
  final bool active;
  final VoidCallback onLogin;
  final void Function(Map<String, dynamic>) onSave;
  final bool Function()? accountCurrent;
  @override
  State<ForgeScreen> createState() => _ForgeState();
}

class _ForgeState extends State<ForgeScreen> {
  Map<String, dynamic>? state, result, pending;
  String? cardId, error;
  String color = 'green', stat = 'ATK';
  bool loading = false, busy = false, animating = false;
  int cardPage = 0;
  String get pendingKey => 'idle-forge-pending-v1:${widget.uid}';
  @override
  void initState() {
    super.initState();
    try {
      final p = jsonDecode(widget.storage?.read(pendingKey) ?? 'null');
      if (p is Map) {
        pending = Map<String, dynamic>.from(p);
        cardId = p['cardId'] as String?;
        color = p['color'] as String? ?? 'green';
        stat = p['stat'] as String? ?? 'ATK';
      }
    } catch (_) {}
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(ForgeScreen old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _load();
  }

  List<Map<String, dynamic>> get cards => (state?['cards'] as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  Map<String, dynamic>? get card =>
      cards.where((c) => c['id'] == cardId).firstOrNull;
  int get stage => int.tryParse(cardId?.split(':').last ?? '1') ?? 1;
  int get cap =>
      ((state?['caps'] as Map?)?['$stage'] as Map?)?[stat == 'ATK'
              ? 'attack'
              : 'crit']?[1]
          as int? ??
      0;
  int get current =>
      (card?[stat == 'ATK' ? 'attack' : 'crit'] as num?)?.toInt() ?? 0;
  int get quantity => ((state?['keys'] as Map?)?[color] as num?)?.toInt() ?? 0;
  bool get atCap => stat != 'SKILL' && card != null && current >= cap;
  Future<void> _load() async {
    if (widget.api == null || widget.uid == null || loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await widget.api!.get('/api/forge');
      if (!mounted || widget.accountCurrent?.call() == false) return;
      setState(() {
        state = data;
        if (!cards.any((c) => c['id'] == cardId)) {
          cardId = cards.firstOrNull?['id'] as String?;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ApiFailure && e.message.startsWith('FORGE_')
              ? e.message
              : 'FORGE_UNAVAILABLE',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _clearPending() {
    pending = null;
    widget.storage?.write(pendingKey, 'null');
  }

  Future<void> _start() async {
    if (busy ||
        widget.api == null ||
        widget.uid == null ||
        widget.accountCurrent?.call() == false) {
      return;
    }
    if (pending == null && (card == null || quantity < 1 || atCap)) return;
    pending ??= {
      'requestId': List.generate(
        32,
        (_) => Random.secure().nextInt(16).toRadixString(16),
      ).join(),
      'cardId': cardId,
      'color': color,
      'stat': stat,
      'revision': state!['revision'],
    };
    widget.storage?.write(pendingKey, jsonEncode(pending));
    setState(() {
      busy = true;
      animating = true;
      error = null;
      result = null;
    });
    final language = KrLocaleScope.languageOf(context);
    final playback = showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      transitionDuration: Duration.zero,
      pageBuilder: (videoContext, _, _) => KrLocaleScope(
        language: language,
        child: PopScope(
          canPop: false,
          child: Material(
            color: Colors.black,
            child: SizedBox.expand(
              key: const Key('forge-fullscreen-video'),
              child: ForgeVideo(onDone: () => Navigator.of(videoContext).pop()),
            ),
          ),
        ),
      ),
    );
    try {
      final response = await widget.api!.post('/api/forge', pending);
      if (!mounted || widget.accountCurrent?.call() == false) return;
      widget.onSave(response);
      setState(() {
        result = Map<String, dynamic>.from(response['result'] as Map);
        stat = pending!['stat'] as String;
        state = response;
        _clearPending();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          animating = false;
          error = e is ApiFailure && e.message.startsWith('FORGE_')
              ? e.message
              : 'FORGE_RETRY';
          if (e is ApiFailure && [400, 403, 413, 422].contains(e.statusCode)) {
            _clearPending();
          }
        });
      }
    } finally {
      await playback;
      if (mounted) {
        setState(() {
          busy = false;
          animating = false;
        });
      }
    }
  }

  String skillName(dynamic id) =>
      SkillCatalog.byId(id as String?)?.localized(context).name ?? '—';
  Widget art(Map<String, dynamic> c, double height) {
    final parts = (c['id'] as String).split(':'),
        hero = KardRuneCatalog.heroes.firstWhere((h) => h.id == parts.first);
    return SizedBox(
      height: height,
      width: height * .75,
      child: CharacterCardArt(
        asset: hero.cardAsset(hero.stages[int.parse(parts.last) - 1]),
        hp: CombatRules.hpForStage(int.parse(parts.last)),
        attack: c['attack'] as int,
        crit: c['crit'] as int,
        skillId: c['skillId'] as String?,
        compact: true,
      ),
    );
  }

  Widget keyArt(String c, double size) => Image.asset(
    'assets/idle/forge/key_$c.webp',
    width: size,
    height: size,
    fit: BoxFit.contain,
    cacheWidth: 256,
  );
  Widget slot(Widget child) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: const Color(0xc0132032),
      border: Border.all(color: const Color(0xffe6ba68), width: 2),
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );
  void _odds() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.tr('SKILL')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.tr('FORGE_SKILL_INFO')),
          for (var i = 0; i < 6; i++)
            Text(
              '${context.tr(SkillCatalog.rarities[i].toUpperCase())}: ${SkillCatalog.weights[stage]![i] / 10}%',
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('CLOSE')),
        ),
      ],
    ),
  );
  bool get locked => busy || pending != null || result != null;
  Widget pickCard(Map<String, dynamic> c, double height) => GestureDetector(
    onTap: locked ? null : () => setState(() => cardId = c['id'] as String),
    child: LongPressDraggable<String>(
      data: c['id'] as String,
      maxSimultaneousDrags: locked ? 0 : 1,
      feedback: Material(color: Colors.transparent, child: art(c, 130)),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(
            color: cardId == c['id'] ? Colors.amber : Colors.transparent,
            width: 2,
          ),
        ),
        child: art(c, height),
      ),
    ),
  );
  Widget outcome() {
    final before = result!['before'] as Map, after = result!['after'] as Map;
    final success = result!['success'] == true;
    final displayed = <String, dynamic>{
      'id': cardId,
      'attack': after['attack'],
      'crit': after['crit'],
      'skillId': after['skillId'],
    };
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(
            context.tr(success ? 'FORGE_SUCCESS' : 'FORGE_FAILED'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: success ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (c, b) => Center(
                child: art(displayed, min(b.maxHeight - 8, b.maxWidth / .75)),
              ),
            ),
          ),
          slot(
            Column(
              children: [
                Text(
                  '${context.tr('BEFORE')} → ${context.tr('AFTER')}',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'ATK: ${before['attack']} → ${after['attack']}',
                  style: const TextStyle(fontSize: 20),
                ),
                Text(
                  'CRT: ${before['crit']}% → ${after['crit']}%',
                  style: const TextStyle(fontSize: 20),
                ),
                Text(
                  '${skillName(before['skillId'])} → ${skillName(after['skillId'])}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => setState(() => result = null),
            child: Text(context.tr('CONFIRM')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Image.asset(
          'assets/idle/forge/background.webp',
          fit: BoxFit.cover,
          cacheWidth: 1080,
        ),
      ),
      const ColoredBox(color: Color(0x55000000)),
      SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (widget.header != null) widget.header!,
            Expanded(
              child: widget.uid == null
                  ? Center(
                      child: FilledButton(
                        onPressed: widget.onLogin,
                        child: Text(context.tr('CLAN_LOGIN')),
                      ),
                    )
                  : result != null && !animating
                  ? outcome()
                  : LayoutBuilder(
                      builder: (context, bounds) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 36,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      context.tr('FORGE'),
                                      style: const TextStyle(
                                        fontSize: 22,
                                        color: Color(0xffffdf99),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: busy ? null : _load,
                                    icon: const Icon(Icons.refresh),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 3,
                              child: loading || busy
                                  ? const LinearProgressIndicator()
                                  : null,
                            ),
                            Expanded(
                              flex: 5,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: SizedBox(
                                  width: bounds.maxWidth - 20,
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          DragTarget<String>(
                                            onWillAcceptWithDetails: (d) =>
                                                !locked &&
                                                cards.any(
                                                  (c) => c['id'] == d.data,
                                                ),
                                            onAcceptWithDetails: (d) =>
                                                setState(() => cardId = d.data),
                                            builder: (c, a, r) => slot(
                                              card == null
                                                  ? const SizedBox(
                                                      width: 90,
                                                      height: 120,
                                                      child: Icon(
                                                        Icons.style_outlined,
                                                      ),
                                                    )
                                                  : art(card!, 120),
                                            ),
                                          ),
                                          DragTarget<String>(
                                            onWillAcceptWithDetails: (d) =>
                                                !locked &&
                                                [
                                                  'green',
                                                  'blue',
                                                  'red',
                                                ].contains(d.data),
                                            onAcceptWithDetails: (d) =>
                                                setState(() => color = d.data),
                                            builder: (c, a, r) =>
                                                slot(keyArt(color, 45)),
                                          ),
                                          Column(
                                            children: [
                                              for (final c in [
                                                'green',
                                                'blue',
                                                'red',
                                              ])
                                                GestureDetector(
                                                  onTap: locked
                                                      ? null
                                                      : () => setState(
                                                          () => color = c,
                                                        ),
                                                  child: LongPressDraggable<String>(
                                                    data: c,
                                                    maxSimultaneousDrags: locked
                                                        ? 0
                                                        : 1,
                                                    feedback: Material(
                                                      color: Colors.transparent,
                                                      child: keyArt(c, 70),
                                                    ),
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color: color == c
                                                              ? Colors.amber
                                                              : Colors
                                                                    .transparent,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          keyArt(c, 42),
                                                          Text(
                                                            '${(state?['keys'] as Map?)?[c] ?? 0}',
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Wrap(
                                        spacing: 4,
                                        children: [
                                          for (final s in [
                                            'ATK',
                                            'CRT',
                                            'SKILL',
                                          ])
                                            ChoiceChip(
                                              label: Text(context.tr(s)),
                                              selected: stat == s,
                                              onSelected: locked
                                                  ? null
                                                  : (_) => setState(
                                                      () => stat = s,
                                                    ),
                                            ),
                                        ],
                                      ),
                                      Text(
                                        '${context.tr('FORGE_CHANCE')}: ${(state?['chances'] as Map?)?[color] ?? 0}%',
                                        style: const TextStyle(
                                          color: Colors.amber,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (stat != 'SKILL' && card != null)
                                        Text(
                                          '$stat $current / $cap · ${atCap ? context.tr('FORGE_CAP') : '+1–${min(stat == 'ATK' ? 5 : 2, cap - current)}${stat == 'CRT' ? '%' : ''}'}',
                                          textAlign: TextAlign.center,
                                        ),
                                      if (stat == 'SKILL')
                                        TextButton(
                                          onPressed: _odds,
                                          child: Text(context.tr('INFO')),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 32,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    key: const Key('forge-prev'),
                                    onPressed: cardPage > 0
                                        ? () => setState(() => cardPage--)
                                        : null,
                                    icon: const Icon(Icons.chevron_left),
                                    padding: EdgeInsets.zero,
                                  ),
                                  Text(
                                    '${min(cardPage + 1, max(1, (cards.length / 4).ceil()))} / ${max(1, (cards.length / 4).ceil())}',
                                  ),
                                  IconButton(
                                    key: const Key('forge-next'),
                                    onPressed: (cardPage + 1) * 4 < cards.length
                                        ? () => setState(() => cardPage++)
                                        : null,
                                    icon: const Icon(Icons.chevron_right),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: LayoutBuilder(
                                builder: (c, b) => GridView.count(
                                  key: const Key('forge-card-grid'),
                                  padding: EdgeInsets.zero,
                                  crossAxisCount: 2,
                                  physics: const NeverScrollableScrollPhysics(),
                                  mainAxisExtent: b.maxHeight / 2,
                                  children: [
                                    for (final c
                                        in cards.skip(cardPage * 4).take(4))
                                      pickCard(c, max(20, b.maxHeight / 2 - 4)),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 42,
                              width: double.infinity,
                              child: FilledButton(
                                key: const Key('forge-start'),
                                onPressed:
                                    busy ||
                                        loading ||
                                        result != null ||
                                        pending == null &&
                                            (card == null ||
                                                quantity < 1 ||
                                                atCap)
                                    ? null
                                    : _start,
                                child: Text(
                                  context.tr(
                                    pending != null ? 'RETRY' : 'START',
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 28,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  context.tr('FORGE_COST'),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      if (error != null && !animating)
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: slot(
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.tr(error!), textAlign: TextAlign.center),
                  TextButton(
                    onPressed: busy
                        ? null
                        : pending != null
                        ? _start
                        : _load,
                    child: Text(context.tr('RETRY')),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}
