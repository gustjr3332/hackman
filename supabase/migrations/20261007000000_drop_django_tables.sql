-- 옛 Django 테이블(auth_*, django_*, contests_*)을 지운다. 계정은 2026-09 에 Supabase 로 옮겼고,
-- 남아 있으면 탈퇴한 사람의 이메일·비밀번호 해시가 운영 DB 에 계속 남는다(개인정보처리방침 위반).
-- 실행 전 운영 DB 의 public 데이터를 저장소 밖에 백업했다(DEVELOPMENT.md 10장).
-- 테이블이 없는 환경(로컬·새 프로젝트)에서는 아무것도 하지 않는다. cascade 는 Django 테이블끼리의 FK 때문.
do $$
declare t record;
begin
  for t in
    select tablename from pg_tables
    where schemaname = 'public' and tablename ~ '^(auth_|django_|contests_)'
  loop
    execute format('drop table if exists public.%I cascade', t.tablename);
  end loop;
end $$;
