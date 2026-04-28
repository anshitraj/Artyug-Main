-- Marketplace core upgrade (non-destructive)
-- Safe to run on existing environments. Uses IF NOT EXISTS / guarded ALTERs.

create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- Shops
-- -----------------------------------------------------------------------------
create table if not exists public.shops (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  slug text unique,
  description text,
  cover_image_url text,
  avatar_url text,
  banner_url text,
  category text,
  niche text,
  tags text[] default '{}',
  status text not null default 'active' check (status in ('draft', 'active', 'archived')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.shops add column if not exists owner_id uuid references auth.users(id) on delete cascade;
alter table public.shops add column if not exists slug text;
alter table public.shops add column if not exists cover_image_url text;
alter table public.shops add column if not exists category text;
alter table public.shops add column if not exists niche text;
alter table public.shops add column if not exists status text default 'active';
alter table public.shops add column if not exists is_active boolean default true;
alter table public.shops add column if not exists updated_at timestamptz default now();
create unique index if not exists shops_slug_unique_idx on public.shops(slug) where slug is not null;
create index if not exists shops_owner_id_idx on public.shops(owner_id);
create index if not exists shops_status_idx on public.shops(status);

-- -----------------------------------------------------------------------------
-- Collections
-- -----------------------------------------------------------------------------
create table if not exists public.collections (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  name text not null,
  slug text,
  description text,
  cover_image_url text,
  artwork_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (shop_id, slug)
);

create index if not exists collections_shop_id_idx on public.collections(shop_id);
create index if not exists collections_name_idx on public.collections(name);

-- -----------------------------------------------------------------------------
-- Paintings marketplace columns
-- -----------------------------------------------------------------------------
alter table public.paintings add column if not exists shop_id uuid references public.shops(id) on delete set null;
alter table public.paintings add column if not exists collection_id uuid references public.collections(id) on delete set null;
alter table public.paintings add column if not exists listing_type text default 'fixed_price';
alter table public.paintings add column if not exists status text default 'active';
alter table public.paintings add column if not exists currency text default 'INR';
alter table public.paintings add column if not exists is_verified boolean default false;
alter table public.paintings add column if not exists nfc_status text default 'not_attached';
alter table public.paintings add column if not exists nfc_attached boolean default false;
alter table public.paintings add column if not exists solana_tx_id text;
alter table public.paintings add column if not exists owner_id uuid references auth.users(id) on delete set null;
alter table public.paintings add column if not exists views_count integer not null default 0;
alter table public.paintings add column if not exists likes_count integer not null default 0;
alter table public.paintings add column if not exists bids_count integer not null default 0;
alter table public.paintings add column if not exists purchases_count integer not null default 0;
alter table public.paintings add column if not exists style text;
alter table public.paintings add column if not exists year_created integer;
alter table public.paintings add column if not exists size_text text;
alter table public.paintings add column if not exists creator_location text;
alter table public.paintings add column if not exists trending_score double precision not null default 0;
alter table public.paintings add column if not exists updated_at timestamptz default now();

do $$
begin
  begin
    alter table public.paintings
      add constraint paintings_listing_type_check
      check (listing_type in ('fixed_price', 'auction', 'open_offer'));
  exception when duplicate_object then null;
  end;
  begin
    alter table public.paintings
      add constraint paintings_status_check
      check (status in ('draft', 'active', 'sold', 'cancelled'));
  exception when duplicate_object then null;
  end;
  begin
    alter table public.paintings
      add constraint paintings_nfc_status_check
      check (nfc_status in ('not_attached', 'attached', 'verified', 'failed'));
  exception when duplicate_object then null;
  end;
end $$;

create index if not exists paintings_shop_id_idx on public.paintings(shop_id);
create index if not exists paintings_collection_id_idx on public.paintings(collection_id);
create index if not exists paintings_listing_type_idx on public.paintings(listing_type);
create index if not exists paintings_status_idx on public.paintings(status);
create index if not exists paintings_trending_score_idx on public.paintings(trending_score desc);
create index if not exists paintings_created_at_idx on public.paintings(created_at desc);

-- -----------------------------------------------------------------------------
-- Auctions
-- -----------------------------------------------------------------------------
create table if not exists public.auctions (
  id uuid primary key default gen_random_uuid(),
  painting_id uuid not null references public.paintings(id) on delete cascade,
  seller_id uuid not null references auth.users(id) on delete cascade,
  starting_price numeric(14,2) not null check (starting_price > 0),
  reserve_price numeric(14,2),
  current_highest_bid numeric(14,2),
  current_highest_bidder_id uuid references auth.users(id) on delete set null,
  current_highest_bidder_name text,
  current_highest_bidder_avatar_url text,
  bid_increment numeric(14,2) not null default 500,
  start_time timestamptz not null default now(),
  end_time timestamptz not null,
  status text not null default 'upcoming',
  total_bids integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.auctions add column if not exists bid_increment numeric(14,2) default 500;
alter table public.auctions add column if not exists updated_at timestamptz default now();

do $$
begin
  begin
    alter table public.auctions
      add constraint auctions_status_check
      check (status in ('upcoming', 'live', 'ended', 'settled', 'cancelled', 'active', 'pending'));
  exception when duplicate_object then null;
  end;
end $$;

create index if not exists auctions_painting_id_idx on public.auctions(painting_id);
create index if not exists auctions_status_idx on public.auctions(status);
create index if not exists auctions_end_time_idx on public.auctions(end_time);

-- -----------------------------------------------------------------------------
-- Bids
-- -----------------------------------------------------------------------------
create table if not exists public.bids (
  id uuid primary key default gen_random_uuid(),
  auction_id uuid not null references public.auctions(id) on delete cascade,
  bidder_id uuid not null references auth.users(id) on delete cascade,
  amount numeric(14,2) not null check (amount > 0),
  status text not null default 'active',
  created_at timestamptz not null default now()
);

do $$
begin
  begin
    alter table public.bids
      add constraint bids_status_check
      check (status in ('active', 'outbid', 'won', 'cancelled'));
  exception when duplicate_object then null;
  end;
end $$;

create index if not exists bids_auction_id_idx on public.bids(auction_id, amount desc);
create index if not exists bids_bidder_id_idx on public.bids(bidder_id);

-- -----------------------------------------------------------------------------
-- Purchase intents (honest beta checkout)
-- -----------------------------------------------------------------------------
create table if not exists public.purchase_intents (
  id uuid primary key default gen_random_uuid(),
  painting_id uuid not null references public.paintings(id) on delete cascade,
  buyer_id uuid not null references auth.users(id) on delete cascade,
  amount numeric(14,2) not null,
  currency text not null default 'INR',
  status text not null default 'pending',
  payment_gateway text,
  payment_reference text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

do $$
begin
  begin
    alter table public.purchase_intents
      add constraint purchase_intents_status_check
      check (status in ('pending', 'paid', 'cancelled', 'expired', 'failed'));
  exception when duplicate_object then null;
  end;
end $$;

create index if not exists purchase_intents_painting_idx on public.purchase_intents(painting_id);
create index if not exists purchase_intents_buyer_idx on public.purchase_intents(buyer_id, created_at desc);

-- -----------------------------------------------------------------------------
-- Bid RPC with server-side validation
-- -----------------------------------------------------------------------------
create or replace function public.place_bid(
  p_auction_id uuid,
  p_bidder_id uuid,
  p_amount numeric
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_auction public.auctions%rowtype;
  v_painting public.paintings%rowtype;
  v_min numeric;
  v_bid public.bids%rowtype;
begin
  select * into v_auction
  from public.auctions
  where id = p_auction_id
  for update;

  if not found then
    raise exception 'AUCTION_NOT_FOUND';
  end if;

  select * into v_painting
  from public.paintings
  where id = v_auction.painting_id
  for update;

  if not found then
    raise exception 'PAINTING_NOT_FOUND';
  end if;

  if v_auction.status not in ('live', 'active') then
    raise exception 'AUCTION_NOT_LIVE';
  end if;

  if v_auction.end_time <= now() then
    raise exception 'AUCTION_ENDED';
  end if;

  if v_auction.seller_id = p_bidder_id or v_painting.artist_id = p_bidder_id then
    raise exception 'SELF_BID_BLOCKED';
  end if;

  v_min := coalesce(v_auction.current_highest_bid, v_auction.starting_price)
           + greatest(coalesce(v_auction.bid_increment, 500), 1);

  if p_amount < v_min then
    raise exception 'BID_TOO_LOW:MIN_%', v_min;
  end if;

  update public.bids
  set status = 'outbid'
  where auction_id = p_auction_id and status = 'active';

  insert into public.bids(auction_id, bidder_id, amount, status)
  values (p_auction_id, p_bidder_id, p_amount, 'active')
  returning * into v_bid;

  update public.auctions
  set current_highest_bid = p_amount,
      current_highest_bidder_id = p_bidder_id,
      total_bids = coalesce(total_bids, 0) + 1,
      updated_at = now()
  where id = p_auction_id;

  update public.paintings
  set bids_count = coalesce(bids_count, 0) + 1,
      updated_at = now()
  where id = v_auction.painting_id;

  return jsonb_build_object(
    'id', v_bid.id,
    'auction_id', v_bid.auction_id,
    'bidder_id', v_bid.bidder_id,
    'amount', v_bid.amount,
    'status', v_bid.status,
    'created_at', v_bid.created_at
  );
end;
$$;

grant execute on function public.place_bid(uuid, uuid, numeric) to authenticated, anon;

-- -----------------------------------------------------------------------------
-- Trending score refresh helper
-- -----------------------------------------------------------------------------
create or replace function public.refresh_painting_trending()
returns void
language sql
as $$
  update public.paintings p
  set trending_score =
      coalesce(p.views_count, 0) * 1
    + coalesce(p.likes_count, 0) * 3
    + coalesce(p.bids_count, 0) * 5
    + coalesce(p.purchases_count, 0) * 10
    + greatest(0, 30 - extract(day from (now() - coalesce(p.created_at, now()))))::double precision;
$$;

-- -----------------------------------------------------------------------------
-- RLS policies (guarded + idempotent)
-- -----------------------------------------------------------------------------
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'shops'
  ) then
    execute 'alter table public.shops enable row level security';

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public' and tablename = 'shops' and policyname = 'shops_select_public'
    ) then
      execute 'create policy shops_select_public on public.shops for select using (true)';
    end if;

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public' and tablename = 'shops' and policyname = 'shops_insert_owner'
    ) then
      execute 'create policy shops_insert_owner on public.shops for insert to authenticated with check (owner_id = auth.uid())';
    end if;

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public' and tablename = 'shops' and policyname = 'shops_update_owner'
    ) then
      execute 'create policy shops_update_owner on public.shops for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid())';
    end if;

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public' and tablename = 'shops' and policyname = 'shops_delete_owner'
    ) then
      execute 'create policy shops_delete_owner on public.shops for delete to authenticated using (owner_id = auth.uid())';
    end if;
  end if;
