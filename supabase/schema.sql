-- Run this file once in Supabase Dashboard > SQL Editor.
-- The Flutter client only uses the publishable/anon key. Never ship service_role.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  avatar_url text,
  goal_label text not null default 'Balanced eating',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  daily_calorie_goal integer not null default 2000 check (daily_calorie_goal > 0),
  protein_goal numeric not null default 120 check (protein_goal >= 0),
  carbs_goal numeric not null default 220 check (carbs_goal >= 0),
  fat_goal numeric not null default 70 check (fat_goal >= 0),
  dietary_preferences text[] not null default '{}',
  units text not null default 'metric',
  timezone text not null default 'UTC',
  updated_at timestamptz not null default now()
);

create table if not exists public.user_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  privacy_mode boolean not null default true,
  notifications_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists public.custom_foods (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  serving text not null default '1 serving',
  calories integer not null default 0 check (calories >= 0),
  protein numeric not null default 0 check (protein >= 0),
  carbs numeric not null default 0 check (carbs >= 0),
  fat numeric not null default 0 check (fat >= 0),
  fiber numeric not null default 0 check (fiber >= 0),
  sodium numeric not null default 0 check (sodium >= 0),
  ingredients text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.habits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  target integer not null default 1 check (target > 0),
  unit text not null default 'time',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.habit_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  habit_id uuid not null references public.habits(id) on delete cascade,
  day date not null,
  completed boolean not null default false,
  created_at timestamptz not null default now(),
  unique (habit_id, day)
);

create table if not exists public.scan_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  food_name text not null,
  subtitle text not null default '',
  emoji text not null default '🍽️',
  rating integer not null default 0 check (rating between 0 and 100),
  rating_label text not null default '',
  confidence numeric not null default 0 check (confidence between 0 and 1),
  serving text not null default '1 serving',
  calories integer not null default 0 check (calories >= 0),
  protein numeric not null default 0 check (protein >= 0),
  carbs numeric not null default 0 check (carbs >= 0),
  fat numeric not null default 0 check (fat >= 0),
  fiber numeric not null default 0 check (fiber >= 0),
  sodium numeric not null default 0 check (sodium >= 0),
  ingredients text[] not null default '{}',
  insight text not null default '',
  source text not null default 'camera',
  scanned_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists scan_records_user_scanned_at_idx on public.scan_records(user_id, scanned_at desc);
create index if not exists custom_foods_user_name_idx on public.custom_foods(user_id, name);
create index if not exists habits_user_active_idx on public.habits(user_id, active);

alter table public.profiles enable row level security;
alter table public.user_preferences enable row level security;
alter table public.user_settings enable row level security;
alter table public.custom_foods enable row level security;
alter table public.habits enable row level security;
alter table public.habit_logs enable row level security;
alter table public.scan_records enable row level security;

create policy "users can read their profile" on public.profiles for select using (auth.uid() = id);
create policy "users can update their profile" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);
create policy "users can insert their profile" on public.profiles for insert with check (auth.uid() = id);

create policy "users manage their preferences" on public.user_preferences for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "users manage their settings" on public.user_settings for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "users manage their custom foods" on public.custom_foods for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "users manage their habits" on public.habits for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "users manage their habit logs" on public.habit_logs for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "users manage their scan records" on public.scan_records for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', ''),
    new.raw_user_meta_data ->> 'avatar_url'
  ) on conflict (id) do nothing;
  insert into public.user_preferences (user_id) values (new.id) on conflict (user_id) do nothing;
  insert into public.user_settings (user_id) values (new.id) on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
