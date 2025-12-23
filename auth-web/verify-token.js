// Supabase Configuration
const SUPABASE_URL = 'https://erikfxagpbaxiabwzfmo.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVyaWtmeGFncGJheGlhYnd6Zm1vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk5NDM3MzksImV4cCI6MjA3NTUxOTczOX0._Yx8pCYOr2v7ntoytboLGECfPLGf4_3AgzBwnMH-3Xc';

// Initialize Supabase client
const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// DOM Elements
const loadingCard = document.getElementById('loadingCard');
const successCard = document.getElementById('successCard');
const errorCard = document.getElementById('errorCard');
const tokenInputCard = document.getElementById('tokenInputCard');
const tokenForm = document.getElementById('tokenForm');
const tokenInput = document.getElementById('tokenInput');
const tokenError = document.getElementById('tokenError');
const continueBtn = document.getElementById('continueBtn');
const retryBtn = document.getElementById('retryBtn');

// Get URL parameters
const urlParams = new URLSearchParams(window.location.search);
const token = urlParams.get('token');
const email = urlParams.get('email');
const type = urlParams.get('type') || 'signup';

// Main initialization
document.addEventListener('DOMContentLoaded', async () => {
    // Format token input to show only numbers
    tokenInput.addEventListener('input', (e) => {
        e.target.value = e.target.value.replace(/\D/g, '').slice(0, 6);
    });

    // Handle form submission
    tokenForm.addEventListener('submit', handleTokenVerification);

    // If token is in URL, verify automatically
    if (token && email) {
        await verifyTokenWithEmail(token, email, type);
    } else {
        // Show token input form
        showTokenInput();
    }
});

// Verify token from URL
async function verifyTokenWithEmail(tokenValue, emailValue, typeValue) {
    try {
        hideAllCards();
        loadingCard.classList.remove('hidden');

        const { data, error } = await supabase.auth.verifyOtp({
            email: emailValue,
            token: tokenValue,
            type: typeValue === 'recovery' ? 'recovery' : 'email'
        });

        if (error) throw error;

        showSuccess('Email Verified!', 'Your email has been successfully verified. You can now sign in to your account.');
    } catch (error) {
        console.error('Token verification error:', error);
        showError(error.message || 'Failed to verify your email. The token may have expired or is invalid.');
    }
}

// Handle manual token input
async function handleTokenVerification(e) {
    e.preventDefault();
    
    const tokenValue = tokenInput.value.trim();
    const emailValue = email || prompt('Please enter your email address:');
    
    if (!emailValue) {
        tokenError.textContent = 'Email address is required';
        tokenError.classList.remove('hidden');
        return;
    }

    if (!tokenValue || tokenValue.length !== 6) {
        tokenError.textContent = 'Please enter a valid 6-digit token';
        tokenError.classList.remove('hidden');
        return;
    }

    tokenError.classList.add('hidden');
    
    try {
        hideAllCards();
        loadingCard.classList.remove('hidden');

        const { data, error } = await supabase.auth.verifyOtp({
            email: emailValue,
            token: tokenValue,
            type: type === 'recovery' ? 'recovery' : 'email'
        });

        if (error) throw error;

        showSuccess('Email Verified!', 'Your email has been successfully verified. You can now sign in to your account.');
    } catch (error) {
        console.error('Token verification error:', error);
        tokenError.textContent = error.message || 'Failed to verify token. Please check and try again.';
        tokenError.classList.remove('hidden');
        loadingCard.classList.add('hidden');
        tokenInputCard.classList.remove('hidden');
    }
}

// Show token input form
function showTokenInput() {
    hideAllCards();
    tokenInputCard.classList.remove('hidden');
}

// Show success message
function showSuccess(title, message) {
    hideAllCards();
    document.getElementById('successMessage').textContent = message;
    successCard.classList.remove('hidden');
    
    // Set up continue button
    continueBtn.onclick = () => {
        const appUrl = window.location.hostname.includes('localhost')
            ? 'http://localhost:8080/signin'
            : 'https://qudrisshopkeeper.vercel.app/signin';
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
        showTokenInput();
    };
}

// Hide all cards
function hideAllCards() {
    loadingCard.classList.add('hidden');
    successCard.classList.add('hidden');
    errorCard.classList.add('hidden');
    tokenInputCard.classList.add('hidden');
}

