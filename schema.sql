-- 1ST MARKET: schema + baseline Row Level Security policies.
-- Run this file in Supabase Dashboard > SQL Editor.
-- Give admin access by creating a user in Authentication > Users. Only authenticated
-- users with app_metadata.role = 'admin' can change catalog, orders or settings.
-- Never put the service_role key in the website.

create extension if not exists pgcrypto;

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null default 'بقالة',
  price numeric(10,2) not null default 0 check (price >= 0),
  old_price numeric(10,2) check (old_price is null or old_price >= 0),
  stock integer not null default 0 check (stock >= 0),
  image text not null default '',
  images jsonb not null default '[]'::jsonb,
  emoji text not null default '🛍️',
  description text not null default '',
  brand text not null default '',
  unit text not null default '',
  size text not null default '',
  origin text not null default '',
  ingredients text not null default '',
  storage_info text not null default '',
  expiry_date text not null default '',
  rating numeric(2,1) not null default 4.8,
  review_count integer not null default 0,
  featured boolean not null default false,
  bestseller boolean not null default false,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.products add column if not exists images jsonb not null default '[]'::jsonb;
alter table public.products add column if not exists brand text not null default '';
alter table public.products add column if not exists unit text not null default '';
alter table public.products add column if not exists size text not null default '';
alter table public.products add column if not exists origin text not null default '';
alter table public.products add column if not exists ingredients text not null default '';
alter table public.products add column if not exists storage_info text not null default '';
alter table public.products add column if not exists expiry_date text not null default '';
alter table public.products add column if not exists rating numeric(2,1) not null default 4.8;
alter table public.products add column if not exists review_count integer not null default 0;

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  emoji text not null default '🛍️',
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  customer_name text not null,
  phone text not null,
  address text not null,
  notes text not null default '',
  items jsonb not null default '[]'::jsonb,
  total numeric(10,2) not null check (total >= 0),
  status text not null default 'جديد' check (status in ('جديد','قيد التجهيز','خرج للتوصيل','تم التوصيل','ملغي')),
  created_at timestamptz not null default now()
);

