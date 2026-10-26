enum SyncDecision { adopt, synced, upload, download, review }

class SaveLink {
  const SaveLink(this.revision, this.snapshot);
  final int revision;
  final String snapshot;
}

abstract final class SaveRepository {
  static Duration retryDelay(int attempt) =>
      Duration(seconds: (15 * (1 << (attempt.clamp(1, 4) - 1))).clamp(15, 120));
  static SyncDecision decide(
    String? local,
    String? remote,
    int revision,
    SaveLink? link,
  ) {
    if (local == null || revision < 0) return SyncDecision.review;
    if (revision == 0 || remote == null) return SyncDecision.review;
    if (local == remote) return SyncDecision.adopt;
    if (link == null) return SyncDecision.review;
    if (revision == link.revision) {
      return local == link.snapshot ? SyncDecision.synced : SyncDecision.upload;
    }
    if (revision > link.revision && local == link.snapshot) {
      return SyncDecision.download;
    }
    return SyncDecision.review;
  }

  static SyncDecision decisionForAccount({
    required String local,
    required String? remote,
    required int revision,
    required SaveLink? link,
    String? previousUid,
    required String currentUid,
  }) {
    if (previousUid != null && previousUid != currentUid && link == null) {
      return SyncDecision.review;
    }
    return decide(local, remote, revision, link);
  }
}
