enum FlameAttackStyle { sword, dagger, magic, arrow }

FlameAttackStyle flameAttackStyleFor(String heroId) => switch (heroId) {
  'dren' || 'nyra' => FlameAttackStyle.dagger,
  'lira' || 'aria' || 'neris' => FlameAttackStyle.magic,
  'rhea' => FlameAttackStyle.arrow,
  _ => FlameAttackStyle.sword,
};
