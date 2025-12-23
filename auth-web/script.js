// Supabase Configuration
const SUPABASE_URL = 'https://erikfxagpbaxiabwzfmo.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVyaWtmeGFncGJheGlhYnd6Zm1vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk5NDM3MzksImV4cCI6MjA3NTUxOTczOX0._Yx8pCYOr2v7ntoytboLGECfPLGf4_3AgzBwnMH-3Xc';

// Initialize Supabase client
const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// DOM Elements
const loadingCard = document.getElementById('loadingCard');
const successCard = document.getElementById('successCard');
const passwordResetCard = document.getElementById('passwordResetCard');
const errorCard = document.getElementById('errorCard');
const passwordResetForm = document.getElementById('passwordResetForm');
const continueBtn = document.getElementById('continueBtn');
const retryBtn = document.getElementById('retryBtn');
const passwordError = document.getElementById('passwordError');

// Main initialization
document.addEventListener('DOMContentLoaded', async () => {
    try {
        // Get URL parameters from both hash and query string
        const urlParams = new URLSearchParams(window.location.search);
        const hashParams = new URLSearchParams(window.location.hash.substring(1));
        
        const accessToken = hashParams.get('access_token');
        const refreshToken = hashParams.get('refresh_token');
        const type = hashParams.get('type') || urlParams.get('type');
        const token = hashParams.get('token') || urlParams.get('token');
        const tokenHash = hashParams.get('token_hash');
        const email = hashParams.get('email') || urlParams.get('email');
        
        console.log('URL params:', { accessToken: !!accessToken, refreshToken: !!refreshToken, type, token: !!token, tokenHash: !!tokenHash, email });

        // Supabase automatically handles session from hash params
        // Check if we have a session set by Supabase
        const { data: sessionData, error: sessionError } = await supabase.auth.getSession();
        
        // If we have tokens in the hash, handle the callback
        if (accessToken && refreshToken) {
            await handleAuthCallback(accessToken, refreshToken, type);
        } else if (sessionData?.session) {
            // Session was already set by Supabase (automatic handling)
            // Check if this is a password reset or email verification
            if (type === 'recovery') {
                showPasswordResetForm();
            } else {
                showSuccess('Email Verified!', 'Your email has been successfully verified. You can now sign in to your account.');
            }
        } else if (tokenHash || token) {
            // Handle token-based verification
            await handleTokenVerification(tokenHash || token, type, email);
        } else {
            // No valid parameters, show error
            showError('Invalid or missing authentication parameters. Please check your email link.');
        }
    } catch (error) {
        console.error('Authentication error:', error);
        showError(error.message || 'An unexpected error occurred. Please try again.');
    }
});

// Handle OAuth/magic link callback
async function handleAuthCallback(accessToken, refreshToken, type) {
    try {
        // Set the session
        const { data, error } = await supabase.auth.setSession({
            access_token: accessToken,
            refresh_token: refreshToken
        });

        if (error) throw error;

        // Check what type of authentication this is
        if (type === 'recovery') {
            // Password reset - show password reset form
            showPasswordResetForm();
        } else {
            // Email verification - show success
            showSuccess('Email Verified!', 'Your email has been successfully verified. You can now sign in to your account.');
        }
    } catch (error) {
        console.error('Auth callback error:', error);
        showError(error.message || 'Failed to complete authentication.');
    }
}

// Handle token-based verification (for email verification)
async function handleTokenVerification(token, type, email) {
    try {
        if (type === 'signup' || type === 'email') {
            // Supabase automatically handles email verification via hash fragments
            // Just check if session was established
            const { data: sessionData } = await supabase.auth.getSession();
            
            if (sessionData?.session) {
                showSuccess(
                    'Email Verified!',
                    'Your email has been successfully verified. You can now sign in to your account.'
                );
            } else {
                // Try to verify manually if session wasn't auto-established
                const hashParams = new URLSearchParams(window.location.hash.substring(1));
                const tokenHash = hashParams.get('token_hash') || token;
                
                if (tokenHash) {
                    const { data, error } = await supabase.auth.verifyOtp({
                        token_hash: tokenHash,
                        type: 'email'
                    });
                    
                    if (error) throw error;
                    showSuccess(
                        'Email Verified!',
                        'Your email has been successfully verified. You can now sign in to your account.'
                    );
                } else {
                    throw new Error('Verification token not found');
                }
            }
        } else if (type === 'recovery') {
            // Password reset - show password reset form
            showPasswordResetForm();
        } else {
            throw new Error('Unknown verification type');
        }
    } catch (error) {
        console.error('Token verification error:', error);
        showError(error.message || 'Failed to verify your request. The link may have expired.');
    }
}

// Show password reset form
function showPasswordResetForm() {
    hideAllCards();
    passwordResetCard.classList.remove('hidden');
    
    // Handle form submission
    passwordResetForm.addEventListener('submit', handlePasswordReset);
}

// Handle password reset
async function handlePasswordReset(e) {
    e.preventDefault();
    
    const newPassword = document.getElementById('newPassword').value;
    const confirmPassword = document.getElementById('confirmPassword').value;
    
    // Validate passwords match
    if (newPassword !== confirmPassword) {
        passwordError.textContent = 'Passwords do not match';
        passwordError.classList.remove('hidden');
        return;
    }
    
    // Validate password length
    if (newPassword.length < 6) {
        passwordError.textContent = 'Password must be at least 6 characters long';
        passwordError.classList.remove('hidden');
        return;
    }
    
    passwordError.classList.add('hidden');
    
    try {
        // Update password
        const { data, error } = await supabase.auth.updateUser({
            password: newPassword
        });
        
        if (error) throw error;
        
        showSuccess(
            'Password Updated!',
            'Your password has been successfully updated. You can now sign in with your new password.'
        );
    } catch (error) {
        console.error('Password reset error:', error);
        passwordError.textContent = error.message || 'Failed to update password. Please try again.';
        passwordError.classList.remove('hidden');
    }
}

// Show success message
function showSuccess(title, message) {
    hideAllCards();
    document.getElementById('successTitle').textContent = title;
    document.getElementById('successMessage').textContent = message;
    successCard.classList.remove('hidden');
    
    // Set up continue button
    continueBtn.onclick = () => {
        // Redirect to the app or a sign-in page
        // Update this URL to match your app's URL
        const appUrl = window.location.hostname.includes('localhost') 
            ? 'http://localhost:8080/signin'
            : 'https://qudrisshopkeeper.app/signin';
        window.location.href = appUrl;
    };
}

// Show error message
function showError(message) {
    hideAllCards();
    document.getElementById('errorMessage').textContent = message;
    errorCard.classList.remove('hidden');
    
    // Set up retry button
    retryBtn.onclick = () => {
        const appUrl = window.location.hostname.includes('localhost')
            ? 'http://localhost:8080/signin'
            : 'https://qudrisshopkeeper.app/signin';
        window.location.href = appUrl;
    };
}

// Hide all cards
function hideAllCards() {
    loadingCard.classList.add('hidden');
    successCard.classList.add('hidden');
    passwordResetCard.classList.add('hidden');
    errorCard.classList.add('hidden');
}

