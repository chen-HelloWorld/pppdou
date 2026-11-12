-- 在 Supabase SQL Editor 执行。保留旧格子表作为备份。
begin;
alter table public.projects add column if not exists grid_data jsonb;
-- 仅迁移格子数量与尺寸一致的图纸，避免把不完整记录标记为完整。
with complete as (
  select p.id, jsonb_build_object(
    'version', 1,
    'cells', jsonb_agg(jsonb_build_array(c.color_id, c.color_hex, c.is_uncertain, c.needs_review, c.is_manually_corrected) order by c.row_index, c.column_index)
  ) as data
  from public.projects p join public.project_cells c on c.project_id = p.id
  where p.grid_data is null and c.row_index < p.rows and c.column_index < p.columns
  group by p.id, p.rows, p.columns
  having count(*) = p.rows * p.columns
)
update public.projects p set grid_data = complete.data, schema_version = 2
from complete where p.id = complete.id and p.grid_data is null;
commit;
