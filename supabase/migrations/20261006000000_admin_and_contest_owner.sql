-- 계정 유형: 관리자(admin) > 운영자(is_staff) > 심사위원(대회별 배정) > 참가자.
-- 운영자는 자기가 만든 대회만 수정·진행한다. 대회 삭제와 운영자 지정·해제는 관리자만 한다.
-- 관리자는 저장소에 아이디를 적지 않고 운영 DB 에서 직접 지정한다:
--   update public.profiles set is_admin = true where username = '<아이디>';

alter table public.profiles add column is_admin boolean not null default false;
alter table public.contests add column created_by uuid default auth.uid()
  references public.profiles on delete set null;

create function public.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false)
$$;

-- 관리자는 운영자 권한을 함께 가진다.
create or replace function public.is_organizer() returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((select is_staff or is_admin from public.profiles where id = auth.uid()), false)
$$;

-- 이 대회를 수정·진행할 수 있는가: 관리자, 또는 이 대회를 만든 운영자.
create function public.can_manage(p_slug text) returns boolean
language sql stable security definer set search_path = '' as $$
  select public.is_admin() or (public.is_organizer() and exists (
    select 1 from public.contests where slug = p_slug and created_by = auth.uid()))
$$;

create function public.contest_of_team(p_team_id bigint) returns text
language sql stable security definer set search_path = '' as $$
  select contest_slug from public.teams where id = p_team_id
$$;

create function public.contest_of_submission(p_submission_id bigint) returns text
language sql stable security definer set search_path = '' as $$
  select t.contest_slug from public.submissions s join public.teams t on t.id = s.team_id where s.id = p_submission_id
$$;

-- ---------------------------------------------------------------- RLS: 운영자 전체 → 대회 관리자
drop policy "운영자만 생성" on public.contests;
drop policy "운영자만 수정" on public.contests;
drop policy "운영자만 삭제" on public.contests;
create policy "운영자만 생성" on public.contests for insert
  with check (public.is_organizer() and created_by = auth.uid());
create policy "개설 운영자·관리자 수정" on public.contests for update
  using (public.can_manage(slug)) with check (public.is_admin() or created_by = auth.uid());
create policy "관리자만 삭제" on public.contests for delete using (public.is_admin());

drop policy "팀원·운영자 수정" on public.teams;
drop policy "팀원·운영자 삭제" on public.teams;
create policy "팀원·대회 관리자 수정" on public.teams for update
  using (public.is_member_of(id) or public.can_manage(contest_slug));
create policy "팀원·대회 관리자 삭제" on public.teams for delete
  using (public.is_member_of(id) or public.can_manage(contest_slug));

drop policy "운영자만 삭제" on public.participants;
create policy "대회 관리자만 삭제" on public.participants for delete
  using (public.can_manage(public.contest_of_team(team_id)));

drop policy "팀원·운영자 등록" on public.submissions;
drop policy "팀원·운영자 수정" on public.submissions;
drop policy "팀원·운영자 삭제" on public.submissions;
create policy "팀원·대회 관리자 등록" on public.submissions for insert
  with check (public.is_member_of(team_id) or public.can_manage(public.contest_of_team(team_id)));
create policy "팀원·대회 관리자 수정" on public.submissions for update
  using (public.is_member_of(team_id) or public.can_manage(public.contest_of_team(team_id)));
create policy "팀원·대회 관리자 삭제" on public.submissions for delete
  using (public.is_member_of(team_id) or public.can_manage(public.contest_of_team(team_id)));

drop policy "운영자만 해제" on public.judges;
create policy "대회 관리자만 해제" on public.judges for delete using (public.can_manage(contest_slug));

drop policy "본인 점수·운영자 조회" on public.scores;
drop policy "본인 점수·운영자 삭제" on public.scores;
create policy "본인 점수·대회 관리자 조회" on public.scores for select
  using (public.can_manage(public.contest_of_submission(submission_id))
    or exists (select 1 from public.judges j where j.id = judge_id and j.user_id = auth.uid()));
create policy "본인 점수·대회 관리자 삭제" on public.scores for delete
  using (public.can_manage(public.contest_of_submission(submission_id))
    or exists (select 1 from public.judges j where j.id = judge_id and j.user_id = auth.uid()));

drop policy "운영자 전용" on public.awards;
create policy "대회 관리자 전용" on public.awards for all
  using (public.can_manage(contest_slug)) with check (public.can_manage(contest_slug));

drop policy "운영자·배정 심사위원 조회" on public.submission_reviews;
create policy "대회 관리자·배정 심사위원 조회" on public.submission_reviews for select
  using (public.can_manage(public.contest_of_submission(submission_id))
    or public.is_judge_of(public.contest_of_submission(submission_id)));

-- ---------------------------------------------------------------- RPC
create or replace function public.require_manager(p_slug text) returns void
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.can_manage(p_slug) then
    raise exception '이 대회를 개설한 운영자나 관리자만 할 수 있습니다.' using errcode = '42501';
  end if;
end $$;

create or replace function public.scoreboard(p_slug text)
returns table (team_id bigint, team_name text, submission_title text, round text,
               average_score numeric, vote_count int, rank int)
