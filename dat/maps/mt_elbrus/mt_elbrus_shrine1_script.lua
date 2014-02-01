-- Set the namespace according to the map name.
local ns = {};
setmetatable(ns, {__index = _G});
mt_elbrus_shrine1_script = ns;
setfenv(1, ns);

-- The map name, subname and location image
map_name = "Mt. Elbrus"
map_image_filename = "img/menus/locations/mt_elbrus.png"
map_subname = "Underpass"

-- The music file used as default background music on this map.
-- Other musics will have to handled through scripting.
music_filename = "mus/icy_wind.ogg"

-- c++ objects instances
local Map = {};
local ObjectManager = {};
local DialogueManager = {};
local EventManager = {};
local Script = {};

-- the main character handler
local hero = {};

-- Forest dialogue secondary hero
local kalya = {};
local orlinn = {};

-- Name of the main sprite. Used to reload the good one at the end of dialogue events.
local main_sprite_name = "";

-- Objects used during the door opening scene
local shrine_entrance_door = {};
local shrine_entrance_sign = {};

local shrine_flame1 = {};
local shrine_flame2 = {};

-- the main map loading code
function Load(m)

    Map = m;
    ObjectManager = Map.object_supervisor;
    DialogueManager = Map.dialogue_supervisor;
    EventManager = Map.event_supervisor;
    Script = Map:GetScriptSupervisor();

    Map.unlimited_stamina = true;

    _CreateCharacters();
    _CreateObjects();

    -- Set the camera focus on hero
    Map:SetCamera(hero);
    -- This is a dungeon map, we'll use the front battle member sprite as default sprite.
    Map.object_supervisor:SetPartyMemberVisibleSprite(hero);

    _CreateEvents();
    _CreateZones();

    -- Add a mediumly dark overlay when necessary
    if (GlobalManager:GetEventValue("story", "mountain_shrine_entrance_light_done") == 0) then
        Map:GetEffectSupervisor():EnableAmbientOverlay("img/ambient/dark.png", 0.0, 0.0, false);
    end

    -- Event Scripts
    Script:AddScript("dat/maps/mt_elbrus/shrine_entrance_show_crystal_script.lua");

    -- Start the dialogue about snow and the bridge if not done
    if (GlobalManager:GetEventValue("story", "mt_elbrus_shrine_entrance_event") ~= 1) then
        hero:SetMoving(false);
        EventManager:StartEvent("Shrine entrance event start", 200);
    end

    if (GlobalManager:GetEventValue("story", "mt_elbrus_shrine_door_opening_event") == 1) then
        _set_shrine_door_open();
        shrine_entrance_sign:SetVisible(true);
        _show_flames();
    end

    -- Preload sounds
    AudioManager:LoadSound("snd/heartbeat_slow.wav", Map);
    AudioManager:LoadSound("snd/ancient_invocation.wav", Map);
    AudioManager:LoadSound("snd/cave-in.ogg", Map);
end

-- the map update function handles checks done on each game tick.
function Update()
    -- Check whether the character is in one of the zones
    _CheckZones();
end

-- Character creation
function _CreateCharacters()
    -- Default hero and position (from mountain path 4)
    hero = CreateSprite(Map, "Bronann", 29, 44.5);
    hero:SetDirection(vt_map.MapMode.NORTH);
    hero:SetMovementSpeed(vt_map.MapMode.NORMAL_SPEED);

    -- Load previous save point data
    local x_position = GlobalManager:GetSaveLocationX();
    local y_position = GlobalManager:GetSaveLocationY();
    if (x_position ~= 0 and y_position ~= 0) then
        -- Use the save point position, and clear the save position data for next maps
        GlobalManager:UnsetSaveLocation();
        -- Make the character look at us in that case
        hero:SetDirection(vt_map.MapMode.SOUTH);
        hero:SetPosition(x_position, y_position);
    elseif (GlobalManager:GetPreviousLocation() == "from_shrine_main_room") then
        hero:SetDirection(vt_map.MapMode.SOUTH);
        hero:SetPosition(42.0, 9.0);
    end

    Map:AddGroundObject(hero);

    -- Create secondary characters
    kalya = CreateSprite(Map, "Kalya",
                         hero:GetXPosition(), hero:GetYPosition());
    kalya:SetDirection(vt_map.MapMode.EAST);
    kalya:SetMovementSpeed(vt_map.MapMode.NORMAL_SPEED);
    kalya:SetCollisionMask(vt_map.MapMode.NO_COLLISION);
    kalya:SetVisible(false);
    Map:AddGroundObject(kalya);

    orlinn = CreateSprite(Map, "Orlinn",
                          hero:GetXPosition(), hero:GetYPosition());
    orlinn:SetDirection(vt_map.MapMode.EAST);
    orlinn:SetMovementSpeed(vt_map.MapMode.NORMAL_SPEED);
    orlinn:SetCollisionMask(vt_map.MapMode.NO_COLLISION);
    orlinn:SetVisible(false);
    Map:AddGroundObject(orlinn);
