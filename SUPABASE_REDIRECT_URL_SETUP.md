# Supabase Redirect URL Configuration

## Your Auth Web Page URL

Your authentication page is deployed at: **https://qudrisshopkeeper.vercel.app/**

This single URL handles:
- ✅ Email verification (when users click email confirmation links)
- 🔑 Password reset (when users click password reset links)

## Configure Supabase Redirect URLs

### Step 1: Go to Supabase Dashboard

1. Navigate to your Supabase project dashboard
2. Go to **Authentication** → **URL Configuration**

### Step 2: Add Redirect URLs

Add these URLs to the **Redirect URLs** list:

```
https://qudrisshopkeeper.vercel.app
https://qudrisshopkeeper.vercel.app/
qudrisshopkeeper://auth/callback
```

### Step 3: Set Site URL (Optional but Recommended)

Set the **Site URL** to:
```
https://qudrisshopkeeper.vercel.app
```

## How It Works

### Email Verification Flow:
1. User signs up in your Flutter app
2. Supabase sends confirmation email with link
3. Link redirects to: `https://qudrisshopkeeper.vercel.app/#access_token=...&type=signup`
4. Page automatically verifies the email and shows success message

### Password Reset Flow:
1. User requests password reset in your Flutter app
2. Supabase sends reset email with link
3. Link redirects to: `https://qudrisshopkeeper.vercel.app/#access_token=...&type=recovery`
4. Page shows password reset form
5. User enters new password and submits
6. Password is updated and success message is shown

## Testing

After configuring Supabase:

1. **Test Email Verification:**
   - Sign up a new user
   - Check email for confirmation link
   - Click link → should redirect to https://qudrisshopkeeper.vercel.app/
   - Should see "Email Verified!" success message

2. **Test Password Reset:**
   - Request password reset
   - Check email for reset link
   - Click link → should redirect to https://qudrisshopkeeper.vercel.app/
   - Should see password reset form
   - Enter new password and submit
   - Should see "Password Updated!" success message

## Troubleshooting

If links don't work:
- ✅ Check redirect URLs are added in Supabase
- ✅ Verify the URL is correct (no trailing slash issues)
- ✅ Check browser console for errors
- ✅ Ensure Supabase email service is enabled