language sql stable security definer set search_path = '' as $$
  with rounds as (
    select r, o from unnest(array['preliminary', 'final']) with ordinality as u (r, o)
    where r = 'preliminary' or public.can_manage(p_slug) or public.is_judge_of(p_slug)
  ), agg as (
    select t.id as team_id, t.name as team_name, s.title as submission_title, rd.r as round, rd.o,
      avg(sc.value) as avg_raw, count(sc.id)::int as vote_count
    from public.teams t
    cross join rounds rd
    left join public.submissions s on s.team_id = t.id
    left join public.scores sc on sc.submission_id = s.id and sc.round = rd.r
    where t.contest_slug = p_slug
    group by t.id, t.name, s.title, rd.r, rd.o
  )
  select team_id, team_name, submission_title, round, round(avg_raw, 2), vote_count,
    case when avg_raw is not null
      then (rank() over (partition by round, avg_raw is null order by avg_raw desc))::int end
  from agg
  order by o, avg_raw desc nulls last, team_name collate "C"
$$;

create or replace function public.assign_judge(p_slug text, p_username text)
returns setof public.judge_list
language plpgsql security definer set search_path = '' as $$
declare v_user uuid; v_id bigint;
begin
  perform public.require_manager(p_slug);
  select id into v_user from public.profiles where username = p_username;
  if v_user is null then
    raise exception '존재하지 않는 사용자입니다.' using errcode = 'P0002';
  end if;
  insert into public.judges (contest_slug, user_id) values (p_slug, v_user) returning id into v_id;
  return query select * from public.judge_list where id = v_id;
exception when unique_violation then
  raise exception '이미 이 대회의 심사위원으로 배정된 사용자입니다.' using errcode = '23505';
end $$;

create or replace function public.set_team_schedule(p_team_id bigint, p_order int, p_minutes int)
returns setof public.team_list
language plpgsql security definer set search_path = '' as $$
begin
  perform public.require_manager(public.contest_of_team(p_team_id));
  update public.teams set presentation_order = p_order, presentation_minutes = p_minutes where id = p_team_id;
  return query select * from public.team_list where id = p_team_id;
end $$;

create or replace function public.assign_presentation_order(p_slug text)
returns setof public.team_list
language plpgsql security definer set search_path = '' as $$
begin
  perform public.require_manager(p_slug);
  update public.teams t set presentation_order = o.n
  from (
    select t2.id, row_number() over (order by s.id is null, s.submitted_at, t2.name) as n
    from public.teams t2 left join public.submissions s on s.team_id = t2.id
    where t2.contest_slug = p_slug
  ) o where t.id = o.id;
  return query select * from public.team_list where contest = p_slug order by presentation_order;
end $$;

create or replace function public.start_presentation(p_team_id bigint)
returns setof public.team_list
language plpgsql security definer set search_path = '' as $$
declare v_slug text := public.contest_of_team(p_team_id); v_now timestamptz := now();
begin
  perform public.require_manager(v_slug);
  update public.teams set presentation_ended_at = v_now
  where contest_slug = v_slug and id <> p_team_id
    and presentation_started_at is not null and presentation_ended_at is null;
  update public.teams set presentation_started_at = v_now, presentation_ended_at = null where id = p_team_id;
  return query select * from public.team_list where id = p_team_id;
end $$;

create or replace function public.end_presentation(p_team_id bigint)
returns setof public.team_list
language plpgsql security definer set search_path = '' as $$
begin
  perform public.require_manager(public.contest_of_team(p_team_id));
  if (select presentation_started_at from public.teams where id = p_team_id) is null then
    raise exception '아직 시작하지 않은 발표입니다.' using errcode = '22023';
  end if;
  update public.teams set presentation_ended_at = now() where id = p_team_id;
  return query select * from public.team_list where id = p_team_id;
end $$;

create or replace function public.reset_presentation(p_team_id bigint)
returns setof public.team_list
language plpgsql security definer set search_path = '' as $$
begin
  perform public.require_manager(public.contest_of_team(p_team_id));
  update public.teams set presentation_started_at = null, presentation_ended_at = null where id = p_team_id;
  return query select * from public.team_list where id = p_team_id;
end $$;

-- 관리자: 아이디로 운영자 지정·해제. 관리자 권한 자체는 이 함수로 바꿀 수 없다.
create function public.set_organizer(p_username text, p_value boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then
    raise exception '관리자만 운영자를 지정할 수 있습니다.' using errcode = '42501';
  end if;
  update public.profiles set is_staff = p_value where username = p_username;
  if not found then
    raise exception '존재하지 않는 사용자입니다.' using errcode = 'P0002';
  end if;
end $$;

drop function public.require_organizer();
revoke execute on function public.require_manager(text) from anon, authenticated, public;
revoke execute on function public.set_organizer(text, boolean) from anon, public;
grant execute on function public.set_organizer(text, boolean) to authenticated;

-- 화면이 대회마다 관리 버튼을 보일지 정한다.
create or replace view public.contest_list with (security_invoker = true) as
select c.slug, c.name, c.description, c.status, c.start_at, c.end_at, c.created_at, c.updated_at,
  (select count(*) from public.teams t where t.contest_slug = c.slug)::int as team_count,
  public.is_judge_of(c.slug) as is_judge,
  c.presentation_minutes,
  public.can_manage(c.slug) as can_manage
from public.contests c;
