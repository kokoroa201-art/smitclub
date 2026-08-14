-- SMIT Club Portal — initial schema
-- profiles, clubs, club creation applications (+ founders), memberships,
-- club board (posts/comments), certificates, plus RLS and supporting triggers.

create extension if not exists pgcrypto;

-- =========================================================================
-- profiles (1:1 with auth.users)
-- =========================================================================

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null,
  student_id text,
  affiliation text,
  role text not null default 'student' check (role in ('student', 'club_admin', 'super_admin')),
  locale_pref text not null default 'ko' check (locale_pref in ('ko', 'en')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- =========================================================================
-- clubs
-- =========================================================================

create table public.clubs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  name_en text,
  slug text not null unique,
  category text not null,
  status text not null default 'preparing' check (status in ('preparing', 'recruiting', 'active', 'closed')),
  description text,
  description_en text,
  cover_image_url text,
  logo_url text,
  meeting_day text,
  meeting_time text,
  meeting_location text,
  founded_year int,
  president_id uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

alter table public.clubs enable row level security;

-- =========================================================================
-- club_applications (동아리 개설 신청)
-- =========================================================================

create table public.club_applications (
  id uuid primary key default gen_random_uuid(),
  applicant_id uuid not null references public.profiles (id),
  club_name text not null,
  category text not null,
  purpose text not null,
  activity_plan text not null,
  meeting_day text,
  meeting_time text,
  meeting_location text,
  agree_rules boolean not null default false,
  status text not null default 'draft' check (status in ('draft', 'submitted', 'needs_revision', 'approved', 'rejected')),
  validation_passed boolean not null default false,
  admin_note text,
  reviewed_by uuid references public.profiles (id),
  reviewed_at timestamptz,
  resulting_club_id uuid references public.clubs (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.club_applications enable row level security;

create index club_applications_applicant_id_idx on public.club_applications (applicant_id);

-- =========================================================================
-- club_application_founders (신청서에 종속된 창립회원 명단 — 자동검증이 참조)
-- =========================================================================

create table public.club_application_founders (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.club_applications (id) on delete cascade,
  name text not null,
  student_id text,
  is_current_student boolean not null default true,
  contact text
);

alter table public.club_application_founders enable row level security;

create index club_application_founders_application_id_idx on public.club_application_founders (application_id);

-- =========================================================================
-- club_memberships (개인 가입 신청 → 동아리장 승인)
-- =========================================================================

create table public.club_memberships (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs (id),
  user_id uuid not null references public.profiles (id),
  status text not null default 'applied' check (status in ('applied', 'approved', 'rejected', 'left')),
  motivation text,
  applied_at timestamptz not null default now(),
  reviewed_by uuid references public.profiles (id),
  reviewed_at timestamptz,
  unique (club_id, user_id)
);

alter table public.club_memberships enable row level security;

create index club_memberships_club_id_idx on public.club_memberships (club_id);
create index club_memberships_user_id_idx on public.club_memberships (user_id);

-- =========================================================================
-- club_posts / club_post_comments (동아리별 게시판)
-- =========================================================================

create table public.club_posts (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs (id),
  author_id uuid not null references public.profiles (id),
  type text not null default 'general' check (type in ('notice', 'event', 'general')),
  title text not null,
  content text not null,
  event_date timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.club_posts enable row level security;

create index club_posts_club_id_idx on public.club_posts (club_id);

create table public.club_post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.club_posts (id) on delete cascade,
  author_id uuid not null references public.profiles (id),
  content text not null,
  created_at timestamptz not null default now()
);

alter table public.club_post_comments enable row level security;

create index club_post_comments_post_id_idx on public.club_post_comments (post_id);

-- =========================================================================
-- certificates (활동/창립 인증서)
-- =========================================================================

create table public.certificates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id),
  club_id uuid not null references public.clubs (id),
  type text not null default 'activity' check (type in ('activity', 'founding')),
  period_start date,
  period_end date,
  issued_by uuid references public.profiles (id),
  pdf_url text,
  issued_at timestamptz not null default now()
);

alter table public.certificates enable row level security;

create index certificates_user_id_idx on public.certificates (user_id);
create index certificates_club_id_idx on public.certificates (club_id);

-- =========================================================================
-- Helper functions (security definer — safe to query RLS-protected tables
-- from inside policies without recursion)
-- =========================================================================

create or replace function public.is_super_admin()
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles where id = auth.uid() and role = 'super_admin'
  );
$$;

create or replace function public.is_club_president(target_club_id uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.clubs where id = target_club_id and president_id = auth.uid()
  );
$$;

create or replace function public.is_approved_club_member(target_club_id uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.club_memberships
    where club_id = target_club_id and user_id = auth.uid() and status = 'approved'
  );
$$;

-- =========================================================================
-- profiles: signup creates the row automatically; role can only be changed
-- by an administrator (or the service_role key), never by the row's owner.
-- =========================================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, name, student_id, affiliation)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'name', split_part(new.email, '@', 1)),
    new.raw_user_meta_data ->> 'student_id',
    new.raw_user_meta_data ->> 'affiliation'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.enforce_profile_role_guard()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.role is distinct from old.role then
    if auth.role() = 'service_role' then
      return new;
    elsif public.is_super_admin() and auth.uid() <> old.id then
      return new;
    else
      raise exception 'insufficient privilege to change role';
    end if;
  end if;
  return new;
end;
$$;

create trigger profiles_role_guard
before update on public.profiles
for each row execute function public.enforce_profile_role_guard();

create policy "profiles_select_authenticated" on public.profiles
  for select to authenticated using (true);

create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- =========================================================================
-- clubs: publicly browsable; only an admin can create a club (via the
-- application-approval flow); the club's own president can edit it.
-- =========================================================================