create table if not exists public.store_settings (
  id integer primary key check (id = 1),
  settings jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
create table if not exists public.banners (
  id uuid primary key default gen_random_uuid(),
  title text not null default '',
  subtitle text not null default '',
  button_text text not null default 'تسوق الآن',
  image text not null default '',
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
insert into public.store_settings (id, settings) values (1, '{"store_name":"1ST MARKET","currency":"ج.م","delivery_fee":0}') on conflict (id) do nothing;

create or replace function public.is_market_admin() returns boolean
language sql stable security invoker
set search_path = ''
as $$ select coalesce((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin', false); $$;

alter table public.products enable row level security;
alter table public.categories enable row level security;
alter table public.orders enable row level security;
alter table public.store_settings enable row level security;
alter table public.banners enable row level security;

drop policy if exists "Public can see active products" on public.products;
create policy "Public can see active products" on public.products for select to anon, authenticated using (active = true or public.is_market_admin());
drop policy if exists "Admin manages products" on public.products;
create policy "Admin manages products" on public.products for all to authenticated using (public.is_market_admin()) with check (public.is_market_admin());

drop policy if exists "Public can see categories" on public.categories;
create policy "Public can see categories" on public.categories for select to anon, authenticated using (true);
drop policy if exists "Admin manages categories" on public.categories;
create policy "Admin manages categories" on public.categories for all to authenticated using (public.is_market_admin()) with check (public.is_market_admin());

drop policy if exists "Customers can place orders" on public.orders;
create policy "Customers can place orders" on public.orders for insert to anon, authenticated with check (status = 'جديد');
drop policy if exists "Admin reads orders" on public.orders;
create policy "Admin reads orders" on public.orders for select to authenticated using (public.is_market_admin());
drop policy if exists "Admin updates orders" on public.orders;
create policy "Admin updates orders" on public.orders for update to authenticated using (public.is_market_admin()) with check (public.is_market_admin());

drop policy if exists "Public can read store settings" on public.store_settings;
create policy "Public can read store settings" on public.store_settings for select to anon, authenticated using (true);
drop policy if exists "Admin manages store settings" on public.store_settings;
create policy "Admin manages store settings" on public.store_settings for all to authenticated using (public.is_market_admin()) with check (public.is_market_admin());

drop policy if exists "Public can see active banners" on public.banners;
create policy "Public can see active banners" on public.banners for select to anon, authenticated using (active = true or public.is_market_admin());
drop policy if exists "Admin manages banners" on public.banners;
create policy "Admin manages banners" on public.banners for all to authenticated using (public.is_market_admin()) with check (public.is_market_admin());

grant usage on schema public to anon, authenticated;
grant select on public.products, public.categories, public.store_settings to anon, authenticated;
grant insert on public.orders to anon, authenticated;
grant select, update on public.orders to authenticated;
grant insert, update, delete on public.products, public.categories, public.store_settings to authenticated;
grant select on public.banners to anon, authenticated;
grant insert, update, delete on public.banners to authenticated;

-- Public product photos and banners; only admins may upload/delete.
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('market-media','market-media',true,8388608,array['image/jpeg','image/png','image/webp','image/avif'])
on conflict (id) do update set public=true, file_size_limit=8388608;
drop policy if exists "Public reads market media" on storage.objects;
create policy "Public reads market media" on storage.objects for select to anon, authenticated using (bucket_id='market-media');
drop policy if exists "Admin uploads market media" on storage.objects;
create policy "Admin uploads market media" on storage.objects for insert to authenticated with check (bucket_id='market-media' and public.is_market_admin());
drop policy if exists "Admin updates market media" on storage.objects;
create policy "Admin updates market media" on storage.objects for update to authenticated using (bucket_id='market-media' and public.is_market_admin()) with check (bucket_id='market-media' and public.is_market_admin());
drop policy if exists "Admin deletes market media" on storage.objects;
create policy "Admin deletes market media" on storage.objects for delete to authenticated using (bucket_id='market-media' and public.is_market_admin());

create or replace function public.lookup_market_order(p_order_number text, p_phone text)
returns jsonb language sql stable security definer set search_path=public
as $$ select to_jsonb(o) from public.orders o where o.order_number=p_order_number and regexp_replace(o.phone,'[^0-9]','','g')=regexp_replace(p_phone,'[^0-9]','','g') limit 1; $$;
revoke all on function public.lookup_market_order(text,text) from public;
grant execute on function public.lookup_market_order(text,text) to anon, authenticated;

-- Add your first products/categories from the site after admin setup, or seed here.
insert into public.categories(name,emoji,sort_order) values
 ('عروض اليوم','🧺',1),('ألبان ومنتجاتها','🥛',2),('خضروات وفواكه','🥬',3),
 ('لحوم ودواجن','🥩',4),('بقالة','🍪',5),('منظفات','🧴',6),('زيوت وسمنة','🫒',7)
on conflict(name) do nothing;

insert into public.products(name,category,price,old_price,stock,emoji,description,featured,bestseller,sort_order)
select v.* from (values
 ('زيت ذرة حلوة 1 لتر','زيوت وسمنة',51::numeric,60::numeric,28,'🫒','زيت ذرة نقي 100%، بطعم خفيف مناسب لجميع أطباقك.',true,true,1),
 ('جبنة كيري مثلثات','ألبان ومنتجاتها',75::numeric,null::numeric,34,'🧀','جبنة كريمية لذيذة مناسبة للفطار والسندوتشات.',true,true,2),
 ('أرز مصري 1 كجم','بقالة',32::numeric,null::numeric,60,'🍚','أرز مصري أبيض عالي الجودة.',true,false,3),
 ('حليب المراعي 1 لتر','ألبان ومنتجاتها',36::numeric,null::numeric,22,'🥛','حليب طازج كامل الدسم.',true,false,4),
 ('بيض أحمر طبق 30 بيضة','ألبان ومنتجاتها',82::numeric,null::numeric,16,'🥚','بيض طازج من مزارع موثوقة.',false,true,5),
 ('دقيق ممتاز 1 كجم','بقالة',22::numeric,null::numeric,45,'🌾','دقيق قمح متعدد الاستخدامات.',false,true,6),
 ('مكرونة 350 جم','بقالة',12::numeric,null::numeric,70,'🍝','مكرونة قمح صلب سهلة التحضير.',false,true,7),
 ('فول مدمس 400 جم','بقالة',18::numeric,null::numeric,38,'🥫','فول جاهز للإفطار بطعم بيتي.',false,true,8)
) as v(name,category,price,old_price,stock,emoji,description,featured,bestseller,sort_order)
where not exists(select 1 from public.products p where p.name=v.name);

insert into public.banners(title,subtitle,button_text,sort_order)
select 'كل احتياجاتك من نفس المكان','اختار اللي ناقصك وإحنا نوصله لحد البيت','تسوق الآن',1
where not exists(select 1 from public.banners);

