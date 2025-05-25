-- Supabase Setup for Sapients Audio-Text Sync App
-- Run these commands in your Supabase SQL Editor

-- Create content table
CREATE TABLE content (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  description TEXT,
  audio_url TEXT NOT NULL,
  image_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create transcriptions table
CREATE TABLE transcriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  content_id UUID REFERENCES content(id) ON DELETE CASCADE,
  text TEXT NOT NULL,
  start_time FLOAT NOT NULL,
  end_time FLOAT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Set up Row Level Security
ALTER TABLE content ENABLE ROW LEVEL SECURITY;
ALTER TABLE transcriptions ENABLE ROW LEVEL SECURITY;

-- Create policies for public read access
CREATE POLICY "Public read access for content" ON content
  FOR SELECT USING (true);
  
CREATE POLICY "Public read access for transcriptions" ON transcriptions
  FOR SELECT USING (true);

-- Insert actual data
INSERT INTO content (title, description, audio_url, image_url) VALUES 
  ('The unsettling silence', 'Why we often avoid our own thoughts and seek constant engagement.', 'unsettling.mp3', 'Whisk_090da2eb6f.jpg');

-- Transcriptions for "The unsettling silence"
-- Note: You'll need to replace the content_id with actual UUIDs from your content table
INSERT INTO transcriptions (content_id, text, start_time, end_time) VALUES
  ((SELECT id FROM content WHERE title = 'The unsettling silence' LIMIT 1), 'The unsettling silence, why we often avoid our own thoughts and seek constant engagement.', 0.491, 7.461),
  ((SELECT id FROM content WHERE title = 'The unsettling silence' LIMIT 1), 'Many people find themselves in a relentless pursuit of distraction, filling their days with activities, noise, and social interactions.', 8.101, 16.311),
  ((SELECT id FROM content WHERE title = 'The unsettling silence' LIMIT 1), 'This aversion to simply being alone with one''s thoughts is a common human experience, driven by a complex interplay of psychological, societal, and even technological factors.', 16.701, 28.751),
  ((SELECT id FROM content WHERE title = 'The unsettling silence' LIMIT 1), 'At its core, the desire to keep engaged often stems from a discomfort with the internal landscape of our minds and a fear of what we might find in the quiet.', 29.521, 39.601),
  ((SELECT id FROM content WHERE title = 'The unsettling silence' LIMIT 1), 'One of the primary reasons for this avoidance is the nature of our thoughts themselves.', 40.531, 45.681),
  ((SELECT id FROM content WHERE title = 'The unsettling silence' LIMIT 1), 'Unbidden, our minds can conjure a stream of worries, anxieties, unresolved issues, and self-criticism.', 46.181, 53.211),
  ((SELECT id FROM content WHERE title = 'The unsettling silence' LIMIT 1), 'This internal chatter can be unpleasant and for some, deeply distressing.', 53.671, 58.731),
  ((SELECT id FROM content WHERE title = 'The unsettling silence' LIMIT 1), 'Research suggests that mental effort itself can sometimes be perceived as aversive, and when that effort involves confronting challenging emotions or cognitive dissonance, the discomfort of holding conflicting beliefs, the urge to escape into external stimuli becomes strong.', 59.241, 76.671),
  ((SELECT id FROM content WHERE title = 'The unsettling silence' LIMIT 1), 'The fear of boredom also plays a significant role.', 77.461, 80.771),
  ((SELECT id FROM content WHERE title = 'The unsettling silence' LIMIT 1), 'In a society that often equates busyness with productivity and self-worth, moments of idleness can feel unproductive or even indicative of a lack of purpose.', 81.191, 91.541),
  ((SELECT id FROM content WHERE title = 'The unsettling silence' LIMIT 1), 'This cult of busyness can make quiet introspection seem like a waste of time, leading individuals to seek constant engagement to feel validated and occupied.', 92.101, 101.811),
  ((SELECT id FROM content WHERE title = 'The unsettling silence' LIMIT 1), 'Boredom can also act as a gateway to confronting uncomfortable truths or emotions that lie beneath the surface, an experience many would rather sidestep.', 102.501, 112.791),
  ((SELECT id FROM content WHERE title = 'The unsettling silence' LIMIT 1), 'Furthermore, keeping ourselves engaged serves as a potent emotional regulation strategy.', 113.501, 118.901),
  ((SELECT id FROM content WHERE title = 'The unsettling silence' LIMIT 1), 'Distraction can be a coping mechanism to avoid or numb difficult feelings such as sadness, loneliness, anxiety, or grief.', 119.441, 127.671),
  ((SELECT id FROM content WHERE title = 'The unsettling silence' LIMIT 1), 'The relentless influx of information and entertainment offered by modern technology, particularly smartphones and social media, provides an easily accessible and highly effective means of diverting attention away from internal discomfort.', 128.181, 142.811),
  ((SELECT id FROM content WHERE title = 'The unsettling silence' LIMIT 1), 'This constant connectivity can also foster a need for external validation, where engagement is driven by a desire for likes, comments, and the feeling of being connected, albeit sometimes superficially.', 143.371, 155.941),
  ((SELECT id FROM content WHERE title = 'The unsettling silence' LIMIT 1), 'For some, the avoidance of solitude can be more profound, verging on autophobia, the fear of being alone.', 156.861, 163.781),
  ((SELECT id FROM content WHERE title = 'The unsettling silence' LIMIT 1), 'This can be rooted in past traumas, deep-seated insecurities, or certain personality traits that make solitude feel threatening rather than restorative.', 164.291, 173.611),
  ((SELECT id FROM content WHERE title = 'The unsettling silence' LIMIT 1), 'In such cases, the presence of others or constant activity provides a sense of safety and distraction from unsettling inner experiences.', 174.131, 182.511),
  ((SELECT id FROM content WHERE title = 'The unsettling silence' LIMIT 1), 'Existential anxieties too can surface in moments of quiet contemplation, questions about life''s meaning, purpose, and our own identity can be daunting.', 183.341, 192.831),
  ((SELECT id FROM content WHERE title = 'The unsettling silence' LIMIT 1), 'Engaging in constant activity can serve as a way to keep these larger, sometimes unsettling questions at bay.', 193.391, 200.991),
  ((SELECT id FROM content WHERE title = 'The unsettling silence' LIMIT 1), 'However, it''s important to acknowledge that while the pull of constant engagement is strong, deliberately creating space for solitude and introspection carries significant benefits.', 201.701, 211.921),
  ((SELECT id FROM content WHERE title = 'The unsettling silence' LIMIT 1), 'It can foster self-awareness, enhance creativity, improve problem-solving skills, and allow for genuine emotional processing.', 212.471, 220.801),
  ((SELECT id FROM content WHERE title = 'The unsettling silence' LIMIT 1), 'Learning to sit with our thoughts, even the uncomfortable ones, is a crucial aspect of psychological well-being and personal growth.', 221.391, 228.881),
  ((SELECT id FROM content WHERE title = 'The unsettling silence' LIMIT 1), 'Techniques such as mindfulness and cognitive reframing can help individuals develop a more comfortable and accepting relationship with their inner world.', 229.471, 237.841);

-- Create storage buckets (run these in the Storage section of Supabase Dashboard)
-- 1. Create bucket named 'audio' for MP3 files
-- 2. Create bucket named 'images' for thumbnail images
-- 3. Set both buckets to public for read access 