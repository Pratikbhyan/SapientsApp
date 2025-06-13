-- Create highlights table for user highlights
CREATE TABLE IF NOT EXISTS public.highlights (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    content_id UUID REFERENCES public.content(id) ON DELETE CASCADE,
    content_title TEXT NOT NULL,
    highlight_text TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS highlights_user_id_idx ON public.highlights(user_id);
CREATE INDEX IF NOT EXISTS highlights_content_id_idx ON public.highlights(content_id);
CREATE INDEX IF NOT EXISTS highlights_created_at_idx ON public.highlights(created_at DESC);

-- Enable RLS
ALTER TABLE public.highlights ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can view their own highlights" 
ON public.highlights FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own highlights" 
ON public.highlights FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own highlights" 
ON public.highlights FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own highlights" 
ON public.highlights FOR DELETE 
USING (auth.uid() = user_id);

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_highlights_updated_at 
    BEFORE UPDATE ON public.highlights 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();