end

-- The heal particle effect map object
local heal_effect = {};

function _CreateObjects()
    local object = {}
    local npc = {}
    local dialogue = {}
    local text = {}
    local event = {}

    Map:AddSavePoint(51, 29);

    -- Load the spring heal effect.
    heal_effect = vt_map.ParticleObject("dat/effects/particles/heal_particle.lua", 0, 0);
    heal_effect:SetObjectID(Map.object_supervisor:GenerateObjectID());
    heal_effect:Stop(); -- Don't run it until the character heals itself
    Map:AddGroundObject(heal_effect);

    object = CreateObject(Map, "Layna Statue", 41, 28);
    object:SetEventWhenTalking("Heal dialogue");
    Map:AddGroundObject(object);

    dialogue = vt_map.SpriteDialogue();
    text = vt_system.Translate("Your party feels better...");
    dialogue:AddLineEvent(text, 0, "Heal event", ""); -- 0 means no portrait and no name
    DialogueManager:AddDialogue(dialogue);
    event = vt_map.DialogueEvent("Heal dialogue", dialogue);
    EventManager:RegisterEvent(event);

    -- Snow effect at shrine entrance
    object = vt_map.ParticleObject("dat/maps/mt_elbrus/particles_snow_south_entrance.lua", 29, 48);
    object:SetObjectID(Map.object_supervisor:GenerateObjectID());
    Map:AddGroundObject(object);
    Map:AddHalo("img/misc/lights/torch_light_mask.lua", 29, 55,
        vt_video.Color(1.0, 1.0, 1.0, 0.8));

    -- Adds the north gate
    shrine_entrance_door = CreateObject(Map, "Door1_big", 42, 4);
    Map:AddGroundObject(shrine_entrance_door);

    -- Adds a hidden sign, show just before the opening of the door
    shrine_entrance_sign = CreateObject(Map, "Ancient_Sign1", 42, 10);
    Map:AddFlatGroundObject(shrine_entrance_sign);
    shrine_entrance_sign:SetVisible(false);

    -- Flames that are burning after the opening of the shrine.
    shrine_flame1 = CreateObject(Map, "Flame1", 33, 9.1);
    Map:AddGroundObject(shrine_flame1);
    shrine_flame2 = CreateObject(Map, "Flame1", 51, 9.1);
    Map:AddGroundObject(shrine_flame2);
    shrine_flame1:SetVisible(false);
    shrine_flame2:SetVisible(false);
    shrine_flame1:RandomizeCurrentAnimationFrame();
    shrine_flame2:RandomizeCurrentAnimationFrame();

    -- When the lighting has improved, show the source of it.
    if (GlobalManager:GetEventValue("story", "mountain_shrine_entrance_light_done") == 1) then
        Map:AddHalo("img/misc/lights/torch_light_mask.lua", 42, 8, vt_video.Color(1.0, 1.0, 1.0, 0.6));
        -- Adds a door horizon...
        object = vt_map.PhysicalObject();
        object:SetObjectID(Map.object_supervisor:GenerateObjectID());
        object:SetPosition(42, 0.8);
        object:SetCollHalfWidth(0.5);
        object:SetCollHeight(1.0);
        object:SetImgHalfWidth(0.5);
        object:SetImgHeight(1.0);
        object:AddStillFrame("dat/maps/mt_elbrus/shrine_entrance_light.png");
        Map:AddFlatGroundObject(object);
    end
end

-- Special event references which destinations must be updated just before being called.
local kalya_move_next_to_hero_event1 = {}
local kalya_move_back_to_hero_event1 = {}
local orlinn_move_next_to_hero_event1 = {}
local orlinn_move_back_to_hero_event1 = {}
local kalya_move_next_to_hero_event2 = {}
local kalya_move_back_to_hero_event2 = {}
local orlinn_move_next_to_hero_event2 = {}
local orlinn_move_back_to_hero_event2 = {}