create policy "clubs_select_public" on public.clubs
  for select using (true);

create policy "clubs_insert_admin" on public.clubs
  for insert with check (public.is_super_admin());

create policy "clubs_update_admin_or_president" on public.clubs
  for update
  using (public.is_super_admin() or president_id = auth.uid())
  with check (public.is_super_admin() or president_id = auth.uid());

-- =========================================================================
-- club_applications / club_application_founders
-- =========================================================================

create policy "club_applications_select_own_or_admin" on public.club_applications
  for select using (applicant_id = auth.uid() or public.is_super_admin());

create policy "club_applications_insert_own" on public.club_applications
  for insert with check (applicant_id = auth.uid());

create policy "club_applications_update_admin" on public.club_applications
  for update using (public.is_super_admin()) with check (public.is_super_admin());

-- The applicant may only edit their own application while it is still in
-- draft or needs_revision; submitted/approved/rejected become read-only to
-- them. The WITH CHECK here only bounds which *status* they may move to
-- (never approved/rejected) — it cannot see old vs. new column values, so
-- the review-only fields (validation_passed, admin_note, reviewed_by,
-- reviewed_at, resulting_club_id) are separately locked down by the
-- enforce_application_admin_fields_guard trigger below.
create policy "club_applications_update_applicant" on public.club_applications
  for update
  using (applicant_id = auth.uid() and status in ('draft', 'needs_revision'))
  with check (applicant_id = auth.uid() and status in ('draft', 'submitted', 'needs_revision'));

-- Guards both INSERT and UPDATE: a non-admin applicant's insert policy only
-- checks applicant_id, so without this the review-only fields (and an
-- immediate 'approved' status) could otherwise be set straight from the
-- initial insert, bypassing the review flow entirely.
create or replace function public.enforce_application_admin_fields_guard()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.role() = 'service_role' or public.is_super_admin() then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.status not in ('draft', 'submitted')
      or new.validation_passed is distinct from false
      or new.admin_note is not null
      or new.reviewed_by is not null
      or new.reviewed_at is not null
      or new.resulting_club_id is not null then
      raise exception 'insufficient privilege to set review fields on insert';
    end if;
    return new;
  end if;

  if new.validation_passed is distinct from old.validation_passed
    or new.admin_note is distinct from old.admin_note
    or new.reviewed_by is distinct from old.reviewed_by
    or new.reviewed_at is distinct from old.reviewed_at
    or new.resulting_club_id is distinct from old.resulting_club_id then
    raise exception 'insufficient privilege to modify review fields';
  end if;

  return new;
end;
$$;

create trigger club_applications_admin_fields_guard
before insert or update on public.club_applications
for each row execute function public.enforce_application_admin_fields_guard();

create policy "club_application_founders_select" on public.club_application_founders
  for select using (
    exists (
      select 1 from public.club_applications a
      where a.id = application_id and (a.applicant_id = auth.uid() or public.is_super_admin())
    )
  );

create policy "club_application_founders_insert" on public.club_application_founders
  for insert with check (
    exists (
      select 1 from public.club_applications a
      where a.id = application_id and a.applicant_id = auth.uid()
    )
  );

-- =========================================================================
-- club_memberships: a student applies for themself; the club's president
-- (or a super admin) reviews.
-- =========================================================================

create policy "club_memberships_select" on public.club_memberships
  for select using (
    user_id = auth.uid() or public.is_club_president(club_id) or public.is_super_admin()
  );

create policy "club_memberships_insert_own" on public.club_memberships
  for insert with check (user_id = auth.uid());

create policy "club_memberships_update_review" on public.club_memberships
  for update
  using (public.is_club_president(club_id) or public.is_super_admin())
  with check (public.is_club_president(club_id) or public.is_super_admin());

-- =========================================================================
-- club_posts / club_post_comments: readable by anyone; writable by the
-- club's approved members, its president, or a super admin.
-- =========================================================================

create policy "club_posts_select_public" on public.club_posts
  for select using (true);

create policy "club_posts_insert_member" on public.club_posts
  for insert with check (
    author_id = auth.uid()
    and (public.is_approved_club_member(club_id) or public.is_club_president(club_id) or public.is_super_admin())
  );

create policy "club_posts_update_own_or_admin" on public.club_posts
  for update
  using (author_id = auth.uid() or public.is_club_president(club_id) or public.is_super_admin())
  with check (author_id = auth.uid() or public.is_club_president(club_id) or public.is_super_admin());

create policy "club_post_comments_select_public" on public.club_post_comments
  for select using (true);

create policy "club_post_comments_insert_member" on public.club_post_comments
  for insert with check (
    author_id = auth.uid()
    and exists (
      select 1 from public.club_posts p
      where p.id = post_id
        and (public.is_approved_club_member(p.club_id) or public.is_club_president(p.club_id) or public.is_super_admin())
    )
  );

create policy "club_post_comments_update_own" on public.club_post_comments
  for update using (author_id = auth.uid()) with check (author_id = auth.uid());

-- =========================================================================
-- certificates: issued by an admin/president; visible to the recipient,
-- the issuing club's president, or a super admin.
-- =========================================================================

create policy "certificates_select" on public.certificates
  for select using (
    user_id = auth.uid() or public.is_club_president(club_id) or public.is_super_admin()
  );

create policy "certificates_insert_issuer" on public.certificates
  for insert with check (public.is_club_president(club_id) or public.is_super_admin());

-- =========================================================================
-- updated_at maintenance
-- =========================================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger club_applications_set_updated_at
before update on public.club_applications
for each row execute function public.set_updated_at();

create trigger club_posts_set_updated_at
before update on public.club_posts
for each row execute function public.set_updated_at();
