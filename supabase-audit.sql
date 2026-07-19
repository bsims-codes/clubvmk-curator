-- Change tracking for the shared rarity DB. Run ONCE in Supabase:
--   Dashboard → SQL Editor → New query → paste all of this → Run.
-- After this, every insert/update/delete on `overrides` is logged to
-- `overrides_history` (old tier → new tier, who, when), and the page's
-- "editing as" name is stored with each edit. Safe to run on live data.

-- 1. Who made the edit (self-reported name from the page's "editing as" box).
alter table overrides add column if not exists editor text;

-- 2. Auto-refresh updated_at on every update.
--    (Upserts from the page previously kept the original insert time, which is
--    why past bulk changes could only be dated by their first insert.)
create or replace function touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists overrides_touch on overrides;
create trigger overrides_touch before update on overrides
for each row execute function touch_updated_at();

-- 3. Append-only history of every change.
create table if not exists overrides_history (
  id         bigint generated always as identity primary key,
  item_id    text not null,
  old_tier   text,              -- null = was common/untagged
  new_tier   text,              -- 'common' = tag deleted
  editor     text,
  changed_at timestamptz not null default now()
);

alter table overrides_history enable row level security;
create policy "anon read history" on overrides_history for select using (true);
-- No insert/update/delete policies on purpose: only the trigger below writes.

create or replace function log_override_change() returns trigger
language plpgsql security definer as $$
begin
  if tg_op = 'INSERT' then
    insert into overrides_history(item_id, old_tier, new_tier, editor)
    values (new.item_id, null, new.tier, new.editor);
    return new;
  elsif tg_op = 'UPDATE' then
    if new.tier is distinct from old.tier then
      insert into overrides_history(item_id, old_tier, new_tier, editor)
      values (new.item_id, old.tier, new.tier, new.editor);
    end if;
    return new;
  else  -- DELETE = set back to common; deleter's name isn't known, only the last setter's
    insert into overrides_history(item_id, old_tier, new_tier, editor)
    values (old.item_id, old.tier, 'common', null);
    return old;
  end if;
end $$;

drop trigger if exists overrides_log on overrides;
create trigger overrides_log after insert or update or delete on overrides
for each row execute function log_override_change();

-- Handy queries afterwards:
--   Recent changes:        select * from overrides_history order by changed_at desc limit 100;
--   Bulk-change bursts:    select date_trunc('second', changed_at) s, editor, count(*)
--                          from overrides_history group by 1,2 having count(*) > 20 order by s desc;
