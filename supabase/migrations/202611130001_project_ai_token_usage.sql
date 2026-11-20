-- 在 Supabase SQL Editor 执行：记录每张图纸在 AI 分析中消耗的累计 token。
begin;

alter table public.projects
  add column if not exists ai_token_usage bigint not null default 0;

alter table public.projects
  drop constraint if exists projects_ai_token_usage_nonnegative;

alter table public.projects
  add constraint projects_ai_token_usage_nonnegative
  check (ai_token_usage >= 0);

commit;
