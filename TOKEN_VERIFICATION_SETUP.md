# Token-Based Email Verification Setup

## Overview

We're using token-based email verification instead of redirect URLs to avoid email service issues. Users will receive a token in their email and enter it on a verification page.

## How It Works

1. **User signs up** in the Flutter app
2. **Supabase sends email** with a verification token (OTP)
3. **User visits** `https://qudrisshopkeeper.vercel.app/verify-token.html`
4. **User enters token** from email
5. **Token is verified** and account is activated

## Supabase Configuration

### Step 1: Configure Email Template

1. Go to **Authentication** → **Email Templates** → **Confirm signup**
2. Update the email template to include:
   - The verification token: `{{ .Token }}`
   - Instructions to visit: `https://qudrisshopkeeper.vercel.app/verify-token.html`

**Example Email Template:**

```
Subject: Confirm your signup

Hi,

Please verify your email address by entering this token on our verification page:

Token: {{ .Token }}

Visit: https://qudrisshopkeeper.vercel.app/verify-token.html?email={{ .Email }}&type=signup

Or copy and paste this token on the verification page.

If you didn't request this, you can safely ignore this email.
```

### Step 2: Ensure OTP is Enabled

1. Go to **Authentication** → **Providers** → **Email**
2. Make sure email provider is enabled
3. The OTP system is used automatically when no redirect URL is provided

## Files Created

1. **auth-web/verify-token.html** - Token verification page with forest theme
2. **auth-web/verify-token.js** - Token verification logic

## Testing

1. Sign up a new user
2. Check email for the token
3. Visit `https://qudrisshopkeeper.vercel.app/verify-token.html?email=your@email.com&type=signup`
4. Enter the token from email
5. Should see success message

## Alternative: Token in URL

Users can also visit:
```
https://qudrisshopkeeper.vercel.app/verify-token.html?token=123456&email=user@example.com&type=signup
```

The page will automatically verify if token is in URL.

