# Comfort Curators - Setup Guide

## Prerequisites

- Node.js 18+ and pnpm
- Docker (for local Supabase)
- Supabase CLI: `npm install -g supabase`

## Quick Start

### 1. Install Dependencies

```bash
pnpm install
```

### 2. Configure Environment

Copy `.env.example` to `.env.local` and fill in values:

```bash
cp .env.example .env.local
```

Required for local development:
- `NEXT_PUBLIC_SUPABASE_URL` - Get from Supabase project
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` - Get from Supabase project  
- `SUPABASE_SERVICE_ROLE_KEY` - Get from Supabase project

### 3. Start Supabase Locally

```bash
supabase start
```

This will output local credentials. Update `.env.local` with these values.

### 4. Run Migrations

```bash
supabase db push
```

### 5. Seed Data (Optional)

```bash
psql -h localhost -p 54322 -U postgres -d postgres -f supabase/seed.sql
```

### 6. Start Development Server

```bash
pnpm dev
```

Access the app at `http://localhost:3000`

## Production Deployment

### Vercel

1. Connect your repository to Vercel
2. Add environment variables in Vercel dashboard
3. Deploy

### Supabase (Remote)

1. Create a project at supabase.com
2. Run migrations: `supabase db push --linked`
3. Configure auth redirect URLs

## Security Considerations

- All tables have Row Level Security (RLS) enabled
- Staff can only access data relevant to their assigned tickets
- iCal URLs and entry details are encrypted
- Audit logs track all sensitive actions

## Compliance Features

- DSAR (Data Subject Access Request) handling
- Consent logging
- Configurable data retention
- GST-compliant invoicing for India
