# Qudris ShopKeeper - Authentication Page

A futuristic, dramatic web page for email verification and password reset with an African forest theme featuring an animated child running through the forest.

## Features

- 🌲 **Dramatic African Forest Theme** - Animated forest background with multiple layers
- 🏃 **Animated Child Silhouette** - A child running through the forest
- ✨ **Firefly Particles** - Floating light particles for atmosphere
- ✅ **Email Verification** - Handles Supabase email verification callbacks
- 🔑 **Password Reset** - Secure password reset flow with form validation
- 📱 **Responsive Design** - Works on all device sizes
- 🎨 **Futuristic UI** - Modern glassmorphic design with smooth animations

## Setup

This is a static site that can be deployed to Vercel or any static hosting service.

### Local Development

```bash
# Serve locally
npx serve .

# Or use any static file server
python -m http.server 8000
```

### Deployment to Vercel

1. **Install Vercel CLI** (if not already installed):
   ```bash
   npm i -g vercel
   ```

2. **Deploy**:
   ```bash
   vercel
   ```

   Or connect your GitHub repository to Vercel for automatic deployments.

3. **Configure Redirect URLs in Supabase**:
   - Go to your Supabase project → Authentication → URL Configuration
   - Add your Vercel deployment URL to the redirect URLs:
     - `https://your-app.vercel.app`
     - `https://your-app.vercel.app/auth/callback`

## How It Works

1. **Email Verification Flow**:
   - User clicks verification link from email
   - Supabase redirects to this page with tokens in URL
   - Page verifies the token and shows success message

2. **Password Reset Flow**:
   - User clicks password reset link from email
   - Page detects it's a password reset and shows form
   - User enters new password and submits
   - Password is updated via Supabase

## Configuration

Update the Supabase configuration in `script.js`:

```javascript
const SUPABASE_URL = 'your-supabase-url';
const SUPABASE_ANON_KEY = 'your-supabase-anon-key';
```

Update redirect URLs in the script where it redirects after success.

## Customization

- **Colors**: Edit CSS variables in `style.css` (`:root` section)
- **Animations**: Adjust animation durations and speeds in `style.css`
- **Content**: Modify text and messages in `index.html` and `script.js`

## Browser Support

- Chrome/Edge (latest)
- Firefox (latest)
- Safari (latest)
- Mobile browsers

## License

MIT

