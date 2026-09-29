-- 운영자가 대회 생성 시 검색엔진 sitemap 노출 여부를 고른다. frontend/api/sitemap.ts 가 읽는다.
alter table public.contests add column in_sitemap boolean not null default false;
