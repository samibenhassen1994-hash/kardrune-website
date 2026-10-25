abstract final class DeckRules {
  static const size = 9;
  static List<String?> normalize(List<Object?>? input, List<String> owned) {
    final out = List<String?>.filled(size, null), seen = <String>{};
    if (input == null) return out;
    for (var i = 0; i < input.length.clamp(0, size); i++) { final id = input[i]; if (id is String && owned.contains(id) && seen.add(id)) out[i] = id; }
    return out;
  }
  static List<String?> put(List<Object?> current, String id, int? slot, List<String> owned) {
    final state = normalize(current, owned); if (!owned.contains(id)) throw ArgumentError('Card is not owned');
    final target = slot != null && slot >= 0 && slot < size ? slot : state.indexOf(null); if (target < 0) throw StateError('All nine slots are full');
    final from = state.indexOf(id); if (from == target) return state; final replaced = state[target];
    if (from >= 0) { state[from] = replaced; state[target] = id; return state; }
    if (replaced != null) { final empty = state.indexOf(null); if (empty < 0) throw StateError('All nine slots are full'); state[empty] = replaced; }
    state[target] = id; return state;
  }
  static List<String?> remove(List<Object?> current, int slot, List<String> owned) { final out = normalize(current, owned); if (slot >= 0 && slot < size) out[slot] = null; return out; }
}