-- Creates all events and sets up the entire event sequence chain
function _CreateEvents()
    local event = {};
    local dialogue = {};
    local text = {};

    event = vt_map.MapTransitionEvent("to mountain shrine", "dat/maps/mt_elbrus/mt_elbrus_shrine2_map.lua",
                                       "dat/maps/mt_elbrus/mt_elbrus_shrine2_script.lua", "from_shrine_entrance");
    EventManager:RegisterEvent(event);
    event = vt_map.MapTransitionEvent("to mountain bridge", "dat/maps/mt_elbrus/mt_elbrus_path4_map.lua",
                                       "dat/maps/mt_elbrus/mt_elbrus_path4_script.lua", "from_shrine_entrance");
    EventManager:RegisterEvent(event);

    -- Heal point
    event = vt_map.ScriptedEvent("Heal event", "heal_party", "heal_done");
    EventManager:RegisterEvent(event);

    -- Generic events
    event = vt_map.ChangeDirectionSpriteEvent("Orlinn looks north", orlinn, vt_map.MapMode.NORTH);
    EventManager:RegisterEvent(event);
    event = vt_map.ChangeDirectionSpriteEvent("Orlinn looks west", orlinn, vt_map.MapMode.WEST);
    EventManager:RegisterEvent(event);
    event = vt_map.ChangeDirectionSpriteEvent("Bronann looks north", hero, vt_map.MapMode.NORTH);
    EventManager:RegisterEvent(event);
    event = vt_map.ChangeDirectionSpriteEvent("Bronann looks south", hero, vt_map.MapMode.SOUTH);
    EventManager:RegisterEvent(event);
    event = vt_map.ChangeDirectionSpriteEvent("Kalya looks north", kalya, vt_map.MapMode.NORTH);
    EventManager:RegisterEvent(event);
    event = vt_map.ChangeDirectionSpriteEvent("Kalya looks west", kalya, vt_map.MapMode.WEST);
    EventManager:RegisterEvent(event);
    event = vt_map.LookAtSpriteEvent("Kalya looks at Bronann", kalya, hero);
    EventManager:RegisterEvent(event);
    event = vt_map.LookAtSpriteEvent("Kalya looks at Orlinn", kalya, orlinn);
    EventManager:RegisterEvent(event);
    event = vt_map.LookAtSpriteEvent("Bronann looks at Kalya", hero, kalya);
    EventManager:RegisterEvent(event);
    event = vt_map.LookAtSpriteEvent("Orlinn looks at Kalya", orlinn, kalya);
    EventManager:RegisterEvent(event);
    event = vt_map.LookAtSpriteEvent("Orlinn looks at Bronann", orlinn, hero);
    EventManager:RegisterEvent(event);

    -- entrance in the map event
    event = vt_map.ScriptedEvent("Shrine entrance event start", "shrine_entrance_event_start", "");
    event:AddEventLinkAtEnd("Kalya moves next to Bronann1", 100);
    event:AddEventLinkAtEnd("Orlinn moves next to Bronann1", 100);
    EventManager:RegisterEvent(event);

    -- NOTE: The actual destination is set just before the actual start call
    kalya_move_next_to_hero_event1 = vt_map.PathMoveSpriteEvent("Kalya moves next to Bronann1", kalya, 0, 0, false);
    kalya_move_next_to_hero_event1:AddEventLinkAtEnd("Kalya moves a bit");
    kalya_move_next_to_hero_event1:AddEventLinkAtEnd("Bronann moves a bit");
    EventManager:RegisterEvent(kalya_move_next_to_hero_event1);
    orlinn_move_next_to_hero_event1 = vt_map.PathMoveSpriteEvent("Orlinn moves next to Bronann1", orlinn, 0, 0, false);
    orlinn_move_next_to_hero_event1:AddEventLinkAtEnd("Orlinn moves near the passway");
    EventManager:RegisterEvent(orlinn_move_next_to_hero_event1);

    event = vt_map.PathMoveSpriteEvent("Kalya moves a bit", kalya, 31, 39, false);
    event:AddEventLinkAtEnd("Kalya looks at Bronann");
    event:AddEventLinkAtEnd("Dialogue about the passage to Estoria", 500);
    EventManager:RegisterEvent(event);
    event = vt_map.PathMoveSpriteEvent("Bronann moves a bit", hero, 29, 39, false);
    event:AddEventLinkAtEnd("Bronann looks at Kalya");
    EventManager:RegisterEvent(event);

    -- Orlinn move near the passway
    event = vt_map.PathMoveSpriteEvent("Orlinn moves near the passway", orlinn, 29, 33, true);
    event:AddEventLinkAtEnd("Orlinn looks west");
    EventManager:RegisterEvent(event);

    dialogue = vt_map.SpriteDialogue();
    text = vt_system.Translate("... You'll see: there's plenty of things I need to show you there. Plus, it's a safe place.");
    dialogue:AddLine(text, kalya);
    text = vt_system.Translate("Err... Sis?");
    dialogue:AddLineEventEmote(text, orlinn, "Orlinn looks at Kalya", "", "sweat drop");
    text = vt_system.Translate("Our Elder will also be able to help us. And you'll get more explanation than I could ever...");
    dialogue:AddLine(text, kalya);
    text = vt_system.Translate("Sis!");
    dialogue:AddLineEvent(text, orlinn, "Orlinn looks at Kalya", "");
    text = vt_system.Translate("... One second, Orlinn. I try to...");
    dialogue:AddLineEvent(text, kalya, "Kalya looks north", "Kalya looks at Bronann");
    text = vt_system.Translate("But Kalya, look at the passageway!");
    dialogue:AddLineEmote(text, orlinn, "exclamation");
    text = vt_system.Translate("What about the...");
    dialogue:AddLineEvent(text, kalya, "Kalya looks north", "");
    text = vt_system.Translate("NO!");
    dialogue:AddLineEmote(text, kalya, "exclamation");
    DialogueManager:AddDialogue(dialogue);
    event = vt_map.DialogueEvent("Dialogue about the passage to Estoria", dialogue);
    event:AddEventLinkAtEnd("Kalya runs to the blocked passage");
    event:AddEventLinkAtEnd("Bronann looks north");
    EventManager:RegisterEvent(event);

    event = vt_map.PathMoveSpriteEvent("Kalya runs to the blocked passage", kalya, 27, 34, true);
    event:AddEventLinkAtEnd("Kalya looks west");
    event:AddEventLinkAtEnd("Dialogue about the passage to Estoria 2");
    EventManager:RegisterEvent(event);

    dialogue = vt_map.SpriteDialogue();
    text = vt_system.Translate("... No, it can't be...");
    dialogue:AddLineEventEmote(text, kalya, "Orlinn looks at Kalya", "", "sweat drop");
    text = vt_system.Translate("After all we've been through, this...");
    dialogue:AddLineEvent(text, kalya, "Kalya looks north", "");
    DialogueManager:AddDialogue(dialogue);
    event = vt_map.DialogueEvent("Dialogue about the passage to Estoria 2", dialogue);
    event:AddEventLinkAtEnd("Bronann goes near both");
    EventManager:RegisterEvent(event);

    event = vt_map.PathMoveSpriteEvent("Bronann goes near both", hero, 28, 36, false);
    event:AddEventLinkAtEnd("Bronann looks north");
    event:AddEventLinkAtEnd("Dialogue about the passage to Estoria 3");
    EventManager:RegisterEvent(event);

    event = vt_map.AnimateSpriteEvent("Orlinn laughs", orlinn, "laughing", 0); -- infinite time.
    EventManager:RegisterEvent(event);

    dialogue = vt_map.SpriteDialogue();
    text = vt_system.Translate("... Calm down Kalya, there must be a way to go through this somehow...");
    dialogue:AddLineEmote(text, hero, "sweat drop");
    text = vt_system.Translate("Unfortunately... Yes, there is one...");
    dialogue:AddLineEvent(text, kalya, "Kalya looks west", "");
    text = vt_system.Translate("We'll have to enter the ancient shrine...");
    dialogue:AddLineEvent(text, kalya, "Kalya looks north", "");
    text = vt_system.Translate("Wouldn't have we flown all by ourselves, I would swear Banesore's army pushed us here on purpose...");
    dialogue:AddLine(text, kalya);
    text = vt_system.Translate("... What's with this 'ancient shrine'?");
    dialogue:AddLineEmote(text, hero, "thinking dots");
    text = vt_system.Translate("Some say it is haunted... And it was sealed a long time ago, long before I was even born.");
    dialogue:AddLineEvent(text, kalya, "Kalya looks at Bronann", "");
    text = vt_system.Translate("Indeed, It must be a long time ago...");
    dialogue:AddLineEventEmote(text, orlinn, "", "Orlinn laughs", "thinking dots");
    text = vt_system.Translate("Orlinn!");
    dialogue:AddLineEventEmote(text, kalya, "Kalya looks at Orlinn", "", "exclamation");
    text = vt_system.Translate("Anyway, we might even not be able to enter there at all. But you're right, let's have a look around first. Who knows?");
    dialogue:AddLineEvent(text, kalya, "Kalya looks at Bronann", "");
    DialogueManager:AddDialogue(dialogue);
    event = vt_map.DialogueEvent("Dialogue about the passage to Estoria 3", dialogue);
    event:AddEventLinkAtEnd("Orlinn goes back to party");
    event:AddEventLinkAtEnd("Kalya goes back to party");
    EventManager:RegisterEvent(event);

    orlinn_move_back_to_hero_event1 = vt_map.PathMoveSpriteEvent("Orlinn goes back to party", orlinn, hero, false);
    orlinn_move_back_to_hero_event1:AddEventLinkAtEnd("Shrine entrance event end");
    EventManager:RegisterEvent(orlinn_move_back_to_hero_event1);

    kalya_move_back_to_hero_event1 = vt_map.PathMoveSpriteEvent("Kalya goes back to party", kalya, hero, false);
    EventManager:RegisterEvent(kalya_move_back_to_hero_event1);

    event = vt_map.ScriptedEvent("Shrine entrance event end", "shrine_entrance_event_end", "");
    EventManager:RegisterEvent(event);

    -- Event where Bronann opens the shrine's door...
    event = vt_map.ScriptedEvent("Shrine door opening event start", "shrine_door_opening_event_start", "");
    event:AddEventLinkAtEnd("Bronann moves in the middle of platform");
    EventManager:RegisterEvent(event);

    event = vt_map.PathMoveSpriteEvent("Bronann moves in the middle of platform", hero, 42.0, 8.0, false);
    event:AddEventLinkAtEnd("Bronann looks north");
    event:AddEventLinkAtEnd("Shrine door opening event actual start");
    EventManager:RegisterEvent(event);

    event = vt_map.ScriptedEvent("Shrine door opening event actual start", "shrine_door_opening_event_start2", "");
    event:AddEventLinkAtEnd("Kalya moves next to Bronann2", 100);
    event:AddEventLinkAtEnd("Orlinn moves next to Bronann2", 100);
    EventManager:RegisterEvent(event);

    -- NOTE: The actual destination is set just before the actual start call
    kalya_move_next_to_hero_event2 = vt_map.PathMoveSpriteEvent("Kalya moves next to Bronann2", kalya, 0, 0, false);
    kalya_move_next_to_hero_event2:AddEventLinkAtEnd("Kalya looks north");
    EventManager:RegisterEvent(kalya_move_next_to_hero_event2);
    orlinn_move_next_to_hero_event2 = vt_map.PathMoveSpriteEvent("Orlinn moves next to Bronann2", orlinn, 0, 0, false);
    orlinn_move_next_to_hero_event2:AddEventLinkAtEnd("Orlinn looks north");
    orlinn_move_next_to_hero_event2:AddEventLinkAtEnd("Dialogue before opening the door", 500);
    EventManager:RegisterEvent(orlinn_move_next_to_hero_event2);

    event = vt_map.AnimateSpriteEvent("Bronann kneels", hero, "kneeling", 0); -- 0 means forever
    EventManager:RegisterEvent(event);

    dialogue = vt_map.SpriteDialogue();
    text = vt_system.Translate("Here we are, looking at this huge, wonderful and yet creepy door... I don't like this...");
    dialogue:AddLineEmote(text, kalya, "thinking dots");
    text = vt_system.Translate("It's not like I actually would want to open it, but how are we going to?");
    dialogue:AddLineEventEmote(text, kalya, "Kalya looks at Bronann", "Orlinn looks at Bronann", "sweat drop");
    DialogueManager:AddDialogue(dialogue);
    event = vt_map.DialogueEvent("Dialogue before opening the door", dialogue);
    event:AddEventLinkAtEnd("Show hurt effect");
    EventManager:RegisterEvent(event);

    event = vt_map.ScriptedEvent("Show hurt effect", "hurt_effect_start", "hurt_effect_update")
    event:AddEventLinkAtEnd("Dialogue before opening the door2");
    EventManager:RegisterEvent(event);

    dialogue = vt_map.SpriteDialogue();
    text = vt_system.Translate("Oh, my chest, it hurts!!");
    dialogue:AddLineEventEmote(text, hero, "Bronann looks south", "Bronann kneels", "exclamation");
    text = vt_system.Translate("The Crystal! ... Orlinn! Let's stand back!");
    dialogue:AddLineEmote(text, kalya, "exclamation");
    DialogueManager:AddDialogue(dialogue);
    event = vt_map.DialogueEvent("Dialogue before opening the door2", dialogue);
    event:AddEventLinkAtEnd("Orlinn rushes down the stairs");
    event:AddEventLinkAtEnd("Kalya rushes down the stairs");
    EventManager:RegisterEvent(event);

    event = vt_map.PathMoveSpriteEvent("Kalya rushes down the stairs", kalya, 43.0, 16.0, true);
    event:AddEventLinkAtEnd("Kalya looks north");
    EventManager:RegisterEvent(event);
    event = vt_map.PathMoveSpriteEvent("Orlinn rushes down the stairs", orlinn, 41.0, 16.0, true);
    event:AddEventLinkAtEnd("Orlinn goes behind Kalya");
    EventManager:RegisterEvent(event);
    event = vt_map.PathMoveSpriteEvent("Orlinn goes behind Kalya", orlinn, 42.6, 17.0, true);
    event:AddEventLinkAtEnd("Orlinn looks north");
    event:AddEventLinkAtEnd("The crystal opens the door");
    EventManager:RegisterEvent(event);

    event = vt_map.ScriptedEvent("The crystal opens the door", "show_crystal", "show_crystal_update");
    event:AddEventLinkAtEnd("Dialogue after crystals appearance");
    EventManager:RegisterEvent(event);

    dialogue = vt_map.SpriteDialogue();
    text = vt_system.Translate("That sign... It is the sign of the Ancients! ... Bronann! Are you alright?");
    dialogue:AddLineEmote(text, kalya, "exclamation");
    DialogueManager:AddDialogue(dialogue);
    event = vt_map.DialogueEvent("Dialogue after crystals appearance", dialogue);
    event:AddEventLinkAtEnd("Bronann gets up", 1200);
    EventManager:RegisterEvent(event);

    -- Simply stop the custom animation
    event = vt_map.ScriptedSpriteEvent("Bronann gets up", hero, "Terminate_all_events", "");
    event:AddEventLinkAtEnd("Dialogue after crystals appearance2", 1000);
    EventManager:RegisterEvent(event);

    dialogue = vt_map.SpriteDialogue();
    text = vt_system.Translate("... I'm fine... I guess... The pain faded away...");
    dialogue:AddLineEvent(text, hero, "Bronann looks south", "");
    text = vt_system.Translate("Thanks goddess...");
    dialogue:AddLineEmote(text, kalya, "sweat drop");
    text = vt_system.Translate("Well, the door is open now...");
    dialogue:AddLineEmote(text, kalya, "thinking dots");
    text = vt_system.Translate("Yiek! Do you really want to go there??");
    dialogue:AddLineEmote(text, orlinn, "sweat drop");
    text = vt_system.Translate("I believe we don't really have a choice... Somehow this place... called me.");
    dialogue:AddLineEventEmote(text, hero, "Bronann looks north", "", "thinking dots");
    text = vt_system.Translate("Anyway, let's stick together and we'll be fine as always, right?");
    dialogue:AddLineEvent(text, kalya, "Kalya looks at Orlinn", "");
    text = vt_system.Translate("... I have a bad feeling about all this now...");
    dialogue:AddLineEvent(text, orlinn, "Orlinn looks at Kalya", "");
    DialogueManager:AddDialogue(dialogue);
    event = vt_map.DialogueEvent("Dialogue after crystals appearance2", dialogue);
    event:AddEventLinkAtEnd("Orlinn goes back to party2");
    event:AddEventLinkAtEnd("Kalya goes back to party2");
    EventManager:RegisterEvent(event);

    orlinn_move_back_to_hero_event2 = vt_map.PathMoveSpriteEvent("Orlinn goes back to party2", orlinn, hero, false);
    orlinn_move_back_to_hero_event2:AddEventLinkAtEnd("Shrine door opening event end");
    EventManager:RegisterEvent(orlinn_move_back_to_hero_event2);

    kalya_move_back_to_hero_event2 = vt_map.PathMoveSpriteEvent("Kalya goes back to party2", kalya, hero, false);
    EventManager:RegisterEvent(kalya_move_back_to_hero_event2);

    event = vt_map.ScriptedEvent("Shrine door opening event end", "shrine_door_opening_event_end", "");
    EventManager:RegisterEvent(event);
