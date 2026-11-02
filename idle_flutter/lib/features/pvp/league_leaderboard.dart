import 'package:flutter/material.dart';

import '../../localization/kr_localizations.dart';
import '../../services/api_client.dart';

/// Ranking pages are requested only when their tab opens or Load More is
/// pressed. The API fetches 11 rows, returns at most 10 and supplies hasMore.
class LeagueLeaderboard extends StatefulWidget {
  const LeagueLeaderboard({
    super.key,
    required this.api,
    required this.onClaimed,
  });

  final ApiClient api;
  final Future<void> Function() onClaimed;

  @override
  State<LeagueLeaderboard> createState() => _LeagueLeaderboardState();
}

class _LeagueLeaderboardState extends State<LeagueLeaderboard> {
  int selected = 0;
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = true;
  String? error;
  String? claiming;
  Map<String, dynamic>? data;
  final List<Map<String, dynamic>> entries = [];

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (loading || loadingMore) return;
    final scope = selected == 1 ? 'league' : 'global';
    final requestedTab = selected;
    if (mounted) {
      setState(() {
        if (reset) {
          loading = true;
          entries.clear();
          hasMore = true;
        } else {
          loadingMore = true;
        }
        error = null;
      });
    }
    try {
      final offset = reset ? 0 : entries.length;
      final result = await widget.api.get(
        '/api/pvp/leaderboard?scope=$scope&offset=$offset',
      );
      if (!mounted || selected != requestedTab) return;
      final rows = result['leaders'] as List? ?? [];
      setState(() {
        data = result;
        entries.addAll(rows.whereType<Map>().map(
          (row) => Map<String, dynamic>.from(row),
        ));
        hasMore = result['hasMore'] == true;
      });
    } catch (e) {
      if (mounted && selected == requestedTab) {
        setState(() => error = e.toString());
      }
    } finally {
      if (mounted && selected == requestedTab) {
        setState(() {
          loading = false;
          loadingMore = false;
        });
      }
    }
  }

  void _switchTab(int tab) {
    if (tab == selected) return;
    setState(() {
      selected = tab;
      entries.clear();
      data = null;
      hasMore = true;
      loading = false;
      loadingMore = false;
      error = null;
    });
    _load(reset: true);
  }

  Future<void> _claim(String league) async {
    if (claiming != null) return;
    setState(() => claiming = league);
    try {
      final result = await widget.api.post('/api/pvp/league-claim', {
        'league': league,
      });
      if (result['claimed'] == true) await widget.onClaimed();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr(result['claimed'] == true
          ? 'League reward claimed!' : 'Reward already claimed.')),
      ));
      await _load(reset: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => claiming = null);
    }
  }

  String _leagueName(BuildContext context, String value) {
    final map = {
      'Bronze': 'BRONZE', 'Silver': 'SILVER', 'Gold': 'GOLD',
      'Platinum': 'PLATINUM', 'Diamond': 'DIAMOND',
      'Legend': 'LEGEND',
    };
    return context.tr(map[value] ?? value);
  }

  Widget _medal(String league, {double size = 52}) {
    final names = {
      'Bronze':'bronze', 'Silver':'silver', 'Gold':'gold',
      'Platinum':'platinum', 'Diamond':'diamond', 'Legend':'legend',
    };
    final name = names[league];
    if (name == null) return const Icon(Icons.shield_outlined);
    return Image.asset(
      'assets/idle/pvp_leagues/$name.webp',
      width: size, height: size, fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const Icon(Icons.military_tech),
    );
  }

  Widget _myOverview() {
    final me = data?['you'] as Map?;
    if (me == null) return const SizedBox.shrink();
    final current = me['league']?.toString() ?? 'Bronze';
    final position = selected == 1 ? me['leaguePosition'] : me['position'];
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xffb99452)),
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xff172942),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(10),
      child: Row(children: [
        _medal(current, size: 54),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_leagueName(context,current),
              style: const TextStyle(fontWeight: FontWeight.bold,
                color: Color(0xffffdda4))),
            Text('${me['points']} ${context.tr('POINTS')}'),
            if (selected != 0)
              Text('${context.tr('YOUR POSITION')}: #$position'),
            if (selected == 0)
              Text(me['next'] == null
                ? context.tr('MAX LEAGUE')
                : '${me['remaining']} ${context.tr('POINTS TO NEXT LEAGUE')}'),
          ],
        )),
      ]),
    );
  }

  Widget _leagues() {
    final leagues = data?['leagues'] as List? ?? [];
    final claimed = (data?['claimed'] as List? ?? []).toSet();
    final points = (data?['you'] as Map?)?['points'] as num? ?? 0;
    return ListView.builder(
      itemCount: leagues.length,
      itemBuilder: (context, index) {
        final row = leagues[index] as Map;
        final name = row['name']?.toString() ?? 'Bronze';
        final threshold = row['points'] as num? ?? 0;
        final reward = row['reward'] as num? ?? 0;
        final unlocked = points >= threshold;
        return Card(
          color: const Color(0xff15243d),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              leading: _medal(name, size: 62),
              title: Text(_leagueName(context, name),
                style: const TextStyle(color: Color(0xffffd99a),
                  fontWeight: FontWeight.w700)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$threshold ${context.tr('POINTS REQUIRED')}'),
                  Text(reward == 0
                    ? context.tr('STARTING LEAGUE')
                    : '$reward Shards'),
                  Text(context.tr(unlocked ? 'REACHED' : 'NOT REACHED')),
                ],
              ),
              trailing: reward > 0 && unlocked
                ? TextButton(
                    onPressed: claimed.contains(name) || claiming != null
                      ? null : () => _claim(name),
                    child: Text(context.tr(claimed.contains(name)
                      ? 'CLAIMED' : 'CLAIM')),
                  ) : null,
            ),
          ),
        );
      },
    );
  }

  Widget _rankings() {
    final me = data?['you'] as Map?;
    final personalPosition = me == null
      ? null : (selected == 1 ? me['leaguePosition'] : me['position']);
    // In Global Ranking the viewer stays in the dedicated eleventh row
    // even when additional pages are loaded. Never duplicate that user.
    final globalPinned = selected == 2 && me != null;
    final firstTen = entries.take(10).toList();
    final following = entries.skip(10).toList();
    final inTopTen = firstTen.any((row) => row['isYou'] == true);
    return ListView(children: [
      for (final row in firstTen) _rankingTile(row),
      if (globalPinned && !inTopTen) ...[
        const Divider(color: Color(0xffb38d5b)),
        Text(context.tr('YOUR POSITION'),textAlign: TextAlign.center),
        _rankingTile({
          'position': personalPosition,
          'name': context.tr('YOU'),
          'league': me['league'],
          'points': me['points'],
          'wins': me['wins'],
          'isYou': true,
        }),
      ],
      for (final row in following)
        if (!globalPinned || row['isYou'] != true) _rankingTile(row),
      if (entries.isEmpty && !loading)
        Padding(
          padding: const EdgeInsets.all(20),
          child: Center(child: Text(context.tr('NO PLAYERS YET'))),
        ),
      if (hasMore && !loading)
        Center(child: OutlinedButton(
          key: const Key('rankings-load-more'),
          onPressed: loadingMore ? null : () => _load(reset: false),
          child: Text(context.tr(loadingMore ? 'LOADING' : 'LOAD MORE')),
        )),
    ]);
  }

  Widget _rankingTile(Map row) {
    final current = row['league']?.toString() ?? 'Bronze';
    final mine = row['isYou'] == true;
    return Card(
      color: mine ? const Color(0xff334057) : const Color(0xff112037),
      child: ListTile(
        dense: true,
        leading: Row(mainAxisSize: MainAxisSize.min,children: [
          SizedBox(width: 30,child: Text('#${row['position']}',
            style: const TextStyle(fontWeight: FontWeight.w700))),
          _medal(current,size: 40),
        ]),
        title: Text(row['name']?.toString() ?? 'Runebearer',
          maxLines: 1,overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight:
            mine ? FontWeight.bold : FontWeight.normal)),
        subtitle: Text('${_leagueName(context,current)} · ${row['wins']} ${context.tr('WINS')}',
          style: const TextStyle(fontSize: 10)),
        trailing: Text('${row['points']} pt',
          style: const TextStyle(color: Color(0xffffdca3))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const tabs=['PVP LEAGUES','LEAGUE RANKING','GLOBAL RANKING'];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.emoji_events,color: Color(0xfff7c87c)),
            const SizedBox(width: 8),
            Expanded(child: Text(context.tr('PVP LEAGUES'),
              style: Theme.of(context).textTheme.titleLarge)),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ]),
          Row(children: [
            for (var i=0;i<tabs.length;i++)
              Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: OutlinedButton(
                  key: Key('rank-tab-$i'),
                  onPressed: () => _switchTab(i),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    backgroundColor: selected==i
                      ? const Color(0xff4b3a27) : null,
                    side: BorderSide(color: selected==i
                      ? const Color(0xffe5be80)
                      : const Color(0xff465b7a)),
                  ),
                  child: FittedBox(child: Text(
                    context.tr(tabs[i]),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
                  )),
                ),
              )),
          ]),
          if (error != null)
            Text(error!,style: const TextStyle(color: Colors.redAccent)),
          if (loading)
            const LinearProgressIndicator(),
          _myOverview(),
          Expanded(child: selected==0 ? _leagues() : _rankings()),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(context.tr(
              'Win PvP matches to earn points. Only completed matches count (max 10 wins/day, 3 per opponent/day).'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ]),
      ),
    );
  }
}
