-- 본인 아이디 변경
begin;
create extension if not exists pgtap with schema extensions;
select * from no_plan();

insert into auth.users (id, email, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-0000000000c1', 'u1@t.local', '{"username":"t_u1"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000000c2', 'u2@t.local', '{"username":"t_u2"}', 'authenticated', 'authenticated');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c1","role":"authenticated"}', true);
set local role authenticated;
select lives_ok($$ update public.profiles set username = 't_new' where id = auth.uid() $$, '본인 아이디를 바꾼다');
select throws_ok($$ update public.profiles set username = 't_u2' where id = auth.uid() $$, '23505', null, '남의 아이디로는 못 바꾼다');
select throws_ok($$ update public.profiles set username = '한글 공백' where id = auth.uid() $$, '23514', null, '형식이 틀리면 막힌다');
select results_eq($$ with x as (update public.profiles set username = 't_hack' where username = 't_u2' returning 1) select count(*)::int from x $$,
  $$ values (0) $$, '남의 아이디는 바꾸지 못한다');
select throws_ok($$ update public.profiles set is_admin = true where id = auth.uid() $$, '42501', null, '관리자 권한은 스스로 못 바꾼다');
reset role;
select is(public.username_of('00000000-0000-0000-0000-0000000000c1'), 't_new', '바뀐 아이디가 반영된다');

select * from finish();
rollback;
