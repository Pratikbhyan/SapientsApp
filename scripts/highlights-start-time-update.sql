-- Add start_time column to existing highlights table
ALTER TABLE public.highlights 
ADD COLUMN IF NOT EXISTS start_time REAL;

-- Create index for better performance when sorting by start_time
CREATE INDEX IF NOT EXISTS highlights_start_time_idx ON public.highlights(content_title, start_time);

-- Update the existing RLS policies to include start_time (they should work as-is)
-- But let's verify the policy exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'highlights' 
        AND policyname = 'Users can insert their own highlights'
    ) THEN
        CREATE POLICY "Users can insert their own highlights" ON public.highlights
            FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;
END $$;