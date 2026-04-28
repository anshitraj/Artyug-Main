-- Remote compatibility patch for marketplace core upgrade
-- Designed for linked Artyug project where legacy table shapes already exist.

create extension if not exists pgcrypto;

-- Shops hardening
alter table public.shops add column if not exists slug text;
alter table public.shops add column if not exists cover_image_url text;
alter table public.shops add column if not exists category text;
alter table public.shops add column if not exists niche text;
alter table public.shops add column if not exists status text default 'active';
create unique index if not exists shops_slug_unique_idx on public.shops(slug) where slug is not null;

-- Collections hardening (legacy text-id table)
alter table public.collections add column if not exists shop_id uuid;
alter table public.collections add column if not exists cover_image_url text;
alter table public.collections add column if not exists updated_at timestamptz default now();
update public.collections set cover_image_url = cover_url where cover_image_url is null and cover_url is not null;

-- Paintings compatibility columns
alter table public.paintings add column if not exists listing_type text default 'fixed_price';
alter table public.paintings add column if not exists currency text default 'INR';
alter table public.paintings add column if not exists is_verified boolean default false;
alter table public.paintings add column if not exists nfc_status text default 'not_attached';
alter table public.paintings add column if not exists nfc_attached boolean default false;
alter table public.paintings add column if not exists solana_tx_id text;
alter table public.paintings add column if not exists owner_id uuid references auth.users(id) on delete set null;
alter table public.paintings add column if not exists bids_count integer not null default 0;
alter table public.paintings add column if not exists purchases_count integer not null default 0;
alter table public.paintings add column if not exists creator_location text;
alter table public.paintings add column if not exists trending_score double precision not null default 0;
alter table public.paintings add column if not exists collection_id text;
create index if not exists paintings_listing_type_idx on public.paintings(listing_type);
create index if not exists paintings_status_idx on public.paintings(status);
create index if not exists paintings_trending_score_idx on public.paintings(trending_score desc);

-- Auctions compatibility with new app columns
alter table public.auctions add column if not exists seller_id uuid;
alter table public.auctions add column if not exists starting_price numeric(14,2);
alter table public.auctions add column if not exists current_highest_bid numeric(14,2);
alter table public.auctions add column if not exists current_highest_bidder_id uuid;
alter table public.auctions add column if not exists current_highest_bidder_name text;
alter table public.auctions add column if not exists current_highest_bidder_avatar_url text;
alter table public.auctions add column if not exists bid_increment numeric(14,2) default 500;
alter table public.auctions add column if not exists total_bids integer not null default 0;
alter table public.auctions add column if not exists updated_at timestamptz default now();

update public.auctions
set seller_id = coalesce(seller_id, artist_id),
    starting_price = coalesce(starting_price, start_price),
    current_highest_bid = coalesce(current_highest_bid, current_price),
    total_bids = coalesce(total_bids, bid_count),
    bid_increment = coalesce(bid_increment, 500)
where true;

create index if not exists auctions_status_idx on public.auctions(status);
create index if not exists auctions_end_time_idx on public.auctions(end_time);

-- Purchase intents table
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
create index if not exists purchase_intents_painting_idx on public.purchase_intents(painting_id);
create index if not exists purchase_intents_buyer_idx on public.purchase_intents(buyer_id, created_at desc);

-- Bid RPC (server-side validation)
drop function if exists public.place_bid(uuid, uuid, numeric);

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

  if coalesce(v_auction.status, 'active') not in ('live', 'active') then
    raise exception 'AUCTION_NOT_LIVE';
  end if;

  if v_auction.end_time <= now() then
    raise exception 'AUCTION_ENDED';
  end if;

  if coalesce(v_auction.seller_id, v_auction.artist_id) = p_bidder_id or v_painting.artist_id = p_bidder_id then
    raise exception 'SELF_BID_BLOCKED';
  end if;

  v_min := coalesce(v_auction.current_highest_bid, v_auction.starting_price, v_auction.start_price)
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
      current_price = p_amount,
      current_highest_bidder_id = p_bidder_id,
      total_bids = coalesce(total_bids, bid_count, 0) + 1,
      bid_count = coalesce(total_bids, bid_count, 0) + 1,
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

-- Trending helper
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

-- RLS
alter table public.shops enable row level security;
alter table public.collections enable row level security;
alter table public.auctions enable row level security;
alter table public.bids enable row level security;
alter table public.purchase_intents enable row level security;

do $$ begin
if not exists (select 1 from pg_policies where schemaname='public' and tablename='shops' and policyname='shops_select_public') then
  create policy shops_select_public on public.shops for select using (true);
