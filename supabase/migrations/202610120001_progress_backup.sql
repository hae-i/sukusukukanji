-- Deploy to a dedicated SukuSuku Kanji project. No purchases or ad credits.
create table public.kanji_progress_backups (
  user_id uuid primary key references auth.users(id) on delete cascade,
  revision bigint not null check (revision > 0),
  payload jsonb not null check (jsonb_typeof(payload) = 'object' and octet_length(payload::text) <= 2000000),
  updated_at timestamptz not null default now()
);
alter table public.kanji_progress_backups enable row level security;
revoke all on public.kanji_progress_backups from anon, authenticated;
grant select on public.kanji_progress_backups to authenticated;
create policy "read own backup" on public.kanji_progress_backups
  for select to authenticated using ((select auth.uid()) = user_id);

-- Atomic compare-and-swap: stale devices cannot overwrite a newer backup.
create function public.save_kanji_progress_backup(snapshot jsonb, expected_revision bigint, expected_user_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  owner_id uuid := auth.uid();
  existing_revision bigint;
  saved public.kanji_progress_backups;
begin
  if owner_id is null or owner_id is distinct from expected_user_id then raise exception 'Authentication required' using errcode = '28000'; end if;
  if expected_revision is null or expected_revision < 0 or
     snapshot is null or jsonb_typeof(snapshot) <> 'object' or
     snapshot->>'version' is distinct from '1' or
     octet_length(snapshot::text) > 2000000 then
    raise exception 'Invalid backup' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(owner_id::text, 0));
  select revision into existing_revision from public.kanji_progress_backups where user_id = owner_id;
  if coalesce(existing_revision, 0) <> expected_revision then
    raise exception 'Backup revision conflict' using errcode = '40001';
  end if;
  insert into public.kanji_progress_backups(user_id, revision, payload, updated_at)
    values (owner_id, expected_revision + 1, snapshot, now())
    on conflict (user_id) do update set revision = excluded.revision,
      payload = excluded.payload, updated_at = excluded.updated_at
    returning * into saved;
  return to_jsonb(saved);
end;
$$;
revoke all on function public.save_kanji_progress_backup(jsonb, bigint, uuid) from public, anon;
grant execute on function public.save_kanji_progress_backup(jsonb, bigint, uuid) to authenticated;
