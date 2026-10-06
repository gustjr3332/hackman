-- 관리자·운영자(개설자)·심사위원 권한
begin;
create extension if not exists pgtap with schema extensions;
select * from no_plan();

insert into auth.users (id, email, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-0000000000b1', 'adm@t.local', '{"username":"t_adm"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000000b2', 'o1@t.local', '{"username":"t_org1"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000000b3', 'o2@t.local', '{"username":"t_org2"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000000b4', 'p@t.local', '{"username":"t_part"}', 'authenticated', 'authenticated');
update public.profiles set is_admin = true where username = 't_adm';
update public.profiles set is_staff = true where username in ('t_org1', 't_org2');

-- ---- 운영자1: 대회 개설
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b2","role":"authenticated"}', true);
set local role authenticated;
select lives_ok($$ insert into public.contests (slug, name, start_at, end_at) values ('t-own', '내 대회', now(), now()) $$,
  '운영자는 대회를 만든다');
select is((select can_manage from public.contest_list where slug = 't-own'), true, '만든 대회는 관리할 수 있다');
select lives_ok($$ select public.assign_judge('t-own', 't_part') $$, '자기 대회에 심사위원을 배정한다');
select results_eq($$ with x as (delete from public.contests where slug = 't-own' returning 1) select count(*)::int from x $$,
  $$ values (0) $$, '운영자는 대회를 삭제하지 못한다');
select throws_ok($$ select public.set_organizer('t_part', true) $$, '42501', null, '운영자는 운영자를 지정하지 못한다');
reset role;

-- ---- 운영자2: 남의 대회
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b3","role":"authenticated"}', true);
set local role authenticated;
select is((select can_manage from public.contest_list where slug = 't-own'), false, '남의 대회는 관리할 수 없다');
select results_eq($$ with x as (update public.contests set name = 'x' where slug = 't-own' returning 1) select count(*)::int from x $$,
  $$ values (0) $$, '남의 대회는 수정되지 않는다');
select throws_ok($$ select public.assign_presentation_order('t-own') $$, '42501', null, '남의 대회 발표 순서를 못 정한다');
reset role;

-- ---- 관리자
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000b1","role":"authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.set_organizer('t_part', true) $$, '관리자는 운영자를 지정한다');
select results_eq($$ with x as (update public.contests set name = '관리자 수정' where slug = 't-own' returning 1) select count(*)::int from x $$,
  $$ values (1) $$, '관리자는 모든 대회를 수정한다');
select results_eq($$ with x as (delete from public.contests where slug = 't-own' returning 1) select count(*)::int from x $$,
  $$ values (1) $$, '관리자는 대회를 삭제한다');
reset role;
select is((select is_staff from public.profiles where username = 't_part'), true, '지정 결과가 반영된다');

select * from finish();
rollback;