end $$;

do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'collections'
  ) then
    execute 'alter table public.collections enable row level security';

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public' and tablename = 'collections' and policyname = 'collections_select_public'
    ) then
      execute 'create policy collections_select_public on public.collections for select using (true)';
    end if;

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public' and tablename = 'collections' and policyname = 'collections_insert_shop_owner'
    ) then
      execute 'create policy collections_insert_shop_owner on public.collections for insert to authenticated with check (exists (select 1 from public.shops s where s.id = collections.shop_id and s.owner_id = auth.uid()))';
    end if;

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public' and tablename = 'collections' and policyname = 'collections_update_shop_owner'
    ) then
      execute 'create policy collections_update_shop_owner on public.collections for update to authenticated using (exists (select 1 from public.shops s where s.id = collections.shop_id and s.owner_id = auth.uid())) with check (exists (select 1 from public.shops s where s.id = collections.shop_id and s.owner_id = auth.uid()))';
    end if;

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public' and tablename = 'collections' and policyname = 'collections_delete_shop_owner'
    ) then
      execute 'create policy collections_delete_shop_owner on public.collections for delete to authenticated using (exists (select 1 from public.shops s where s.id = collections.shop_id and s.owner_id = auth.uid()))';
    end if;
  end if;
end $$;

do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'auctions'
  ) then
    execute 'alter table public.auctions enable row level security';

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public' and tablename = 'auctions' and policyname = 'auctions_select_public'
    ) then
      execute 'create policy auctions_select_public on public.auctions for select using (true)';
    end if;

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public' and tablename = 'auctions' and policyname = 'auctions_insert_seller'
    ) then
      execute 'create policy auctions_insert_seller on public.auctions for insert to authenticated with check (seller_id = auth.uid())';
    end if;

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public' and tablename = 'auctions' and policyname = 'auctions_update_seller'
    ) then
      execute 'create policy auctions_update_seller on public.auctions for update to authenticated using (seller_id = auth.uid()) with check (seller_id = auth.uid())';
    end if;

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public' and tablename = 'auctions' and policyname = 'auctions_delete_seller'
    ) then
      execute 'create policy auctions_delete_seller on public.auctions for delete to authenticated using (seller_id = auth.uid())';
    end if;
  end if;