end

-- zones
local to_shrine_zone = {};
local to_mountain_bridge_zone = {};
local shrine_door_opening_zone = {};

-- Create the different map zones triggering events
function _CreateZones()

    -- N.B.: left, right, top, bottom
    to_shrine_zone = vt_map.CameraZone(40, 44, 2, 4);
    Map:AddZone(to_shrine_zone);

    to_mountain_bridge_zone = vt_map.CameraZone(26, 32, 46, 48);
    Map:AddZone(to_mountain_bridge_zone);

    shrine_door_opening_zone = vt_map.CameraZone(40, 44, 8, 10);
    Map:AddZone(shrine_door_opening_zone);
end

-- Check whether the active camera has entered a zone. To be called within Update()
function _CheckZones()
    if (to_shrine_zone:IsCameraEntering() == true) then
        hero:SetMoving(false);
        EventManager:StartEvent("to mountain shrine");
    elseif (to_mountain_bridge_zone:IsCameraEntering() == true) then
        hero:SetMoving(false);
        EventManager:StartEvent("to mountain bridge");
    elseif (shrine_door_opening_zone:IsCameraEntering() == true and Map:CurrentState() == vt_map.MapMode.STATE_EXPLORE) then
        if (GlobalManager:GetEventValue("story", "mt_elbrus_shrine_door_opening_event") == 0) then
            hero:SetMoving(false);
            EventManager:StartEvent("Shrine door opening event start");
        end
    end

