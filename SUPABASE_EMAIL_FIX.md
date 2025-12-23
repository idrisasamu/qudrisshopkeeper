# Fix Supabase Email Configuration Error

## Problem
Getting error: `"Error sending confirmation email"` with status code 500 when trying to sign up.

## Solutions

### Option 1: Check Supabase Email Service Status

1. Go to your Supabase Dashboard: https://supabase.com/dashboard
2. Select your project
3. Go to **Settings** → **API**
4. Check if email service is enabled

### Option 2: Configure Email Redirect URLs in Supabase

1. Go to **Authentication** → **URL Configuration**
2. Add these redirect URLs:
   - `qudrisshopkeeper://auth/callback` (for mobile)
   - `https://your-vercel-url.vercel.app` (for web - update with your actual Vercel deployment URL)
   - `http://localhost:3000/auth/callback` (for local development)

### Option 3: Disable Email Confirmation (Temporary Workaround)

If you want to test without email confirmation:

1. Go to **Authentication** → **Providers** → **Email**
2. Turn OFF **"Confirm email"**
3. Users will be able to sign up without email verification

⚠️ **Note**: This is not recommended for production.

### Option 4: Check Email Templates

1. Go to **Authentication** → **Email Templates**
2. Ensure the **Confirm signup** template is configured
3. Make sure the redirect URL in the template matches your app

### Option 5: Use Supabase SMTP (For Production)

If using the default Supabase email service (limited), you may hit rate limits. For production:

1. Go to **Settings** → **Auth** → **SMTP Settings**
2. Configure your own SMTP server (e.g., SendGrid, Mailgun, AWS SES)
3. This provides better deliverability and higher limits

## After Fixing

Once you've updated the Supabase configuration:
1. The email service should work
2. Users will receive confirmation emails
3. Clicking the email link will redirect to your auth web page (once deployed to Vercel)

## Testing

After configuration:
1. Try signing up again
2. Check your email inbox (and spam folder)
3. Click the verification link
4. Should redirect to your auth page

