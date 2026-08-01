-- Run this ONCE in your Supabase project:
--   Dashboard → SQL Editor → New query → paste all of this → Run.
--
-- Items the capture picked up but couldn't name. The extension records some
-- items with an empty name, and the importer refuses to invent a catalog row
-- for a nameless id — that guard stops NPC/base avatar figures becoming junk
-- rows, but it also silently drops real new items. This table is where they
-- wait to be identified.
--
--   naming.html lists them with their art, you type a name (and for a sprite,
--   pick which frame to use), and tools/vmk_merge_capture.py reads the names
--   back on the next import.
--
-- Same trust model as `overrides`: the anon key may read and write.

create table if not exists pending_items (
  raw_id     text primary key,          -- the numeric id from the capture
  source     text not null,             -- 'thumb' | 'sprite'
  hash       text,                      -- thumb: the item_<hash>.png key
  atlas      text,                      -- sprite: the -pkg32_0.webp atlas code
  frames     jsonb not null default '[]'::jsonb,   -- sprite: [{key,x,y,w,h}]
  category   text,                      -- best guess: pin | clothing
  name       text,                      -- you fill this in
  frame_key  text,                      -- sprite: which frame to crop for the icon
  status     text not null default 'pending',  -- pending | named | skip
  updated_at timestamptz not null default now()
);

alter table pending_items enable row level security;

drop policy if exists pending_items_all on pending_items;
create policy pending_items_all on pending_items
  for all using (true) with check (true);

-- live sync, so two people naming at once see each other's work
alter publication supabase_realtime add table pending_items;
