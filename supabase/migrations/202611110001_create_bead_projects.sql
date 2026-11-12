-- 拼豆图纸数据库建表脚本
-- 可在 Supabase Dashboard 的 SQL Editor 中执行。
-- 表、索引、策略和触发器已存在时会跳过，不删除现有数据或对象。
-- 用户账号由 Supabase Auth 管理，本脚本只创建图纸和格子业务表。

begin;

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  rows integer not null check (rows between 1 and 1000),
  columns integer not null check (columns between 1 and 1000),
  palette_code text not null default 'MARD',
  palette_version text,
  schema_version integer not null default 1 check (schema_version > 0),
  source_image_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists projects_user_updated_at_idx
  on public.projects (user_id, updated_at desc);

create table if not exists public.project_cells (
  project_id uuid not null references public.projects (id) on delete cascade,
  row_index integer not null check (row_index >= 0),
  column_index integer not null check (column_index >= 0),
  has_bead boolean not null default false,
  color_id text,
  color_hex text,
  is_uncertain boolean not null default false,
  needs_review boolean not null default false,
  is_manually_corrected boolean not null default false,
  primary key (project_id, row_index, column_index),
  constraint project_cells_color_matches_bead check (
    (has_bead and color_id is not null and color_hex is not null)
    or (not has_bead and color_id is null and color_hex is null)
  )
);

alter table public.projects enable row level security;
alter table public.project_cells enable row level security;

grant select, insert, update, delete on public.projects to authenticated;
grant select, insert, update, delete on public.project_cells to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'projects'
      and policyname = 'Users can view their own projects'
  ) then
    create policy "Users can view their own projects"
      on public.projects for select to authenticated
      using ((select auth.uid()) = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'projects'
      and policyname = 'Users can create their own projects'
  ) then
    create policy "Users can create their own projects"
      on public.projects for insert to authenticated
      with check ((select auth.uid()) = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'projects'
      and policyname = 'Users can update their own projects'
  ) then
    create policy "Users can update their own projects"
      on public.projects for update to authenticated
      using ((select auth.uid()) = user_id)
      with check ((select auth.uid()) = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'projects'
      and policyname = 'Users can delete their own projects'
  ) then
    create policy "Users can delete their own projects"
      on public.projects for delete to authenticated
      using ((select auth.uid()) = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'project_cells'
      and policyname = 'Users can view cells in their own projects'
  ) then
    create policy "Users can view cells in their own projects"
      on public.project_cells for select to authenticated
      using (
        exists (
          select 1 from public.projects
          where projects.id = project_cells.project_id
            and projects.user_id = (select auth.uid())
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'project_cells'
      and policyname = 'Users can create cells in their own projects'
  ) then
    create policy "Users can create cells in their own projects"
      on public.project_cells for insert to authenticated
      with check (
        exists (
          select 1 from public.projects
          where projects.id = project_cells.project_id
            and projects.user_id = (select auth.uid())
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'project_cells'
      and policyname = 'Users can update cells in their own projects'
  ) then
    create policy "Users can update cells in their own projects"
      on public.project_cells for update to authenticated
      using (
        exists (
          select 1 from public.projects
          where projects.id = project_cells.project_id
            and projects.user_id = (select auth.uid())
        )
      )
      with check (
        exists (
          select 1 from public.projects
          where projects.id = project_cells.project_id
            and projects.user_id = (select auth.uid())
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'project_cells'
      and policyname = 'Users can delete cells in their own projects'
  ) then
    create policy "Users can delete cells in their own projects"
      on public.project_cells for delete to authenticated
      using (
        exists (
          select 1 from public.projects
          where projects.id = project_cells.project_id
            and projects.user_id = (select auth.uid())
        )
      );
  end if;
end;
$$;

create or replace function public.set_project_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'set_projects_updated_at'
      and tgrelid = 'public.projects'::regclass
      and not tgisinternal
  ) then
    create trigger set_projects_updated_at
      before update on public.projects
      for each row execute function public.set_project_updated_at();
  end if;
end;
$$;

commit;
