-- Simple account deletion function for Sapients app
-- Run this in your Supabase SQL editor

-- Create the account deletion function
CREATE OR REPLACE FUNCTION delete_user_account()
RETURNS json AS $$
DECLARE
    current_user_id uuid;
    deletion_result json;
BEGIN
    -- Get the current authenticated user ID
    current_user_id := auth.uid();
    
    -- Check if user is authenticated
    IF current_user_id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'User not authenticated'
        );
    END IF;
    
    -- Log the deletion attempt
    RAISE NOTICE 'Starting account deletion for user: %', current_user_id;
    
    -- Delete user-specific data from custom tables (add your tables here)
    -- Example deletions:
    -- DELETE FROM user_favorites WHERE user_id = current_user_id;
    -- DELETE FROM user_notes WHERE user_id = current_user_id;
    -- DELETE FROM user_preferences WHERE user_id = current_user_id;
    
    -- Delete from auth.users table (this will remove the user completely)
    DELETE FROM auth.users WHERE id = current_user_id;
    
    -- Return success
    deletion_result := json_build_object(
        'success', true,
        'user_id', current_user_id,
        'message', 'User account deleted completely'
    );
    
    RAISE NOTICE 'User account deleted successfully: %', current_user_id;
    
    RETURN deletion_result;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Return error information
        RETURN json_build_object(
            'success', false,
            'error', SQLERRM,
            'user_id', current_user_id
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION delete_user_account() TO authenticated;

-- Test the function (optional - you can run this to test)
-- SELECT delete_user_account();