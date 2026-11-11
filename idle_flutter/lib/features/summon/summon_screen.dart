import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../localization/kr_localizations.dart';

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
    this.onEventSummon,
  });
  final int shards;
  final Widget header;
  final bool active;
  final String accountKey;
  final Future<Map<String, dynamic>> Function() loadFreeStatus;
  final Future<void> Function(bool featured) onSummon;
  final Future<void> Function() onFreeSummon;
  final Future<void> Function()? onEventSummon;

  @override
  State<SummonScreen> createState() => _SummonScreenState();
}

class _SummonScreenState extends State<SummonScreen>
    with SingleTickerProviderStateMixin {
  int section = 0, available = 0;
  int? nextAt;
  DateTime now = DateTime.now();
  Timer? ticker;
  Timer? rechargeNotification;
  bool notificationsEnabled = freePullNotificationsGranted;
  bool busy = false;
  late final AnimationController _entranceController;
  late final Animation<Offset> _entranceOffset;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      animationBehavior: AnimationBehavior.preserve,
      duration: const Duration(milliseconds: 420),
    );
    _entranceOffset =
        Tween<Offset>(begin: const Offset(0, .35), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );
    if (widget.active) _entranceController.forward();
    if (widget.active) _refresh();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !widget.active) return;
      if (notificationsEnabled != freePullNotificationsGranted) {
        notificationsEnabled = freePullNotificationsGranted;
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
    if (widget.active && !oldWidget.active) {
      _entranceController.forward(from: 0);
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

  Future<void> _pull({required bool featured, bool free = false,bool event=false}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (free) {
        await widget.onFreeSummon();
      } else if(event) {
        await widget.onEventSummon?.call();
      } else {
        await widget.onSummon(featured);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('Summon unavailable. Try again later.'))));
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
    _entranceController.dispose();
    ticker?.cancel();
    rechargeNotification?.cancel();
    super.dispose();
  }

  void _scheduleNotification() {
    rechargeNotification?.cancel();
    // Signed-in accounts are notified by the server-side push scheduler.
    // Keeping the foreground timer as well would alert twice for one charge.
    if (widget.accountKey != 'guest') return;
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
      // A browser shortcut on Android can lose 70-100 logical pixels to
      // Chrome's native title bar. Do not collapse the art to 92px and
      // stretch the glass panel across the rest of the screen in that case:
      // that hides the HERO SUMMON heading and leaves a huge empty card.
      //
      // Size the banner continuously with the *available* body height and
      // size the panel to its actual content, not a percentage of the screen.
      final bannerHeight = (box.maxHeight * .34)
          .clamp(166.0, 250.0)
          .toDouble();
      // Leave the first 80px of the arena artwork for the game header:
      // the summoning panel must never overlap the profile or wallet.
      final panelHeight = (bannerHeight + 279.0)
          .clamp(0.0, box.maxHeight - 80.0)
          .toDouble();
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
          SlideTransition(
            position: MediaQuery.disableAnimationsOf(context)
                ? const AlwaysStoppedAnimation(Offset.zero) : _entranceOffset,
            transformHitTests: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                key: const Key('summon-content-panel'),
                width: double.infinity,
                height: panelHeight,
                margin: const EdgeInsets.fromLTRB(10, 0, 10, 5),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                decoration: BoxDecoration(
                  color: const Color(0x8a111b31),
                  border: Border.all(
                    color: const Color(0xffddb46b),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [
                    BoxShadow(color: Color(0x99000000), blurRadius: 18),
                  ],
                ),
                child: Column(
                  children: [
                    _banner(bannerHeight),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        _tab(0, context.tr('STANDARD')),
                        const SizedBox(width: 5),
                        _tab(1, context.tr('FEATURED')),
                        const SizedBox(width: 5),
                        _tab(2, context.tr('EVENT')),
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
          ),
          Positioned(top: 0, left: 0, right: 0, child: widget.header),
        ],
      );
    },
  );

  Widget _banner(double height) {
    final title = switch (section) {
      0 => 'STANDARD PORTAL',
      1 => 'DREN · FEATURED SUMMON',
      _ => 'GODS OF OLYMPUS',
    };
    return Container(
      key: const Key('summon-banner-frame'),
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xffffe3a0),
            Color(0xff9a5c20),
            Color(0xffffcd69),
            Color(0xff6d3a14),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0xaa000000), blurRadius: 12),
          BoxShadow(color: Color(0x66ffc85d), blurRadius: 10),
        ],
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0x66091326),
          border: Border.all(color: const Color(0xff4f2d13), width: 2),
          borderRadius: BorderRadius.circular(11),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: Stack(
            key: ValueKey<int>(section),
            fit: StackFit.expand,
            children: [
              if (section == 0)
                Opacity(
                  opacity: .9,
                  child: Image.asset(
                    'assets/idle/summon/banners/Standard_banner.jpg',
                    key: const Key('summon-banner-art-standard'),
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                )
              else if (section == 1)
                Image.asset(
                  'assets/idle/summon/banners/Dren_banner.webp',
                  key: const Key('summon-banner-art-featured'),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  opacity: const AlwaysStoppedAnimation(.9),
                )
              else
                Image.asset(
                  'assets/idle/summon/banners/Banner_Gods_of_olympus.webp',
                  key: const Key('summon-banner-art-event'),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000),
                      Color(0x12000000),
                      Color(0x88020712),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: height < 195 ? 7 : 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x88020712),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    context.tr(title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xffffedbd),
                      fontFamily: 'Georgia',
                      fontSize: height < 195 ? 16 : 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 8),
                        Shadow(color: Color(0xffffb638), blurRadius: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(int index, String label) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() => section = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: section == index
              ? const Color(0xff7a4b1f)
              : const Color(0xff101c31),
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
        child: FittedBox(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xffffe7b5),
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: .4,
              shadows: [Shadow(color: Colors.black, blurRadius: 5)],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _standard() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _title(context.tr('STANDARD SUMMON')),
      _info('Nine heroes · 300 Shards or a free charge'),
      const SizedBox(height: 5),
      _info('${context.tr('FREE PULLS')}  $available / 2', gold: true),
      if (nextAt != null) ...[
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: _progress(),
          minHeight: 5,
          color: const Color(0xffffd677),
          backgroundColor: const Color(0xff34465f),
        ),
        _info('${context.tr('NEXT CHARGE IN')} ${_remaining()}', gold: true),
      ],
      const SizedBox(height: 6),
      _button(
        context.tr('FREE SUMMON'),
        available > 0 && !busy,
        () => _pull(featured: false, free: true),
      ),
      const SizedBox(height: 6),
      _button(
        context.tr('SUMMON 1  ◆ 300'),
        widget.shards >= 300 && !busy,
        () => _pull(featured: false),
        key: const Key('summon-paid-button'),
      ),
    ],
  );

  Widget _featured() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _title('${context.tr('FEATURED SUMMON')} · DREN'),
      _info('Dren rate-up · 600 Shards'),
      const SizedBox(height: 9),
      _button(
        context.tr('FEATURED PULL  ◆ 600'),
        widget.shards >= 600 && !busy,
        () => _pull(featured: true),
      ),
    ],
  );

  Widget _event() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _title(context.tr('EVENT SUMMON')),
      _info(context.tr('Olympus: 10% total (1.67% each). Otherwise, featured-style heroes with extra Stage 3 chance.')),
      const SizedBox(height: 8),
      _button(context.tr('OLYMPUS PULL  ◆ 1200'),widget.shards>=1200&&!busy&&widget.onEventSummon!=null,
        ()=>_pull(featured:false,event:true),key:const Key('summon-event-button')),
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
        label: Text(context.tr('INFO')),
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
                  context.tr(
                    section == 0
                        ? 'STANDARD SUMMON'
                        : section == 1
                        ? 'FEATURED SUMMON'
                        : 'EVENT SUMMON',
                  ),
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
                          Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                            _info(context.tr('Cost: 1200 Shards. Six Olympus gods: 10% total; 1.67% each.')),
                            _info(context.tr('Other heroes: 90%. Dren featured rate-up.')),
                            _info(context.tr('Fallback stages: Stage 1 55%, Stage 2 30%, Stage 3 15%.')),
                            _info(context.tr('Olympus cards: one form, Ultra fixed skills, ATK 100, CRIT 25%, HP 430.')),
                          ]),
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
                    child: Text(context.tr('CLOSE')),
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
      context.tr(text),
      style: TextStyle(
        color: gold ? const Color(0xffffd986) : const Color(0xffe4e9f3),
        fontSize: 10,
        fontWeight: gold ? FontWeight.w800 : FontWeight.w500,
      ),
    ),
  );
  Widget _button(String label, bool enabled, VoidCallback action, {Key? key}) =>
      GestureDetector(
        key: key,
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
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.split('◆').first.trim(),
                  style: const TextStyle(
                    color: Color(0xff251607),
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
                if (label.contains('◆')) ...[
                  const SizedBox(width: 5),
                  Image.asset('assets/idle/arena/shard.webp', width: 18, height: 18),
                  const SizedBox(width: 4),
                  Text(label.split('◆').last.trim(), style: const TextStyle(
                    color: Color(0xff251607), fontWeight: FontWeight.w900,
                  )),
                ],
              ],
            ),
          ),
        ),
      );
}
