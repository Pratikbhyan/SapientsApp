-- Create a function to delete a user account and all associated data
-- This function should be run in your Supabase SQL editor

CREATE OR REPLACE FUNCTION delete_user_account()
RETURNS void AS $$
DECLARE
    current_user_id uuid;
BEGIN
    -- Get the current authenticated user ID
    current_user_id := auth.uid();
    
    -- Check if user is authenticated
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;
    
    -- Delete user data from all tables (adjust table names as needed)
    -- Note: Adjust these table names to match your actual database schema
    
    -- Delete from content table if user has any personal content
    -- DELETE FROM content WHERE user_id = current_user_id;
    
    -- Delete from any user-specific tables
    -- DELETE FROM user_preferences WHERE user_id = current_user_id;
    -- DELETE FROM user_favorites WHERE user_id = current_user_id;
    -- DELETE FROM user_notes WHERE user_id = current_user_id;
    
    -- Delete the user from auth.users (this also cascades to related auth tables)
    DELETE FROM auth.users WHERE id = current_user_id;
    
    -- Log the deletion (optional)
    RAISE NOTICE 'User account % deleted successfully', current_user_id;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log the error and re-raise it
        RAISE EXCEPTION 'Failed to delete user account: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION delete_user_account() TO authenticated;

-- Optional: Create RLS policies if needed for any tables that store user data
-- Make sure to review and adjust based on your actual database schema