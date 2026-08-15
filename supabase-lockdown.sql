-- ============================================================================
-- CLUBVMK — curator lockdown
-- Run this ONCE in the Supabase dashboard → SQL Editor.
--
-- WHY THIS EXISTS
--   The curator tables were set up with "anyone holding the anon key may
--   read/write" policies. That was a fair trade when this was a two-person
--   tool nobody could find. It stopped being one once the curator page went
--   up on public GitHub Pages and the bot started serving a live server:
--   the anon key is *designed* to be public (it ships in the portal too), so
--   those policies let anyone on the internet retier every item, replace item
--   art, or empty the tables — and the bot syncs the result within 5 minutes.
--
-- WHAT IT CHANGES
--   Reads stay open — the portal and the bot both need them, and none of this
--   data is secret. Only WRITES are pulled back to the curator accounts:
--
--     overrides             rarity tiers        read: all   write: curators
--     image_overrides       replacement art     read: all   write: curators
--     pending_items         naming queue        read: all   write: curators
--     pin_animation         pin animation data  read: all   write: curators
--     composite_candidates  composite review    read: all   write: curators
--     item-images           storage bucket      read: all   write: curators
--
--   overrides_history is left alone: it is already read-only to clients and
--   written only by its trigger, which is what an audit log should be.
--
--   The BOT is unaffected — it connects with the service_role key, which
--   bypasses RLS entirely.
--
-- BEFORE YOU RUN IT
--   The curator page must be signing in with Discord (auth.js), or its writes
--   will start failing. That is already deployed.
-- ============================================================================

-- Depends on public.auth_discord_id() from the bot repo's webportal/schema.sql
-- — the Discord id off the *verified* JWT, which a client cannot spoof.

-- ── who may curate ──────────────────────────────────────────────────────────
-- One function instead of the same id repeated across nine policies: adding or
-- removing a curator is a single edit here, and no policy can drift out of step
-- with the others. Re-run this statement alone to change the roster.
create or replace function public.is_curator()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.auth_discord_id() in (
    '886570059974201405'      -- bsims
  ), false)
$$;

-- ── overrides: item rarity tiers ────────────────────────────────────────────
drop policy if exists "anon read"              on public.overrides;
drop policy if exists "anon insert"            on public.overrides;
drop policy if exists "anon update"            on public.overrides;
drop policy if exists "anon delete"            on public.overrides;
drop policy if exists overrides_read_all       on public.overrides;
drop policy if exists overrides_curator_write  on public.overrides;

create policy overrides_read_all on public.overrides
  for select using (true);

create policy overrides_curator_write on public.overrides
  for all using (public.is_curator()) with check (public.is_curator());

-- ── image_overrides: replacement item art ───────────────────────────────────
drop policy if exists image_overrides_all            on public.image_overrides;
drop policy if exists image_overrides_read_all       on public.image_overrides;
drop policy if exists image_overrides_curator_write  on public.image_overrides;

create policy image_overrides_read_all on public.image_overrides
  for select using (true);

create policy image_overrides_curator_write on public.image_overrides
  for all using (public.is_curator()) with check (public.is_curator());

-- ── pending_items: the naming queue ─────────────────────────────────────────
drop policy if exists pending_items_all            on public.pending_items;
drop policy if exists pending_items_read_all       on public.pending_items;
drop policy if exists pending_items_curator_write  on public.pending_items;

create policy pending_items_read_all on public.pending_items
  for select using (true);

create policy pending_items_curator_write on public.pending_items
  for all using (public.is_curator()) with check (public.is_curator());

-- ── pin_animation: pin animation frames ─────────────────────────────────────
drop policy if exists pin_animation_all            on public.pin_animation;
drop policy if exists pin_animation_read_all       on public.pin_animation;
drop policy if exists pin_animation_curator_write  on public.pin_animation;

create policy pin_animation_read_all on public.pin_animation
  for select using (true);

create policy pin_animation_curator_write on public.pin_animation
  for all using (public.is_curator()) with check (public.is_curator());

-- ── composite_candidates: the composite review queue ────────────────────────
drop policy if exists composite_candidates_all            on public.composite_candidates;
drop policy if exists composite_candidates_read_all       on public.composite_candidates;
drop policy if exists composite_candidates_curator_write  on public.composite_candidates;

create policy composite_candidates_read_all on public.composite_candidates
  for select using (true);

create policy composite_candidates_curator_write on public.composite_candidates
  for all using (public.is_curator()) with check (public.is_curator());

-- ── item-images bucket: the uploaded replacement art itself ─────────────────
-- The table policy above only guards the *filename*. Without this, anyone
-- could still overwrite the PNG that filename points at — and the bot
-- downloads and renders whatever is in the bucket.
drop policy if exists item_images_read  on storage.objects;
drop policy if exists item_images_write on storage.objects;

create policy item_images_read on storage.objects
  for select using (bucket_id = 'item-images');

create policy item_images_write on storage.objects
  for all
  using      (bucket_id = 'item-images' and public.is_curator())
  with check (bucket_id = 'item-images' and public.is_curator());

-- ── check it took ───────────────────────────────────────────────────────────
-- Should list exactly the policies above, each write policy with a qual that
-- calls is_curator(). Anything still reading `true` for a write is a miss.
select tablename, policyname, cmd, qual
from pg_policies
where schemaname = 'public'
  and tablename in ('overrides', 'image_overrides', 'pending_items',
                    'pin_animation', 'composite_candidates')
order by tablename, policyname;
