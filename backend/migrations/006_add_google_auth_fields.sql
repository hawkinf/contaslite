-- Migration 006: Add Google Authentication fields to users table
-- Date: 2026-01-17
-- Description: Adds google_id and photo_url columns to support Google Sign-In

-- Add google_id column (unique Google account identifier)
ALTER TABLE users
ADD COLUMN IF NOT EXISTS google_id VARCHAR(255) UNIQUE;

-- Add photo_url column (Google profile picture URL)
ALTER TABLE users
ADD COLUMN IF NOT EXISTS photo_url VARCHAR(500);

-- Make password_hash nullable (Google users don't have passwords)
ALTER TABLE users
ALTER COLUMN password_hash DROP NOT NULL;

-- Create index on google_id for fast lookups
CREATE INDEX IF NOT EXISTS idx_users_google_id ON users(google_id);

-- Add comment for documentation
COMMENT ON COLUMN users.google_id IS 'Google account unique identifier (sub claim from ID token)';
COMMENT ON COLUMN users.photo_url IS 'Profile picture URL from Google account';
