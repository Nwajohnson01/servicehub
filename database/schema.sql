-- =========================================================
-- SERVICEHUB DATABASE SCHEMA
-- Multi-tenant service business management platform
-- =========================================================

-- Enable UUID generation
create extension if not exists "uuid-ossp";

-- =========================================================
-- 1. ORGANIZATIONS (the "tenant" — each business on the platform)
-- =========================================================
create table organizations (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  slug text unique not null,
  logo_url text,
  contact_email text,
  contact_phone text,
  address text,
  whatsapp_number text,
  subscription_plan text default 'free',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- =========================================================
-- 2. PROFILES (extends Supabase auth.users with role + org)
-- =========================================================
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  organization_id uuid references organizations(id) on delete set null,
  role text not null check (role in ('customer', 'staff', 'business_owner', 'admin')),
  full_name text,
  phone text,
  avatar_url text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_profiles_organization on profiles(organization_id);
create index idx_profiles_role on profiles(role);

-- =========================================================
-- 3. STAFF (extra details for staff/technician profiles)
-- =========================================================
create table staff (
  id uuid primary key default uuid_generate_v4(),
  profile_id uuid not null references profiles(id) on delete cascade,
  organization_id uuid not null references organizations(id) on delete cascade,
  title text,
  is_active boolean default true,
  created_at timestamptz default now()
);

create index idx_staff_organization on staff(organization_id);
create index idx_staff_profile on staff(profile_id);

-- =========================================================
-- 4. SERVICE CATEGORIES
-- =========================================================
create table service_categories (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  name text not null,
  created_at timestamptz default now()
);

create index idx_service_categories_org on service_categories(organization_id);

-- =========================================================
-- 5. SERVICES
-- =========================================================
create table services (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  category_id uuid references service_categories(id) on delete set null,
  name text not null,
  description text,
  price numeric(12,2) not null default 0,
  duration_minutes integer,
  image_url text,
  is_available boolean default true,
  status text default 'active' check (status in ('active', 'inactive', 'draft')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_services_organization on services(organization_id);
create index idx_services_category on services(category_id);
create index idx_services_status on services(status);

-- =========================================================
-- 6. CUSTOMERS
-- =========================================================
create table customers (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  profile_id uuid references profiles(id) on delete set null,
  name text not null,
  email text,
  phone text,
  address text,
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_customers_organization on customers(organization_id);
create index idx_customers_profile on customers(profile_id);
create index idx_customers_email on customers(email);

-- =========================================================
-- 7. LEADS
-- =========================================================
create table leads (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  customer_id uuid not null references customers(id) on delete cascade,
  service_id uuid references services(id) on delete set null,
  source text default 'website',
  value numeric(12,2),
  status text not null default 'new' check (status in
    ('new', 'contacted', 'qualified', 'quotation_sent', 'negotiation', 'won', 'lost')),
  assigned_staff_id uuid references staff(id) on delete set null,
  notes text,
  follow_up_date date,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_leads_organization on leads(organization_id);
create index idx_leads_customer on leads(customer_id);
create index idx_leads_status on leads(status);
create index idx_leads_assigned_staff on leads(assigned_staff_id);

-- =========================================================
-- 8. LEAD ACTIVITIES (timeline of actions on a lead)
-- =========================================================
create table lead_activities (
  id uuid primary key default uuid_generate_v4(),
  lead_id uuid not null references leads(id) on delete cascade,
  activity_type text not null,
  notes text,
  created_by uuid references profiles(id) on delete set null,
  created_at timestamptz default now()
);

create index idx_lead_activities_lead on lead_activities(lead_id);

-- =========================================================
-- 9. APPOINTMENTS
-- =========================================================
create table appointments (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  customer_id uuid not null references customers(id) on delete cascade,
  service_id uuid references services(id) on delete set null,
  staff_id uuid references staff(id) on delete set null,
  appointment_date date not null,
  appointment_time time not null,
  location text,
  notes text,
  status text not null default 'pending' check (status in
    ('pending', 'confirmed', 'rescheduled', 'completed', 'cancelled')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_appointments_organization on appointments(organization_id);
create index idx_appointments_customer on appointments(customer_id);
create index idx_appointments_staff on appointments(staff_id);
create index idx_appointments_status on appointments(status);
create index idx_appointments_date on appointments(appointment_date);

-- =========================================================
-- 10. QUOTATIONS
-- =========================================================
create table quotations (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  quote_number text unique not null,
  customer_id uuid not null references customers(id) on delete cascade,
  lead_id uuid references leads(id) on delete set null,
  subtotal numeric(12,2) not null default 0,
  discount numeric(12,2) default 0,
  tax numeric(12,2) default 0,
  total numeric(12,2) not null default 0,
  valid_until date,
  notes text,
  status text not null default 'draft' check (status in
    ('draft', 'sent', 'accepted', 'rejected', 'expired')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_quotations_organization on quotations(organization_id);
create index idx_quotations_customer on quotations(customer_id);
create index idx_quotations_status on quotations(status);

-- =========================================================
-- 11. QUOTATION ITEMS
-- =========================================================
create table quotation_items (
  id uuid primary key default uuid_generate_v4(),
  quotation_id uuid not null references quotations(id) on delete cascade,
  service_id uuid references services(id) on delete set null,
  description text,
  quantity integer not null default 1,
  unit_price numeric(12,2) not null default 0,
  subtotal numeric(12,2) not null default 0
);

create index idx_quotation_items_quotation on quotation_items(quotation_id);

-- =========================================================
-- 12. INVOICES
-- =========================================================
create table invoices (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  invoice_number text unique not null,
  customer_id uuid not null references customers(id) on delete cascade,
  quotation_id uuid references quotations(id) on delete set null,
  subtotal numeric(12,2) not null default 0,
  discount numeric(12,2) default 0,
  tax numeric(12,2) default 0,
  total numeric(12,2) not null default 0,
  due_date date,
  status text not null default 'draft' check (status in
    ('draft', 'sent', 'paid', 'partially_paid', 'overdue', 'cancelled')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_invoices_organization on invoices(organization_id);
create index idx_invoices_customer on invoices(customer_id);
create index idx_invoices_status on invoices(status);

-- =========================================================
-- 13. INVOICE ITEMS
-- =========================================================
create table invoice_items (
  id uuid primary key default uuid_generate_v4(),
  invoice_id uuid not null references invoices(id) on delete cascade,
  description text not null,
  quantity integer not null default 1,
  unit_price numeric(12,2) not null default 0,
  subtotal numeric(12,2) not null default 0
);

create index idx_invoice_items_invoice on invoice_items(invoice_id);

-- =========================================================
-- 14. PAYMENTS
-- =========================================================
create table payments (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  invoice_id uuid not null references invoices(id) on delete cascade,
  amount numeric(12,2) not null,
  reference text,
  method text default 'manual',
  status text not null default 'pending' check (status in
    ('pending', 'completed', 'failed', 'refunded')),
  paid_at timestamptz,
  created_at timestamptz default now()
);

create index idx_payments_organization on payments(organization_id);
create index idx_payments_invoice on payments(invoice_id);

-- =========================================================
-- 15. NOTIFICATIONS
-- =========================================================
create table notifications (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid references organizations(id) on delete cascade,
  recipient_id uuid references profiles(id) on delete cascade,
  type text not null,
  title text,
  body text,
  payload jsonb,
  read_at timestamptz,
  created_at timestamptz default now()
);

create index idx_notifications_recipient on notifications(recipient_id);
create index idx_notifications_organization on notifications(organization_id);

-- =========================================================
-- 16. MESSAGES
-- =========================================================
create table messages (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  customer_id uuid references customers(id) on delete cascade,
  sender_id uuid references profiles(id) on delete set null,
  body text not null,
  created_at timestamptz default now()
);

create index idx_messages_organization on messages(organization_id);
create index idx_messages_customer on messages(customer_id);

-- =========================================================
-- 17. REVIEWS
-- =========================================================
create table reviews (
  id uuid primary key default uuid_generate_v4(),
  organization_id uuid not null references organizations(id) on delete cascade,
  customer_id uuid references customers(id) on delete cascade,
  service_id uuid references services(id) on delete set null,
  rating integer not null check (rating between 1 and 5),
  comment text,
  created_at timestamptz default now()
);

create index idx_reviews_organization on reviews(organization_id);
create index idx_reviews_service on reviews(service_id);

-- =========================================================
-- END OF SCHEMA
-- Row Level Security policies are defined separately
-- in database/policies.sql
-- =========================================================
