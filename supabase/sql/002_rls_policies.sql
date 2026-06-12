alter table medhavn.medication_plans enable row level security;
alter table medhavn.dose_logs enable row level security;
alter table medhavn.user_settings enable row level security;
alter table medhavn.user_consents enable row level security;

drop policy if exists "plans own rows" on medhavn.medication_plans;
create policy "plans own rows"
  on medhavn.medication_plans
  for all
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "dose logs own rows" on medhavn.dose_logs;
create policy "dose logs own rows"
  on medhavn.dose_logs
  for all
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "settings own row" on medhavn.user_settings;
create policy "settings own row"
  on medhavn.user_settings
  for all
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "consents own rows" on medhavn.user_consents;
create policy "consents own rows"
  on medhavn.user_consents
  for all
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);