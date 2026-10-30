Future<bool> toggleNotificationState({
  required Future<bool> Function() ensurePermission,
  required Future<bool> Function() refresh,
  required Future<void> Function() disable,
  required Future<bool> Function() enable,
}) async {
  if (!await ensurePermission()) return false;
  if (await refresh()) {
    await disable();
    return false;
  }
  return enable();
}
