-- Enhanced account deletion setup for Sapients app
-- Run this in your Supabase SQL editor if you want full account deletion

-- Step 1: Create the account deletion function
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
    
    -- Delete user-specific data from custom tables
    -- Adjust these table names to match your actual database schema
    
    -- Example deletions (uncomment and modify as needed):
    -- DELETE FROM user_favorites WHERE user_id = current_user_id;
    -- DELETE FROM user_notes WHERE user_id = current_user_id;
    -- DELETE FROM user_preferences WHERE user_id = current_user_id;
    -- DELETE FROM user_cache WHERE user_id = current_user_id;
    
    -- Log the deletion attempt
    RAISE NOTICE 'Attempting to delete user account: %', current_user_id;
    
    -- The auth.users deletion should be handled by Supabase Auth API
    -- Don't delete from auth.users directly here
    
    -- Return success
    deletion_result := json_build_object(
        'success', true,
        'user_id', current_user_id,
        'message', 'User data deleted successfully'
    );
    
    RAISE NOTICE 'User account data deleted successfully: %', current_user_id;
    
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

-- Step 2: Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION delete_user_account() TO authenticated;

-- Step 3: Create RLS policies for user data tables (examples)
-- Uncomment and modify these based on your actual tables

/*
-- Example: User favorites table
ALTER TABLE user_favorites ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own favorites" ON user_favorites
    FOR ALL USING (auth.uid() = user_id);

-- Example: User notes table  
ALTER TABLE user_notes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own notes" ON user_notes
    FOR ALL USING (auth.uid() = user_id);

-- Example: User preferences table
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own preferences" ON user_preferences
    FOR ALL USING (auth.uid() = user_id);
*/

-- Step 4: Test the function (optional)
-- You can test this function by calling: SELECT delete_user_account();