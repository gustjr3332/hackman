-- 소셜 로그인(Google·GitHub) 가입자와 회원 탈퇴.

-- 이메일 가입은 지금처럼 고른 아이디를 그대로 쓰고, 겹치면 가입이 실패한다(화면이 그 오류를 안내).
-- 소셜 가입은 아이디를 고를 기회가 없으므로 GitHub 아이디나 이메일 앞부분에서 만들고, 허용 문자만
-- 남기고, 겹치면 뒤에 4자리를 붙인다. 겹쳐서 가입이 실패하면 소셜 로그인 자체가 막히기 때문이다.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_base text;
  v_name text;
begin
  if new.raw_user_meta_data ? 'username' then
    insert into public.profiles (id, username) values (new.id, new.raw_user_meta_data ->> 'username');
    return new;
  end if;

  v_base := left(regexp_replace(
    coalesce(new.raw_user_meta_data ->> 'user_name', split_part(new.email, '@', 1), ''),
    '[^A-Za-z0-9_.@+-]', '', 'g'), 140);
  if v_base = '' then v_base := 'user'; end if;
  v_name := v_base;
  while exists (select 1 from public.profiles where username = v_name) loop
    v_name := v_base || '_' || substr(md5(random()::text), 1, 4);
  end loop;
  insert into public.profiles (id, username) values (new.id, v_name);
  return new;
end $$;

-- 본인 탈퇴. auth.users 를 지우면 profiles → 팀 참가·심사위원 배정까지 cascade 로 지워진다.
-- 채점 기록이 있는 심사위원은 judges_guard 가 막는다(점수가 사라지면 순위가 바뀐다).
create function public.delete_my_account() returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.' using errcode = '42501';
  end if;
  if exists (select 1 from public.scores s join public.judges j on j.id = s.judge_id where j.user_id = auth.uid()) then
    raise exception '채점 기록이 있는 심사위원 계정은 바로 탈퇴할 수 없습니다. 운영자에게 문의해 주세요.'
      using errcode = '42501';
  end if;
  delete from auth.users where id = auth.uid();
end $$;

revoke execute on function public.delete_my_account() from anon, public;
grant execute on function public.delete_my_account() to authenticated;
