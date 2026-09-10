-- 匿名ユーザー再リンク機構 (#20)
create table if not exists public.device_identities (
  device_secret uuid primary key,
  user_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.device_identities enable row level security;

drop policy if exists "device_identities_select_own" on public.device_identities;
create policy "device_identities_select_own" on public.device_identities
  for select using (auth.uid() = user_id);
drop policy if exists "device_identities_insert_own" on public.device_identities;
create policy "device_identities_insert_own" on public.device_identities
  for insert with check (auth.uid() = user_id);
drop policy if exists "device_identities_update_own" on public.device_identities;
create policy "device_identities_update_own" on public.device_identities
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create or replace function public.relink_device(p_device_secret uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current_user uuid := auth.uid();
  v_old_user uuid;
  v_existing boolean;
  v_migrated json;
begin
  if v_current_user is null then
    raise exception 'AUTH_REQUIRED: not authenticated';
  end if;
  if p_device_secret is null then
    raise exception 'INVALID_SECRET: null';
  end if;

  select user_id into v_old_user
    from public.device_identities
    where device_secret = p_device_secret;

  v_existing := v_old_user is not null;

  if v_existing then
    -- 旧 user_id のデータを現在の匿名ユーザーへ移行
    update public.user_books set user_id = v_current_user where user_id = v_old_user;
    -- reading_sessions / collection_items は user_id 列が無い（user_book_id / collection_id 経由で追従）
    update public.war_trophies set user_id = v_current_user where user_id = v_old_user;
    update public.reading_goals set user_id = v_current_user where user_id = v_old_user;
    update public.collections set user_id = v_current_user where user_id = v_old_user;

    update public.device_identities
      set user_id = v_current_user, updated_at = now()
      where device_secret = p_device_secret;
  else
    insert into public.device_identities (device_secret, user_id)
    values (p_device_secret, v_current_user)
    on conflict (device_secret) do update
      set user_id = excluded.user_id, updated_at = now();
  end if;

  select json_build_object(
    'relinked', v_existing,
    'old_user_id', v_old_user,
    'user_id', v_current_user,
    'migrated', json_build_object(
      'user_books', (select count(*) from public.user_books where user_id = v_current_user),
      'reading_sessions', (select count(*) from public.reading_sessions where user_id = v_current_user),
      'war_trophies', (select count(*) from public.war_trophies where user_id = v_current_user),
      'reading_goals', (select count(*) from public.reading_goals where user_id = v_current_user),
      'collections', (select count(*) from public.collections where user_id = v_current_user),
      'collection_items', (select count(*) from public.collection_items where user_id = v_current_user)
    )
  ) into v_migrated;

  return v_migrated;
end;
$$;

grant execute on function public.relink_device(uuid) to anon, authenticated;