end

-- Opens the shrine door
function _open_shrine_door()
    -- Permit the entrance into the shrine...
    shrine_entrance_door:SetCollisionMask(vt_map.MapMode.NO_COLLISION);
    -- Makes the door open
    local opening_anim_id = shrine_entrance_door:AddAnimation("img/sprites/map/objects/door_big1_opening.lua");
    shrine_entrance_door:SetCurrentAnimation(opening_anim_id);
end

-- Set the shrine door as opened
function _set_shrine_door_open()
    -- Permit the entrance into the shrine...
    shrine_entrance_door:SetCollisionMask(vt_map.MapMode.NO_COLLISION);
    -- Makes the door open
    local open_anim_id = shrine_entrance_door:AddAnimation("img/sprites/map/objects/door_big1_open.lua");
    shrine_entrance_door:SetCurrentAnimation(open_anim_id);
end

function _show_flames()
    local object = vt_map.SoundObject("snd/campfire.ogg", 33.0, 9.1, 5.0);
    if (object ~= nil) then Map:AddAmbientSoundObject(object) end;
    object = vt_map.SoundObject("snd/campfire.ogg", 51.0, 9.1, 5.0);
    if (object ~= nil) then Map:AddAmbientSoundObject(object) end;

    Map:AddHalo("img/misc/lights/torch_light_mask2.lua", 33.0, 9.1 + 3.0,
        vt_video.Color(0.85, 0.32, 0.0, 0.6));
    Map:AddHalo("img/misc/lights/sun_flare_light_main.lua", 33.0, 9.1 + 2.0,
        vt_video.Color(0.99, 1.0, 0.27, 0.1));
    Map:AddHalo("img/misc/lights/torch_light_mask2.lua", 51.0, 9.1 + 3.0,
        vt_video.Color(0.85, 0.32, 0.0, 0.6));
    Map:AddHalo("img/misc/lights/sun_flare_light_main.lua", 51.0, 9.1 + 2.0,
        vt_video.Color(0.99, 1.0, 0.27, 0.1));

    shrine_flame1:SetVisible(true);
    shrine_flame2:SetVisible(true);
