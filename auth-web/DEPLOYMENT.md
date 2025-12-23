# Deployment Guide for Auth Web Page

## Quick Deployment to Vercel

### Step 1: Push to Git

```bash
# Add the auth-web folder to git
git add auth-web/

# Commit the changes
git commit -m "Add futuristic auth web page with African forest theme"

# Push to your repository
git push origin main
```

### Step 2: Deploy to Vercel

#### Option A: Using Vercel CLI

1. **Install Vercel CLI** (if not already installed):
   ```bash
   npm install -g vercel
   ```

2. **Navigate to auth-web directory**:
   ```bash
   cd auth-web
   ```

3. **Login to Vercel**:
   ```bash
   vercel login
   ```

4. **Deploy**:
   ```bash
   vercel
   ```
   
   - Follow the prompts:
     - Set up and deploy? **Yes**
     - Which scope? (select your account)
     - Link to existing project? **No**
     - Project name? (use default or enter a name like `qudris-auth`)
     - In which directory is your code located? **./**
     - Want to override settings? **No**

5. **For production deployment**:
   ```bash
   vercel --prod
   ```

#### Option B: Using Vercel Dashboard (GitHub Integration)

1. Go to [vercel.com](https://vercel.com) and sign in
2. Click "Add New Project"
3. Import your Git repository
4. Configure the project:
   - **Root Directory**: `auth-web`
   - **Framework Preset**: Other
   - **Build Command**: (leave empty - static site)
   - **Output Directory**: (leave empty - root is output)
5. Click "Deploy"

### Step 3: Configure Supabase Redirect URLs

After deployment, you'll get a URL like `https://your-app.vercel.app`

1. Go to your Supabase project dashboard
2. Navigate to **Authentication** → **URL Configuration**
3. Add your Vercel URL to **Redirect URLs**:
   - `https://your-app.vercel.app`
   - `https://your-app.vercel.app/auth/callback`
   - `https://your-app.vercel.app/*` (for all subpaths)

4. Update **Site URL** to your Vercel URL (optional but recommended)

### Step 4: Update Flutter App Auth Service (Optional)

If you want the Flutter app to redirect to your new auth page, update `lib/services/auth_service.dart`:

```dart
String _getRedirectUrl() {
  if (kIsWeb) {
    // Use your Vercel URL for web
    return 'https://your-app.vercel.app';
  } else {
    // Keep deep link for mobile
    return 'qudrisshopkeeper://auth/callback';
  }
}
```

Or configure it in Supabase dashboard under Authentication → URL Configuration.

### Step 5: Test the Deployment

1. **Email Verification Test**:
   - Sign up for a new account in your app
   - Click the verification link in the email
   - You should see the dramatic forest page with success message

2. **Password Reset Test**:
   - Request a password reset
   - Click the reset link in the email
   - You should see the password reset form on the forest page

## Environment Variables

No environment variables are needed as the Supabase credentials are hardcoded in `script.js`. 

⚠️ **Security Note**: For production, consider moving credentials to environment variables if needed.

## Custom Domain (Optional)

To use a custom domain:

1. In Vercel dashboard, go to your project → Settings → Domains
2. Add your custom domain
3. Follow DNS configuration instructions
4. Update Supabase redirect URLs to include your custom domain

## Troubleshooting

- **404 errors**: Make sure Vercel is serving from the root directory
- **Auth not working**: Check Supabase redirect URLs are configured correctly
- **CORS errors**: Verify Supabase URL and anon key in `script.js`
- **Styling issues**: Clear browser cache and hard refresh

## Local Testing

Test locally before deploying:

```bash
cd auth-web
npx serve .
```

Then visit `http://localhost:3000` and test with a verification link (you'll need to modify the URL to include test tokens).

