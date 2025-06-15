-- Create feedback table
CREATE TABLE IF NOT EXISTS public.feedback (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    user_email TEXT,
    message TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;

-- Create policy to allow authenticated users to insert their own feedback
CREATE POLICY "Users can insert their own feedback" ON public.feedback
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Create policy to allow service role to read all feedback (for admin access)
CREATE POLICY "Service role can read all feedback" ON public.feedback
    FOR SELECT USING (auth.jwt() ->> 'role' = 'service_role');

-- Optional: Create index for better performance
CREATE INDEX IF NOT EXISTS feedback_user_id_idx ON public.feedback(user_id);
CREATE INDEX IF NOT EXISTS feedback_created_at_idx ON public.feedback(created_at DESC);