end

-- Effect time used when applying the heal light effect
local heal_effect_time = 0;
local heal_color = vt_video.Color(0.0, 0.0, 1.0, 1.0);

-- Shown when Bronnan feels bad.
local hurt_effect_time = 0;
local hurt_color = vt_video.Color(1.0, 0.0, 0.0, 1.0);

-- Used in the crystal appearance scene.
local crystal_appearance_time = 0;
local ancient_sign_visible = false;

-- Map Custom functions
-- Used through scripted events
map_functions = {
    heal_party = function()
        hero:SetMoving(false);
        -- Should be sufficient to heal anybody
        GlobalManager:GetActiveParty():AddHitPoints(10000);
        GlobalManager:GetActiveParty():AddSkillPoints(10000);
        Map:SetStamina(10000);
        AudioManager:PlaySound("snd/heal_spell.wav");
        heal_effect:SetPosition(hero:GetXPosition(), hero:GetYPosition());
        heal_effect:Start();
        heal_effect_time = 0;
    end,

    heal_done = function()
        heal_effect_time = heal_effect_time + SystemManager:GetUpdateTime();

        if (heal_effect_time < 300.0) then
            heal_color:SetAlpha(heal_effect_time / 300.0 / 3.0);
            Map:GetEffectSupervisor():EnableLightingOverlay(heal_color);
            return false;
        end

        if (heal_effect_time < 1000.0) then
            heal_color:SetAlpha(((1000.0 - heal_effect_time) / 700.0) / 3.0);
            Map:GetEffectSupervisor():EnableLightingOverlay(heal_color);
            return false;
        end
        return true;
    end,

    shrine_entrance_event_start = function()
        Map:PushState(vt_map.MapMode.STATE_SCENE);
        -- Keep a reference of the correct sprite for the event end.
        main_sprite_name = hero:GetSpriteName();

        -- Make the hero be Bronann for the event.
        hero:ReloadSprite("Bronann");

        kalya:SetPosition(hero:GetXPosition(), hero:GetYPosition());
        kalya:SetVisible(true);
        orlinn:SetPosition(hero:GetXPosition(), hero:GetYPosition());
        orlinn:SetVisible(true);
        kalya:SetCollisionMask(vt_map.MapMode.NO_COLLISION);
        orlinn:SetCollisionMask(vt_map.MapMode.NO_COLLISION);

        kalya_move_next_to_hero_event1:SetDestination(hero:GetXPosition() + 2.0, hero:GetYPosition(), false);
        orlinn_move_next_to_hero_event1:SetDestination(hero:GetXPosition() - 2.0, hero:GetYPosition(), false);
    end,

    shrine_entrance_event_end = function()
        Map:PopState();
        kalya:SetPosition(0, 0);
        kalya:SetVisible(false);
        kalya:SetCollisionMask(vt_map.MapMode.NO_COLLISION);
        orlinn:SetPosition(0, 0);
        orlinn:SetVisible(false);
        orlinn:SetCollisionMask(vt_map.MapMode.NO_COLLISION);

        -- Reload the hero back to default
        hero:ReloadSprite(main_sprite_name);

        -- Set event as done
        GlobalManager:SetEventValue("story", "mt_elbrus_shrine_entrance_event", 1);
    end,

    shrine_door_opening_event_start = function()
        Map:PushState(vt_map.MapMode.STATE_SCENE);
    end,

    shrine_door_opening_event_start2 = function()
        -- Keep a reference of the correct sprite for the event end.
        main_sprite_name = hero:GetSpriteName();

        -- Make the hero be Bronann for the event.
        hero:ReloadSprite("Bronann");

        kalya:SetPosition(hero:GetXPosition(), hero:GetYPosition());
        kalya:SetVisible(true);
        orlinn:SetPosition(hero:GetXPosition(), hero:GetYPosition());
        orlinn:SetVisible(true);
        kalya:SetCollisionMask(vt_map.MapMode.NO_COLLISION);
        orlinn:SetCollisionMask(vt_map.MapMode.NO_COLLISION);

        kalya_move_next_to_hero_event2:SetDestination(hero:GetXPosition() + 2.0, hero:GetYPosition(), false);
        orlinn_move_next_to_hero_event2:SetDestination(hero:GetXPosition() - 2.0, hero:GetYPosition(), false);
    end,

    hurt_effect_start = function()
        hurt_effect_time = 0;
        AudioManager:PlaySound("snd/heartbeat_slow.wav");
    end,

    hurt_effect_update = function()
        hurt_effect_time = hurt_effect_time + SystemManager:GetUpdateTime();

        if (hurt_effect_time < 300.0) then
            hurt_color:SetAlpha(hurt_effect_time / 300.0 / 3.0);
            Map:GetEffectSupervisor():EnableLightingOverlay(hurt_color);
            return false;
        end

        if (hurt_effect_time < 600.0) then
            hurt_color:SetAlpha(((600.0 - hurt_effect_time) / 300.0) / 3.0);
            Map:GetEffectSupervisor():EnableLightingOverlay(hurt_color);
            return false;
        end
        return true;
    end,

    show_crystal = function()
        -- Triggers the crystal appearance
        GlobalManager:SetEventValue("scripts_events", "shrine_entrance_show_crystal", 1)
        crystal_appearance_time = 0;
        ancient_sign_visible = false;
    end,

    show_crystal_update = function()
        -- Show the ancient sign on ground.
        if (ancient_sign_visible == false) then
            crystal_appearance_time = crystal_appearance_time + SystemManager:GetUpdateTime();
            if (crystal_appearance_time >= 8000) then
                shrine_entrance_sign:SetVisible(true);
                ancient_sign_visible = true;
                AudioManager:PlaySound("snd/ancient_invocation.wav");
            end
        end
        if (GlobalManager:GetEventValue("scripts_events", "shrine_entrance_show_crystal") == 0) then
            Map:GetEffectSupervisor():ShakeScreen(0.4, 2200, vt_mode_manager.EffectSupervisor.SHAKE_FALLOFF_GRADUAL);
            AudioManager:PlaySound("snd/cave-in.ogg");
            _open_shrine_door();
            -- Show a slight fire spiral effect.
            Map:GetParticleManager():AddParticleEffect("dat/effects/particles/fire_spiral.lua", 512.0, 284.0);
            _show_flames();
            return true;
        end
        return false;
    end,

    shrine_door_opening_event_end = function()
        Map:PopState();
        kalya:SetPosition(0, 0);
        kalya:SetVisible(false);
        kalya:SetCollisionMask(vt_map.MapMode.NO_COLLISION);
        orlinn:SetPosition(0, 0);
        orlinn:SetVisible(false);
        orlinn:SetCollisionMask(vt_map.MapMode.NO_COLLISION);

        -- Reload the hero back to default
        hero:ReloadSprite(main_sprite_name);

        -- Set event as done
        GlobalManager:SetEventValue("story", "mt_elbrus_shrine_door_opening_event", 1);
    end,
}