end $$;

do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'bids'
  ) then
    execute 'alter table public.bids enable row level security';

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public' and tablename = 'bids' and policyname = 'bids_select_public'
    ) then
      execute 'create policy bids_select_public on public.bids for select using (true)';
    end if;

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public' and tablename = 'bids' and policyname = 'bids_insert_bidder'
    ) then
      execute 'create policy bids_insert_bidder on public.bids for insert to authenticated with check (bidder_id = auth.uid())';
    end if;
  end if;
end $$;

do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'purchase_intents'
  ) then
    execute 'alter table public.purchase_intents enable row level security';

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public' and tablename = 'purchase_intents' and policyname = 'purchase_intents_select_party'
    ) then
      execute 'create policy purchase_intents_select_party on public.purchase_intents for select to authenticated using (buyer_id = auth.uid() or exists (select 1 from public.paintings p where p.id = purchase_intents.painting_id and p.artist_id = auth.uid()))';
    end if;

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public' and tablename = 'purchase_intents' and policyname = 'purchase_intents_insert_buyer'
    ) then
      execute 'create policy purchase_intents_insert_buyer on public.purchase_intents for insert to authenticated with check (buyer_id = auth.uid())';
    end if;

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public' and tablename = 'purchase_intents' and policyname = 'purchase_intents_update_buyer'
    ) then
      execute 'create policy purchase_intents_update_buyer on public.purchase_intents for update to authenticated using (buyer_id = auth.uid()) with check (buyer_id = auth.uid())';
    end if;
  end if;
end $$;
