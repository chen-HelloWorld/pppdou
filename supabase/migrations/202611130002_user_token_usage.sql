-- 每个用户一条 Token 汇总记录。可在 Supabase SQL Editor 中执行。
-- 仅创建统计结构及读取权限；额度扣减需要由可信服务端完成。
begin;

create table if not exists public.user_token_usage (
  user_id uuid primary key references auth.users(id) on delete cascade,
  daily_limit bigint not null default 200000 check (daily_limit >= 0),
  usage_date date not null default ((now() at time zone 'Asia/Shanghai')::date),
  daily_used_tokens bigint not null default 0 check (daily_used_tokens >= 0),
  total_used_tokens bigint not null default 0 check (total_used_tokens >= 0),
  updated_at timestamptz not null default now()
);

alter table public.user_token_usage enable row level security;
revoke all on public.user_token_usage from anon, authenticated;
grant select on public.user_token_usage to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public'
      and tablename = 'user_token_usage' and policyname = 'Users can view their own token usage'
  ) then
    create policy "Users can view their own token usage"
      on public.user_token_usage for select to authenticated
      using ((select auth.uid()) = user_id);
  end if;
end;
$$;

commit;
