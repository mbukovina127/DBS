-- Insert dream-themed classes with your exact schema
INSERT INTO classes (
    id,
    base_health,
    base_strength,
    base_dexterity,
    base_intelligence,
    base_constitution,
    base_action_points,
    health_modifier,
    strength_modifier,
    dexterity_modifier,
    intelligence_modifier,
    constitution_modifier,
    encumbrance_modifier,
    defence_modifier,
    ap_modifier
) VALUES
-- 1. Dreamwalker (balanced dream explorer)
(
    1,              -- id
    100,            -- base_health
    10,             -- base_strength
    12,             -- base_dexterity
    16,             -- base_intelligence
    12,             -- base_constitution
    8,              -- base_action_points
    10,             -- health_modifier (+10%)
    -5,             -- strength_modifier (-5%)
    15,             -- dexterity_modifier (+15%)
    20,             -- intelligence_modifier (+20%)
    0,              -- constitution_modifier (+0%)
    -10,            -- encumbrance_modifier (-10%)
    5,              -- defence_modifier (+5%)
    10              -- ap_modifier (+10%)
),

-- 2. Oneironaut (lucid dreaming specialist)
(
    2,
    80,
    8,
    14,
    20,
    10,
    10,
    -5,
    -10,
    5,
    30,
    -5,
    -15,
    0,
    15
),

-- 3. Nightmare Warden (dream protector)
(
    3,
    120,
    16,
    10,
    12,
    16,
    6,
    20,
    15,
    0,
    10,
    20,
    5,
    15,
    5
),

-- 4. Meditation Sage (focused discipline)
(
    4,
    90,
    6,
    16,
    18,
    14,
    12,
    5,
    -15,
    10,
    25,
    15,
    -20,
    10,
    20
);

-- Insert sample characters with NULL for derived stats
INSERT INTO characters (
    id,
    class_id,
    nickname,
    health,
    strength,
    dexterity,
    intelligence,
    constitution,
    encumbrance,
    action_points
) VALUES
-- Dreamwalker character
(
    1,
    1,
    'Lumen the Awake',
    NULL,  -- will be derived
    NULL,  -- will be derived
    NULL,  -- will be derived
    NULL,  -- will be derived
    NULL,  -- will be derived
    NULL,  -- will be derived
    NULL   -- will be derived
),

-- Oneironaut character
(
    2,
    2,
    'Phantasos',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL
),

-- Nightmare Warden character
(
    3,
    3,
    'Morpheus Guardian',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL
),

-- Meditation Sage character
(
    4,
    4,
    'Zenith the Clear',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL
);

UPDATE characters c
SET 
    health = cl.base_health,
    strength = cl.base_strength,
    dexterity = cl.base_dexterity,
    intelligence = cl.base_intelligence,
    constitution = cl.base_constitution,
    action_points = cl.base_action_points
FROM classes cl
WHERE c.class_id = cl.id;