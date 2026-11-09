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
  });
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
      if (mounted) setState(() => busy = false);
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
  @override
  Widget build(BuildContext context) {
    if (widget.uid == null) {
      return Center(
        child: FilledButton(
          onPressed: widget.onLogin,
          child: Text(context.tr('CLAN_LOGIN')),
        ),
      );
    }
    return Stack(
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
        if (animating)
          ForgeVideo(
            onDone: () {
              if (mounted) setState(() => animating = false);
            },
          )
        else
          LayoutBuilder(
            builder: (context, bounds) {
              final h = (bounds.maxHeight * .28).clamp(92.0, 170.0);
              return SingleChildScrollView(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.tr('FORGE'),
                            style: const TextStyle(
                              fontSize: 24,
                              color: Color(0xffffdf99),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: busy ? null : _load,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    if (loading || busy) const LinearProgressIndicator(),
                    if (error != null)
                      slot(
                        Column(
                          children: [
                            Text(
                              context.tr(error!),
                              textAlign: TextAlign.center,
                            ),
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
                    if (result != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: slot(
                          Column(
                            children: [
                              Text(
                                context.tr(
                                  result!['success'] == true
                                      ? 'FORGE_SUCCESS'
                                      : 'FORGE_FAILED',
                                ),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: result!['success'] == true
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                ),
                              ),
                              Text(
                                stat == 'SKILL'
                                    ? '${skillName(result!['before']['skillId'])} → ${skillName(result!['after']['skillId'])}'
                                    : '$stat: ${result!['before'][stat == 'ATK' ? 'attack' : 'crit']} → ${result!['after'][stat == 'ATK' ? 'attack' : 'crit']}',
                                textAlign: TextAlign.center,
                              ),
                              TextButton(
                                onPressed: () => setState(() => result = null),
                                child: Text(context.tr('CONFIRM')),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  DragTarget<String>(
                                    onWillAcceptWithDetails: (d) =>
                                        cards.any((c) => c['id'] == d.data) &&
                                        !busy &&
                                        pending == null &&
                                        result == null,
                                    onAcceptWithDetails: (d) =>
                                        setState(() => cardId = d.data),
                                    builder: (context, candidates, rejected) =>
                                        slot(
                                          card == null
                                              ? SizedBox(
                                                  height: h,
                                                  width: h * .75,
                                                  child: const Icon(
                                                    Icons.style_outlined,
                                                  ),
                                                )
                                              : art(card!, h),
                                        ),
                                  ),
                                  DragTarget<String>(
                                    onWillAcceptWithDetails: (d) =>
                                        [
                                          'green',
                                          'blue',
                                          'red',
                                        ].contains(d.data) &&
                                        !busy &&
                                        pending == null &&
                                        result == null,
                                    onAcceptWithDetails: (d) =>
                                        setState(() => color = d.data),
                                    builder: (context, candidates, rejected) =>
                                        slot(keyArt(color, h * .45)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (card != null)
                                Text(
                                  '${context.tr('STAGE')} $stage',
                                  style: const TextStyle(
                                    color: Color(0xffffdf99),
                                  ),
                                ),
                              Wrap(
                                spacing: 4,
                                children: [
                                  for (final s in ['ATK', 'CRT', 'SKILL'])
                                    ChoiceChip(
                                      label: Text(context.tr(s)),
                                      selected: stat == s,
                                      onSelected:
                                          busy ||
                                              pending != null ||
                                              result != null
                                          ? null
                                          : (_) => setState(() => stat = s),
                                    ),
                                ],
                              ),
                              Text(
                                '${context.tr('FORGE_CHANCE')}: ${(state?['chances'] as Map?)?[color] ?? 0}%',
                                style: const TextStyle(
                                  color: Color(0xffffdf99),
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
                        SizedBox(
                          width: 64,
                          child: Column(
                            children: [
                              for (final c in ['green', 'blue', 'red'])
                                GestureDetector(
                                  onTap:
                                      busy || pending != null || result != null
                                      ? null
                                      : () => setState(() => color = c),
                                  child: LongPressDraggable<String>(
                                    data: c,
                                    maxSimultaneousDrags:
                                        busy ||
                                            pending != null ||
                                            result != null
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
                                              : Colors.transparent,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          keyArt(c, 48),
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
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          key: const Key('forge-prev'),
                          onPressed: cardPage > 0
                              ? () => setState(() => cardPage--)
                              : null,
                          icon: const Icon(Icons.chevron_left),
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
                        ),
                      ],
                    ),
                    GridView.count(
                      key: const Key('forge-card-grid'),
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisExtent: 128,
                      children: [
                        for (final c in cards.skip(cardPage * 4).take(4))
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: GestureDetector(
                              onTap: busy || pending != null || result != null
                                  ? null
                                  : () => setState(
                                      () => cardId = c['id'] as String,
                                    ),
                              child: LongPressDraggable<String>(
                                data: c['id'] as String,
                                maxSimultaneousDrags:
                                    busy || pending != null || result != null
                                    ? 0
                                    : 1,
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: art(c, 130),
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: cardId == c['id']
                                          ? Colors.amber
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: art(c, 120),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('forge-start'),
                        onPressed:
                            busy ||
                                loading ||
                                result != null ||
                                pending == null &&
                                    (card == null || quantity < 1 || atCap)
                            ? null
                            : _start,
                        child: Text(
                          context.tr(pending != null ? 'RETRY' : 'START'),
                        ),
                      ),
                    ),
                    Text(
                      context.tr('FORGE_COST'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
