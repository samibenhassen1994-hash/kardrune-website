-- Apply after 0008. Existing decks start at revision 1; their cards and order stay intact.
ALTER TABLE pvp_decks ADD COLUMN revision INTEGER NOT NULL DEFAULT 1;
