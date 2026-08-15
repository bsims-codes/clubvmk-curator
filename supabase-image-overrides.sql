-- ============================================================================
-- MyVMK Curator — item image replacements
-- Run this ONCE in the Supabase dashboard → SQL Editor.
--
--   • image_overrides — item_id → the replacement image's filename in the bucket.
--   • item-images bucket — holds the uploaded replacement art.
--
-- Same open model as the `overrides` table: the curator has no login, so reads
-- and writes use the public anon key. (If you later add auth, tighten these.)
-- ============================================================================

create table if not exists public.image_overrides (
  item_id    text        primary key,
  image_name text        not null,      -- filename in the item-images bucket
  editor     text,
  updated_at timestamptz not null default now()
);

alter table public.image_overrides enable row level security;

-- Everyone reads; only curators write (see supabase-lockdown.sql).
drop policy if exists image_overrides_all           on public.image_overrides;
drop policy if exists image_overrides_read_all      on public.image_overrides;
drop policy if exists image_overrides_curator_write on public.image_overrides;
create policy image_overrides_read_all on public.image_overrides
  for select using (true);
create policy image_overrides_curator_write on public.image_overrides
  for all using (public.is_curator()) with check (public.is_curator());

-- keep the realtime channel working like the overrides table (optional)
-- alter publication supabase_realtime add table public.image_overrides;

-- ── storage bucket for replacement item images ─────────────────────────────
insert into storage.buckets (id, name, public)
values ('item-images', 'item-images', true)
on conflict (id) do update set public = true;

drop policy if exists item_images_read on storage.objects;
create policy item_images_read on storage.objects
  for select using (bucket_id = 'item-images');

drop policy if exists item_images_write on storage.objects;
create policy item_images_write on storage.objects
  for all
  using      (bucket_id = 'item-images' and public.is_curator())
  with check (bucket_id = 'item-images' and public.is_curator());
