# Deployment Guide

## 1. Supabase Configuration

### Link to Remote Project

1. Get your Project Ref (Reference ID) from the Supabase Dashboard URL (e.g., `https://app.supabase.com/project/abcdefghijklm`). The ref is `abcdefghijklm`.
2. Login and link your project:

```bash
npx supabase login
npx supabase link --project-ref daftuatmmoobwpeatxmf
```
3. Push your database migrations to the remote project:

```bash
npx supabase db push
```

4. Upload seed data (optional, for initial setup):

```bash
# You'll need the postgres connection string from Supabase Settings -> Database
psql "postgres://postgres:[YOUR-PASSWORD]@db.[YOUR-PROJECT-REF].supabase.co:5432/postgres" -f supabase/seed.sql
```

### Auth Configuration

1. Go to **Authentication -> URL Configuration** in Supabase Dashboard.
2. Set **Site URL** to your Vercel URL (e.g., `https://comfort-curators.vercel.app`).
3. Add `https://comfort-curators.vercel.app/auth/callback` to **Redirect URLs**.

### Storage

1. The migrations should have created the buckets. Verify in **Storage** dashboard.
2. Ensure policies are applied (they are part of the migrations).

---

## 2. Stripe Configuration

### Stripe Dashboard

1. Create a **Product** for the subscription (e.g., "Smart Plan").
2. Get the **Price ID** (e.g., `price_H5ggY...`).
3. Set up a **Webhook Endpoint** pointing to `https://comfort-curators.vercel.app/api/webhooks/stripe`.
   - Select events: `customer.subscription.created`, `customer.subscription.updated`, `customer.subscription.deleted`, `invoice.payment_succeeded`.
   - Get the **Signing Secret** (`whsec_...`).

---

## 3. Vercel Environment Variables

Add the following environment variables in Vercel Project Settings:

| Variable | Value Source |
|----------|--------------|
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase Settings -> API |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Supabase Settings -> API |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase Settings -> API (service_role secret) |
| `NEXT_PUBLIC_MAP_TILE_URL_TEMPLATE` | Map provider (e.g., OpenStreetMap/MapTiler) |
| `STRIPE_SECRET_KEY` | Stripe Dashboard -> API Keys |
| `STRIPE_WEBHOOK_SECRET` | Stripe Dashboard -> Webhooks |
| `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` | Stripe Dashboard -> API Keys |
| `GEMINI_KEY_A` | Google AI Studio |
| `GEMINI_KEY_B` | Google AI Studio |
| `AI_MODEL_NAME` | `gemini-2.5-flash` |
| `ENCRYPTION_KEY` | Generate with `openssl rand -base64 32` |
| `CRON_SECRET` | Generate a random string |
| `NEXT_PUBLIC_APP_NAME` | "Comfort Curators" |

---

## 4. Cron Jobs

Since Vercel Cron is free for hobby/pro, the `vercel.json` (if added) or Vercel Cron settings should target:

- `/api/cron/ical` (Hourly)
- `/api/cron/packages` (Every 15 mins)
- `/api/cron/health` (Hourly)

*Note: Secure these endpoints to only accept requests with the `CRON_SECRET` header.*
