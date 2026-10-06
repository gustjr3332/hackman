-- 본인 아이디를 프로필 설정에서 바꾼다. 형식·중복은 기존 check·unique 가 막고, 본인 행만은 RLS 가 막는다.
grant update (username) on public.profiles to authenticated;