end if;
if not exists (select 1 from pg_policies where schemaname='public' and tablename='shops' and policyname='shops_insert_owner') then
  create policy shops_insert_owner on public.shops for insert to authenticated with check (owner_id = auth.uid());
end if;
if not exists (select 1 from pg_policies where schemaname='public' and tablename='shops' and policyname='shops_update_owner') then
  create policy shops_update_owner on public.shops for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
end if;
if not exists (select 1 from pg_policies where schemaname='public' and tablename='shops' and policyname='shops_delete_owner') then
  create policy shops_delete_owner on public.shops for delete to authenticated using (owner_id = auth.uid());
end if;
end $$;

do $$ begin
if not exists (select 1 from pg_policies where schemaname='public' and tablename='collections' and policyname='collections_select_public') then
  create policy collections_select_public on public.collections for select using (true);
end if;
if not exists (select 1 from pg_policies where schemaname='public' and tablename='collections' and policyname='collections_insert_owner') then
  create policy collections_insert_owner on public.collections for insert to authenticated with check ((artist_id is not null and artist_id = auth.uid()::text) or (shop_id is not null and exists (select 1 from public.shops s where s.id = collections.shop_id and s.owner_id = auth.uid())));
end if;
if not exists (select 1 from pg_policies where schemaname='public' and tablename='collections' and policyname='collections_update_owner') then
  create policy collections_update_owner on public.collections for update to authenticated using ((artist_id is not null and artist_id = auth.uid()::text) or (shop_id is not null and exists (select 1 from public.shops s where s.id = collections.shop_id and s.owner_id = auth.uid()))) with check ((artist_id is not null and artist_id = auth.uid()::text) or (shop_id is not null and exists (select 1 from public.shops s where s.id = collections.shop_id and s.owner_id = auth.uid())));
end if;
if not exists (select 1 from pg_policies where schemaname='public' and tablename='collections' and policyname='collections_delete_owner') then
  create policy collections_delete_owner on public.collections for delete to authenticated using ((artist_id is not null and artist_id = auth.uid()::text) or (shop_id is not null and exists (select 1 from public.shops s where s.id = collections.shop_id and s.owner_id = auth.uid())));
end if;
end $$;

do $$ begin
if not exists (select 1 from pg_policies where schemaname='public' and tablename='auctions' and policyname='auctions_select_public') then
  create policy auctions_select_public on public.auctions for select using (true);
end if;
if not exists (select 1 from pg_policies where schemaname='public' and tablename='auctions' and policyname='auctions_insert_seller') then
  create policy auctions_insert_seller on public.auctions for insert to authenticated with check (coalesce(seller_id, artist_id) = auth.uid());
end if;
if not exists (select 1 from pg_policies where schemaname='public' and tablename='auctions' and policyname='auctions_update_seller') then
  create policy auctions_update_seller on public.auctions for update to authenticated using (coalesce(seller_id, artist_id) = auth.uid()) with check (coalesce(seller_id, artist_id) = auth.uid());
end if;
end $$;

do $$ begin
if not exists (select 1 from pg_policies where schemaname='public' and tablename='bids' and policyname='bids_select_public') then
  create policy bids_select_public on public.bids for select using (true);
end if;
if not exists (select 1 from pg_policies where schemaname='public' and tablename='bids' and policyname='bids_insert_bidder') then
  create policy bids_insert_bidder on public.bids for insert to authenticated with check (bidder_id = auth.uid());
end if;
end $$;

do $$ begin
if not exists (select 1 from pg_policies where schemaname='public' and tablename='purchase_intents' and policyname='purchase_intents_select_party') then
  create policy purchase_intents_select_party on public.purchase_intents for select to authenticated using (buyer_id = auth.uid() or exists (select 1 from public.paintings p where p.id = purchase_intents.painting_id and p.artist_id = auth.uid()));
end if;
if not exists (select 1 from pg_policies where schemaname='public' and tablename='purchase_intents' and policyname='purchase_intents_insert_buyer') then
  create policy purchase_intents_insert_buyer on public.purchase_intents for insert to authenticated with check (buyer_id = auth.uid());
end if;
if not exists (select 1 from pg_policies where schemaname='public' and tablename='purchase_intents' and policyname='purchase_intents_update_buyer') then
  create policy purchase_intents_update_buyer on public.purchase_intents for update to authenticated using (buyer_id = auth.uid()) with check (buyer_id = auth.uid());
end if;
end $$;
