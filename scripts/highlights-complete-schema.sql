-- Drop existing highlights table if it exists
DROP TABLE IF EXISTS public.highlights CASCADE;

-- Create highlights table with all necessary columns
CREATE TABLE public.highlights (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content_id UUID,
    content_title TEXT NOT NULL,
    highlight_text TEXT NOT NULL,
    start_time REAL, -- New field for natural story ordering
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Enable Row Level Security
ALTER TABLE public.highlights ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can insert their own highlights" ON public.highlights
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own highlights" ON public.highlights
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own highlights" ON public.highlights
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own highlights" ON public.highlights
    FOR DELETE USING (auth.uid() = user_id);

-- Create indexes for better performance
CREATE INDEX highlights_user_id_idx ON public.highlights(user_id);
CREATE INDEX highlights_content_title_idx ON public.highlights(content_title);
CREATE INDEX highlights_created_at_idx ON public.highlights(created_at DESC);
CREATE INDEX highlights_natural_order_idx ON public.highlights(content_title, start_time ASC NULLS LAST);

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at on row updates
CREATE TRIGGER update_highlights_updated_at 
    BEFORE UPDATE ON public.highlights 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Grant necessary permissions
GRANT ALL ON public.highlights TO authenticated;
GRANT ALL ON public.highlights TO service_role;

-- Comment on table and columns for documentation
COMMENT ON TABLE public.highlights IS 'User highlights from audio content with natural story ordering';
COMMENT ON COLUMN public.highlights.id IS 'Unique identifier for the highlight';
COMMENT ON COLUMN public.highlights.user_id IS 'Reference to the user who created the highlight';
COMMENT ON COLUMN public.highlights.content_id IS 'Reference to the content being highlighted';
COMMENT ON COLUMN public.highlights.content_title IS 'Title of the content for grouping highlights';
COMMENT ON COLUMN public.highlights.highlight_text IS 'The actual highlighted text content';
COMMENT ON COLUMN public.highlights.start_time IS 'Start time in seconds for natural story ordering';
COMMENT ON COLUMN public.highlights.created_at IS 'When the highlight was created';
COMMENT ON COLUMN public.highlights.updated_at IS 'When the highlight was last updated';