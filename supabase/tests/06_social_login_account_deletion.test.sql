-- 소셜 가입 아이디 생성, 회원 탈퇴
begin;
create extension if not exists pgtap with schema extensions;
select * from no_plan();

insert into auth.users (id, email, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-0000000000a1', 'kim@gmail.com', '{"username":"kim"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000000a2', 'kim@naver.com', '{"full_name":"김"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000000a3', 'x@t.local', '{"user_name":"octo-cat"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000000a4', '홍길동@t.local', '{}', 'authenticated', 'authenticated');

select is(public.username_of('00000000-0000-0000-0000-0000000000a3'), 'octo-cat', 'GitHub 가입은 GitHub 아이디를 쓴다');
select matches(public.username_of('00000000-0000-0000-0000-0000000000a2'), '^kim_[0-9a-f]{4}$',
  '소셜 가입 아이디가 겹치면 뒤에 4자리를 붙인다');
select is(public.username_of('00000000-0000-0000-0000-0000000000a4'), 'user', '허용 문자가 없으면 user');
select throws_ok($$ insert into auth.users (id, email, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-0000000000a5', 'k2@t.local', '{"username":"kim"}', 'authenticated', 'authenticated') $$,
  '23505', null, '이메일 가입은 아이디가 겹치면 여전히 실패한다');

select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok($$ select public.delete_my_account() $$, '42501', null, '비로그인은 탈퇴 함수를 못 부른다');
reset role;

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a3","role":"authenticated"}', true);
set local role authenticated;
select lives_ok($$ select public.delete_my_account() $$, '본인은 탈퇴할 수 있다');
reset role;
select is((select count(*)::int from auth.users where id = '00000000-0000-0000-0000-0000000000a3'), 0, '계정이 지워진다');
select is((select count(*)::int from public.profiles where id = '00000000-0000-0000-0000-0000000000a3'), 0, '프로필도 지워진다');

select * from finish();
rollback;
