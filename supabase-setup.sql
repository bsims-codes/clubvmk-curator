-- Run this ONCE in your Supabase project:
--   Dashboard → SQL Editor → New query → paste all of this → Run.
-- It creates the shared rarity table. Anyone may READ it (the portal and the
-- bot both do); only a signed-in curator may write, because the anon key is
-- public and this table drives rarities in the live bot.
--
-- Writes depend on public.is_curator() from supabase-lockdown.sql — run that
-- first on a fresh project, or these policies will fail to create.

create table if not exists overrides (
  item_id    text primary key,
  tier       text not null,
  updated_at timestamptz not null default now()
);

alter table overrides enable row level security;

-- Everyone reads; only curators write.
drop policy if exists overrides_read_all      on overrides;
drop policy if exists overrides_curator_write on overrides;
create policy overrides_read_all on overrides
  for select using (true);
create policy overrides_curator_write on overrides
  for all using (public.is_curator()) with check (public.is_curator());

-- Turn on live sync (so edits appear on your friend's screen instantly).
alter publication supabase_realtime add table overrides;
