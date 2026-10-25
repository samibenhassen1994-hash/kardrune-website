class DailyRewardState {
  const DailyRewardState({required this.day, required this.count});
  final String day;
  final int count;
}

class PracticeResult {
  const PracticeResult(this.win, this.chance, this.reward, this.daily);
  final bool win;
  final double chance;
  final int reward;
  final DailyRewardState daily;
}

abstract final class GameRules {
  static const dailyRewardLimit = 10;
  static int safeCount(Object? value) => value is int && value >= 0 ? value : 0;
  static String dayKey(int milliseconds) {
    final d = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }
  static DailyRewardState dailyRewardState(DailyRewardState? progress, int now) {
    final today = dayKey(now);
    return DailyRewardState(day: today, count: progress?.day == today ? safeCount(progress!.count).clamp(0, dailyRewardLimit) : 0);
  }
  static double practiceWinChance(num power, int stage) {
    final s = stage.clamp(1, 3);
    return (0.43 + (power + (s - 1) * 18) / 200).clamp(0.05, 0.90);
  }
  static PracticeResult resolvePractice(DailyRewardState? progress, num power, int stage, double roll, int now) {
    final chance = practiceWinChance(power, stage), win = roll < chance;
    final d = dailyRewardState(progress, now), rewarded = d.count < dailyRewardLimit;
    return PracticeResult(win, chance, rewarded ? (win ? 100 : 35) : 0,
        DailyRewardState(day: d.day, count: d.count + (rewarded ? 1 : 0)));
  }
}
