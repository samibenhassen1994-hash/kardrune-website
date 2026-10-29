import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../game/skill_catalog.dart';
import 'free_pull_notifications.dart';

class SummonScreen extends StatefulWidget {
  const SummonScreen({
    super.key,
    required this.header,
    required this.shards,
    required this.active,
    required this.accountKey,
    required this.loadFreeStatus,
    required this.onSummon,
    required this.onFreeSummon,
  });
  final int shards;
  final Widget header;
  final bool active;
  final String accountKey;
  final Future<Map<String, dynamic>> Function() loadFreeStatus;
  final Future<void> Function(bool featured) onSummon;
  final Future<void> Function() onFreeSummon;

  @override
  State<SummonScreen> createState() => _SummonScreenState();
}

class _SummonScreenState extends State<SummonScreen> {
  int section = 0, available = 0;
  int? nextAt;
  DateTime now = DateTime.now();
  Timer? ticker;
  Timer? rechargeNotification;
  bool notificationsEnabled = freePullNotificationsGranted;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) _refresh();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !widget.active) return;
      if (!notificationsEnabled && freePullNotificationsGranted) {
        notificationsEnabled = true;
        _scheduleNotification();
      }
      setState(() => now = DateTime.now());
      if (nextAt != null && now.millisecondsSinceEpoch >= nextAt!) _refresh();
    });
  }

  @override
  void didUpdateWidget(covariant SummonScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.active && !oldWidget.active) ||
        widget.accountKey != oldWidget.accountKey) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    try {
      final status = await widget.loadFreeStatus();
      if (!mounted) return;
      setState(() {
        available = (status['available'] as num?)?.toInt().clamp(0, 2) ?? 0;
        nextAt = (status['nextAt'] as num?)?.toInt();
        now = DateTime.now();
      });
      _scheduleNotification();
    } catch (_) {
      if (mounted) {
        setState(() {
          available = 0;
          nextAt = null;
        });
      }
    }
  }

  Future<void> _pull({required bool featured, bool free = false}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (free) {
        await widget.onFreeSummon();
      } else {
        await widget.onSummon(featured);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Summon unavailable: $error')));
      }
    } finally {
      if (mounted) {
        await _refresh();
        setState(() => busy = false);
      }
    }
  }

  @override
  void dispose() {
    ticker?.cancel();
    rechargeNotification?.cancel();
    super.dispose();
  }

  void _scheduleNotification() {
    rechargeNotification?.cancel();
    if (!notificationsEnabled || nextAt == null) return;
    final delay = nextAt! - DateTime.now().millisecondsSinceEpoch;
    if (delay <= 0) return;
    rechargeNotification = Timer(Duration(milliseconds: delay), () {
      showFreePullNotification();
      _refresh();
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final compact = box.maxHeight < 540;
      final panelHeight = (box.maxHeight * (compact ? .72 : .62)).clamp(
        290.0,
        470.0,
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 1.4, sigmaY: 1.4),
            child: Image.asset(
              'assets/idle/summon/summon_arena.webp',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              cacheWidth: 1080,
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x22030a19),
                  Color(0x18030a19),
                  Color(0xbb050d20),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              height: panelHeight,
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 5),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              decoration: BoxDecoration(
                color: const Color(0xe5111b31),
                border: Border.all(color: const Color(0xffddb46b), width: 1.5),
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [
                  BoxShadow(color: Color(0x99000000), blurRadius: 18),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _tab(
                        0,
                        'STANDARD',
                        'assets/idle/cards/young_sam/young_sam_stage_1.webp',
                      ),
                      const SizedBox(width: 5),
                      _tab(
                        1,
                        'FEATURED',
                        'assets/idle/cards/dren/dren_stage_3.webp',
                      ),
                      const SizedBox(width: 5),
                      _tab(2, 'EVENT', 'assets/idle/summon/summon_arena.webp'),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Expanded(
                    child: SingleChildScrollView(
                      child: switch (section) {
                        0 => _standard(),
                        1 => _featured(),
                        _ => _event(),
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(top: 0, left: 0, right: 0, child: widget.header),
        ],
      );
    },
  );

  Widget _tab(int index, String label, String image) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() => section = index),
      child: Container(
        height: 82,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          border: Border.all(
            color: section == index
                ? const Color(0xffffe2a1)
                : const Color(0xffa5783d),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: section == index
              ? const [BoxShadow(color: Color(0x88f9bf58), blurRadius: 9)]
              : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              image,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x08000000), Color(0xdd0b1020)],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: FittedBox(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xffffe7b5),
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _standard() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _title('STANDARD SUMMON'),
      _info('Nine heroes · 300 Shards or a free charge'),
      const SizedBox(height: 5),
      _info('FREE PULLS  $available / 2', gold: true),
      if (nextAt != null) ...[
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: _progress(),
          minHeight: 5,
          color: const Color(0xffffd677),
          backgroundColor: const Color(0xff34465f),
        ),
        _info('Next charge in ${_remaining()}', gold: true),
      ],
      const SizedBox(height: 6),
      _button(
        'FREE SUMMON',
        available > 0 && !busy,
        () => _pull(featured: false, free: true),
      ),
      const SizedBox(height: 6),
      _button(
        'SUMMON 1  ◆ 300',
        widget.shards >= 300 && !busy,
        () => _pull(featured: false),
      ),
    ],
  );

  Widget _featured() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _title('FEATURED SUMMON · DREN'),
      _info('Dren rate-up · 600 Shards'),
      const SizedBox(height: 9),
      _button(
        'FEATURED PULL  ◆ 600',
        widget.shards >= 600 && !busy,
        () => _pull(featured: true),
      ),
    ],
  );

  Widget _event() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _title('EVENT SUMMON'),
      _info(
        'No event banner is active. Rates and featured heroes will appear here when an event is configured.',
      ),
    ],
  );

  Widget _skillRates() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 5),
      _info('SKILL RARITY BY STAGE', gold: true),
      for (final stage in [1, 2, 3]) _info('S$stage  ${_rates(stage)}'),
    ],
  );

  String _rates(int stage) {
    final weights = SkillCatalog.weights[stage]!;
    const names = ['C', 'U', 'R', 'E', 'L', 'X'];
    return List.generate(
      6,
      (i) =>
          '${names[i]} ${(weights[i] / 10).toStringAsFixed(weights[i] % 10 == 0 ? 0 : 1)}%',
    ).where((v) => !v.endsWith(' 0%')).join('  ');
  }

  double _progress() {
    if (nextAt == null) return 1;
    final remaining = nextAt! - now.millisecondsSinceEpoch;
    return (1 - remaining / (12 * 60 * 60 * 1000)).clamp(0, 1);
  }

  String _remaining() {
    final seconds = ((nextAt! - now.millisecondsSinceEpoch) / 1000)
        .ceil()
        .clamp(0, 999999);
    final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60;
    return '${h}h ${m}m';
  }

  Widget _title(String text) => Row(
    children: [
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xffffdf9d),
            fontFamily: 'Georgia',
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      TextButton.icon(
        onPressed: _showInfo,
        icon: const Icon(Icons.info_outline, size: 17),
        label: const Text('INFO'),
        style: TextButton.styleFrom(foregroundColor: const Color(0xffffd986)),
      ),
    ],
  );

  void _showInfo() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xff111e35),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xffffd986), width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section == 0
                      ? 'STANDARD SUMMON'
                      : section == 1
                      ? 'FEATURED SUMMON'
                      : 'EVENT SUMMON',
                  style: const TextStyle(
                    color: Color(0xffffdf9d),
                    fontFamily: 'Georgia',
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (section == 0) ...[
                          _info('Cost: 300 Shards, or one free charge.'),
                          _info(
                            '2 free charges; each recharges 12 hours after use.',
                          ),
                          _info('All 9 heroes: 11.11% each.'),
                          _info('Stage 1: 78% · Stage 2: 19% · Stage 3: 3%'),
                        ] else if (section == 1) ...[
                          _info('Cost: 600 Shards. Dren is rate-up.'),
                          _info('Stage 1: 60% · Stage 2: 30% · Stage 3: 10%'),
                          _info('Dren: 42.22%; each other hero: 7.22%.'),
                        ] else
                          _info(
                            'No event is active. No event odds or cost are defined.',
                          ),
                        if (section != 2) ...[
                          _info('ATK: 1–100 · CRIT: 0–25% · 1 skill per card.'),
                          _info(
                            'Duplicate: keep new stats or take 100 Shards.',
                          ),
                          _skillRates(),
                        ],
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('CLOSE'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _info(String text, {bool gold = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: TextStyle(
        color: gold ? const Color(0xffffd986) : const Color(0xffe4e9f3),
        fontSize: 10,
        fontWeight: gold ? FontWeight.w800 : FontWeight.w500,
      ),
    ),
  );
  Widget _button(String label, bool enabled, VoidCallback action) =>
      GestureDetector(
        onTap: enabled ? action : null,
        child: Container(
          height: 39,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: enabled
                  ? const [Color(0xffffe0a1), Color(0xffb97632)]
                  : const [Color(0xff646677), Color(0xff3e4656)],
            ),
            border: Border.all(color: const Color(0xffffe4a5)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xff251607),
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
        ),
      );
}
