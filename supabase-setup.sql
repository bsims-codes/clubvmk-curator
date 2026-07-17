-- Run this ONCE in your Supabase project:
--   Dashboard → SQL Editor → New query → paste all of this → Run.
-- It creates the shared rarity table and lets the page read/write it with the
-- public anon key. Fine for a small trusted project (only you + your friend).

create table if not exists overrides (
  item_id    text primary key,
  tier       text not null,
  updated_at timestamptz not null default now()
);

alter table overrides enable row level security;

-- Anyone holding the anon key (i.e. anyone who opens the page) may read/write.
create policy "anon read"   on overrides for select using (true);
create policy "anon insert" on overrides for insert with check (true);
create policy "anon update" on overrides for update using (true) with check (true);
create policy "anon delete" on overrides for delete using (true);

-- Turn on live sync (so edits appear on your friend's screen instantly).
alter publication supabase_realtime add table overrides;
