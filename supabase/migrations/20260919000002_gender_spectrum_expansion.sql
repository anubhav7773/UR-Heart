-- 1. Drop existing rigid gender check constraint
ALTER TABLE public.users 
DROP CONSTRAINT IF EXISTS users_gender_check;

-- 2. Add expanded gender and gender_sub_identity columns
ALTER TABLE public.users 
ALTER COLUMN gender TYPE VARCHAR(50);

ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS gender_sub_identity VARCHAR(50);

-- 3. Add inclusive constraint allowing primary spectrum classifications
ALTER TABLE public.users 
ADD CONSTRAINT users_gender_check CHECK (
    gender IN (
        'male',
        'female',
        'non_binary',
        'trans_man',
        'trans_woman',
        'genderfluid',
        'agender',
        'queer',
        'other'
    )
);

-- Index for discovery feed filtering
CREATE INDEX IF NOT EXISTS idx_users_gender ON public.users(gender);
