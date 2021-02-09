-- Configuration --------------------------------------
AUTOTRACKER_ENABLE_DEBUG_LOGGING = false
-------------------------------------------------------

print("")
print("Active Auto-Tracker Configuration")
print("---------------------------------------------------------------------")
print("Enable Item Tracking:        ", AUTOTRACKER_ENABLE_ITEM_TRACKING)
print("Enable Location Tracking:    ", AUTOTRACKER_ENABLE_LOCATION_TRACKING)
if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
    print("Enable Debug Logging:        ", "true")
end
print("---------------------------------------------------------------------")
print("")

U8_READ_CACHE = 0
U8_READ_CACHE_ADDRESS = 0

function autotracker_started()
    print("Started Tracking")
end

function InvalidateReadCaches()
    U8_READ_CACHE_ADDRESS = 0
end

function ReadU8(segment, address)
    if U8_READ_CACHE_ADDRESS ~= address then
        U8_READ_CACHE = segment:ReadUInt8(address)
        U8_READ_CACHE_ADDRESS = address
    end
    return U8_READ_CACHE
end

function isInGame()
  return AutoTracker:ReadU8(0x0201327A) > 0x00
end

function updateToggleItemFromByteAndFlag(segment, code, address, flag)
    local item = Tracker:FindObjectForCode(code)
    if item then
        local value = ReadU8(segment, address)
        if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
            print(item.Name, code, flag)
        end

        local flagTest = value & flag

        if flagTest ~= 0 then
            item.Active = true
        else
            item.Active = false
        end
    end
end

PREVIOUS_CANDLE_VALUE = 0x00
RESEVOIR_CANDLE_BIT = 0x00
DANCE_HALL_CANDLE_BIT = 0x00
ARENA_CANDLE_BIT = 0x00
RESEVOIR_POSSIBLE = false
ARENA_POSSIBLE = false
DANCE_HALL_POSSIBLE = false

function updateMoneyCandleLocation(segment)
    -- Candles in the original game so there is no harded bit used as a flag
    -- It uses 374 but each item is assigned 01, 02, 04 seemingly randomly
    -- Use if the map location has been accessed to determine which one
    -- to set as a best effort
    local value = ReadU8(segment, 0x02000374)

    if PREVIOUS_CANDLE_VALUE ~= value then
      local newBit = PREVIOUS_CANDLE_VALUE ~ value
      PREVIOUS_CANDLE_VALUE = value
      if RESEVOIR_CANDLE_BIT == 0x00 and RESEVOIR_POSSIBLE then
        RESEVOIR_CANDLE_BIT = newBit
        local location = Tracker:FindObjectForCode("@Underground Reservoir Demon's Treasure/Demon's Treasure")
        if location.Owner.ModifiedByUser then
            return
        end
        location.AvailableChestCount = 0
      elseif ARENA_CANDLE_BIT == 0x00 and ARENA_POSSIBLE then
        ARENA_CANDLE_BIT = newBit
        local location = Tracker:FindObjectForCode("@Creaking Skull Brother/Some Guarded Ring")
        if location.Owner.ModifiedByUser then
            return
        end
        location.AvailableChestCount = 0
      elseif DANCE_HALL_CANDLE_BIT == 0x00 and DANCE_HALL_POSSIBLE then
        DANCE_HALL_CANDLE_BIT = newBit
        local location = Tracker:FindObjectForCode("@Dance Hall Pit Dead End/Dead End")
        if location.Owner.ModifiedByUser then
            return
        end
        location.AvailableChestCount = 0
      end
      
      -- Reset the values if this changes
      if RESEVOIR_CANDLE_BIT ~= 0x00 and value & RESEVOIR_CANDLE_BIT == 0 then
        RESEVOIR_CANDLE_BIT = 0x00
        local location = Tracker:FindObjectForCode("@Underground Reservoir Demon's Treasure/Demon's Treasure")
        if location.Owner.ModifiedByUser then
            return
        end
        location.AvailableChestCount = 1
      end
      if ARENA_CANDLE_BIT ~= 0x00 and value & ARENA_CANDLE_BIT == 0 then
        ARENA_CANDLE_BIT = 0x00
        local location = Tracker:FindObjectForCode("@Creaking Skull Brother/Some Guarded Ring")
        if location.Owner.ModifiedByUser then
            return
        end
        location.AvailableChestCount = 1
      end
      if DANCE_HALL_CANDLE_BIT ~= 0x00 and value & DANCE_HALL_CANDLE_BIT == 0 then
        DANCE_HALL_CANDLE_BIT = 0x00
        local location = Tracker:FindObjectForCode("@Dance Hall Pit Dead End/Dead End")
        if location.Owner.ModifiedByUser then
            return
        end
        location.AvailableChestCount = 1
      end
    end
end

function updateMoneyCandleLocationsPossibleFromSegment(segment)
  local resevoirRoomValue = ReadU8(segment, 0x0200015F)
  local danceHallRoomValue = ReadU8(segment, 0x0200013C)
  local arenaRoomValue = ReadU8(segment, 0x0200017D)
  if resevoirRoomValue & 0x40 ~= 0 then
    RESEVOIR_POSSIBLE = true
  else
    RESEVOIR_POSSIBLE = false
  end
  if danceHallRoomValue & 0x80 ~= 0 then
    DANCE_HALL_POSSIBLE = true
  else 
    DANCE_HALL_POSSIBLE = false
  end
  if arenaRoomValue & 0x01 ~= 0 then
    ARENA_POSSIBLE = true
  else
    ARENA_POSSIBLE = false
  end
end
  

BLUE_BOOK_STAGE = 0
RED_BOOK_STAGE = 0
YELLOW_BOOK_STAGE = 0

function updateProgessiveItemFromByteAndFlag(segment, code, address, flag, currentStage)
    local item = Tracker:FindObjectForCode(code)
    if item then
        local value = ReadU8(segment, address)
        if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
            print(item.Name, code, flag)
        end

        local flagTest = value & flag

        if flagTest ~= 0 and currentStage == 0 then
            item.CurrentStage = 1
            currentStage = 1
        elseif currentStage == 1 then
            item.CurrentStage = 0
        end
    end
end 

function updateSectionChestCountFromByteAndFlag(segment, locationRef, address, flag, callback)
    local location = Tracker:FindObjectForCode(locationRef)
    if location then
        -- Do not auto-track this the user has manually modified it
        if location.Owner.ModifiedByUser then
            return
        end

        local value = ReadU8(segment, address)
        
        if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
            print(locationRef, value)
        end
  
        if (value & flag) ~= 0 then
            location.AvailableChestCount = 0
            if callback then
                callback(true)
            end
        else
            location.AvailableChestCount = location.ChestCount
            if callback then
                callback(false)
            end
        end
    elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING then
        print("Couldn't find location", locationRef)
    end
end

function update2ItemLocation(segment, locationRef, item1Address, item1Flag, item2Address, item2Flag)
  local location = Tracker:FindObjectForCode(locationRef)

  if location then
        -- Do not auto-track this the user has manually modified it
        if location.Owner.ModifiedByUser then
            return
        end

        local item1Value = ReadU8(segment, item1Address)
        local item2Value = ReadU8(segment, item2Address)
        local item1Retrieved = (item1Value & item1Flag) ~= 0
        local item2Retrieved = (item2Value & item2Flag) ~= 0

        if item1Retrieved and item2Retrieved then
            location.AvailableChestCount = 0
        elseif item1Retrieved or item2Retrieved then
            location.AvailableChestCount = 1
        else
            location.AvailableChestCount = 2
        end
    elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING then
        print("Couldn't find locationRef ", locationRef)
    end
end

function updateRushSoul(segment)
  local item = Tracker:FindObjectForCode("rush")
  if item then
    local manitcoreValue = ReadU8(segment, 0x0201335D)
    local manticoreTest = manitcoreValue & 0x0F
    local curlyValue = ReadU8(segment, 0x0201335D)
    local curlyTest =  curlyValue & 0xF0
    local devilValue = ReadU8(segment, 0x0201335C)
    local devilTest = devilValue & 0xF0
    if manticoreTest ~= 0 or curlyTest ~= 0 or devilTest ~= 0 then
      item.Active = true
    else
      item.Active = false
    end
  end
end

function updateItemsFromMemorySegment(segment)
    if not isInGame() then
        return false
    end

    InvalidateReadCaches()

    if AUTOTRACKER_ENABLE_ITEM_TRACKING then
        updateToggleItemFromByteAndFlag(segment, "djump", 0x02013393, 0x0F)
        updateToggleItemFromByteAndFlag(segment, "bat", 0x02013354, 0xF0)
        updateToggleItemFromByteAndFlag(segment, "blackp", 0x02013355, 0x0F)
        updateToggleItemFromByteAndFlag(segment, "slide", 0x02013392, 0xF0)
        updateToggleItemFromByteAndFlag(segment, "divekick", 0x02013393, 0xF0)
        updateToggleItemFromByteAndFlag(segment, "backDash", 0x02013392, 0x0F)
        updateToggleItemFromByteAndFlag(segment, "flyingarmor", 0x02013354, 0x0F)
        updateToggleItemFromByteAndFlag(segment, "Galamoth", 0x02013394, 0xF0)
        updateToggleItemFromByteAndFlag(segment, "Hyppogriph", 0x02013394, 0x0F)
        updateToggleItemFromByteAndFlag(segment, "skula", 0x0201336E , 0xF0)
        updateToggleItemFromByteAndFlag(segment, "Undine", 0x0201336E,0x0F)
        updateToggleItemFromByteAndFlag(segment, "Undine", 0x0201336E,0x0F)

        updateRushSoul(segment)
    end
end

function updateBooksFromMemorySegment(segment)
    if AUTOTRACKER_ENABLE_ITEM_TRACKING then
      updateProgessiveItemFromByteAndFlag(segment, "bookred", 0x020132AE, 0xFF, RED_BOOK_STAGE)
      updateProgessiveItemFromByteAndFlag(segment, "bookblue", 0x020132AF, 0xFF, BLUE_BOOK_STAGE)
      updateProgessiveItemFromByteAndFlag(segment, "bookyellow", 0x020132B0, 0xFF, YELLOW_BOOK_STAGE)
    end
end

function updateGrahamFromMemorySegment(segment)
    if AUTOTRACKER_ENABLE_ITEM_TRACKING then
      updateToggleItemFromByteAndFlag(segment, "graham", 0x02000343,0x04)
      -- Julian is 0x02000341, 0x04
    end
end

function updateChestsFromMemorySegmentCorridor(segment)
    if not isInGame() then
        return false
    end

    InvalidateReadCaches()

    if AUTOTRACKER_ENABLE_LOCATION_TRACKING then
        updateSectionChestCountFromByteAndFlag(segment, "@Corridor Entrance/Top", 0x02000368, 0x01)
        updateSectionChestCountFromByteAndFlag(segment, "@Corridor Entrance/First Item", 0x02000362, 0x02)
        updateSectionChestCountFromByteAndFlag(segment, "@Corridor Entrance/Merman Pond", 0x02000360, 0x02)
        updateSectionChestCountFromByteAndFlag(segment, "@Reservoir Entrance/Pendant", 0x02000368, 0x04)
        updateSectionChestCountFromByteAndFlag(segment, "@Reservoir Corridor/Tasty Meat", 0x02000370, 0x04)
        updateSectionChestCountFromByteAndFlag(segment, "@Merman Party/Elfin Robe", 0x02000367, 0x08)
        updateSectionChestCountFromByteAndFlag(segment, "@Castle Entrance/Mina's Treasure", 0x02000368, 0x80)
        updateSectionChestCountFromByteAndFlag(segment, "@Entrance Towers Fly/Check It", 0x02000364, 0x02)
        updateSectionChestCountFromByteAndFlag(segment, "@Entrance Towers Climb/Cestus", 0x02000365, 0x40)
        updateSectionChestCountFromByteAndFlag(segment, "@Dance Hall Tower/Spear", 0x02000362, 0x04)
        updateSectionChestCountFromByteAndFlag(segment, "@Dance Hall Main Room/Small Alcove", 0x02000362, 0x20)
        updateSectionChestCountFromByteAndFlag(segment, "@Dance Hall Pit Small Alcove/Small Alcove", 0x0200036C, 0x20)
        updateSectionChestCountFromByteAndFlag(segment, "@Golem Fight Reward/Tsuchinoko Room", 0x02000360, 0x10)
        updateSectionChestCountFromByteAndFlag(segment, "@Minotaur's Secret/Minotaur's Secret", 0x02000367, 0x02)
        updateSectionChestCountFromByteAndFlag(segment, "@Top of Dance Hall Right Side/Cato & Waiter", 0x02000372, 0x08)
        updateSectionChestCountFromByteAndFlag(segment, "@Top of Dance Hall Left Side/Cato & Flea", 0x02000372, 0x04)
        updateSectionChestCountFromByteAndFlag(segment, "@Top of Dance Hall/Mansarde", 0x0200036E, 0x08)
        updateSectionChestCountFromByteAndFlag(segment, "@Dive Kick Room/Dive Kick Room", 0x02000369, 0x04)
        updateSectionChestCountFromByteAndFlag(segment, "@Inner Quarters Entrance/Inner Quarters Entrance", 0x0200036D, 0x04)
        updateSectionChestCountFromByteAndFlag(segment, "@Inner Quarters Student Witch/Student Witch Secret", 0x0200036C, 0x40)
        updateSectionChestCountFromByteAndFlag(segment, "@Inner Quarters Witch/Witch Secret", 0x02000366, 0x10)
        update2ItemLocation(segment, "@Galamoth Locked/Galamoth Locked",  0x02000364, 0x04, 0x02000369, 0x80)
        update2ItemLocation(segment, "@Top of the Quarters/Undine and Hrunting",  0x02000360, 0x40, 0x02000363, 0x04)
        updateSectionChestCountFromByteAndFlag(segment, "@Inner Quarters Lilith Room/Lilith Room", 0x0200036C, 0x02)
        updateSectionChestCountFromByteAndFlag(segment, "@Top Floor Satan's Ring/Satan's Ring", 0x02000368, 0x20)
        updateSectionChestCountFromByteAndFlag(segment, "@Top Floor Secret/Top Floor Secret", 0x02000365, 0x10)
        updateSectionChestCountFromByteAndFlag(segment, "@Top Floor Under Warp/Max Potion", 0x0200036E, 0x01)
        updateSectionChestCountFromByteAndFlag(segment, "@Top Floor Window/Mana Prism", 0x0200036E, 0x20)
        updateSectionChestCountFromByteAndFlag(segment, "@Top Floor Under the Stairs/Under the Stairs", 0x0200036E, 0x10)
        updateSectionChestCountFromByteAndFlag(segment, "@Top Floor Under Under the Stairs/Kaladbolg", 0x02000364, 0x01)
        updateSectionChestCountFromByteAndFlag(segment, "@Top Floor Hyppogriph/Hyppogriph", 0x02000360, 0x20)
        updateSectionChestCountFromByteAndFlag(segment, "@Death Reward/Skula", 0x02000360, 0x80)
        updateSectionChestCountFromByteAndFlag(segment, "@Clock Tower Lightning Doll/MONEY!", 0x02000372, 0x80)
        updateSectionChestCountFromByteAndFlag(segment, "@Clock Tower Secret/Mystletain", 0x02000363, 0x40)
        updateSectionChestCountFromByteAndFlag(segment, "@Clock Tower Pendulum Room/Pendulum Room", 0x02000363, 0x80)
        updateSectionChestCountFromByteAndFlag(segment, "@Clock Tower Trials/Pitch Black Suit", 0x02000366, 0x20)
        updateSectionChestCountFromByteAndFlag(segment, "@Floating Gardens F/Room F", 0x02000373, 0x02)
        updateSectionChestCountFromByteAndFlag(segment, "@Floating Gardens D/Room D", 0x02000373, 0x01)
        updateSectionChestCountFromByteAndFlag(segment, "@Floating Gardens E/Room E", 0x02000373, 0x04)
        updateSectionChestCountFromByteAndFlag(segment, "@Floating Gardens B Left/Room B Left", 0x02000373, 0x08)
        updateSectionChestCountFromByteAndFlag(segment, "@Floating Gardens B Right/Room B Right", 0x02000373, 0x10)
        updateSectionChestCountFromByteAndFlag(segment, "@Floating Gardens Main/Scroll", 0x0200036A, 0x04)
        updateSectionChestCountFromByteAndFlag(segment, "@Long Swim/Flying Armor", 0x02000360, 0x04)
        updateSectionChestCountFromByteAndFlag(segment, "@Long Swim/Flying Armor", 0x02000360, 0x04)
        updateSectionChestCountFromByteAndFlag(segment, "@First Secret Room/Hopefully Something Good", 0x0200036B, 0x80)
        updateSectionChestCountFromByteAndFlag(segment, "@Creaking Reward/Castle Map 1", 0x0200036A, 0x02)
        updateSectionChestCountFromByteAndFlag(segment, "@White Dragon Room/Potion", 0x0200036B, 0x04)
        updateSectionChestCountFromByteAndFlag(segment, "@Under the Inner Quarters/Left", 0x0200036B, 0x10)
        updateSectionChestCountFromByteAndFlag(segment, "@Under the Inner Quarters/Right", 0x02000366, 0x04)
        updateSectionChestCountFromByteAndFlag(segment, "@Fire Armor Early/Accessible Early", 0x0200036B, 0x20)
        updateSectionChestCountFromByteAndFlag(segment, "@Fire Armor Late/Accessible Late", 0x02000367, 0x40)
        updateSectionChestCountFromByteAndFlag(segment, "@Catoblepas Room/Flying Armor Jump <3", 0x02000366, 0x08)
        updateSectionChestCountFromByteAndFlag(segment, "@Scarf Room/Scarf", 0x02000368, 0x10)
        updateSectionChestCountFromByteAndFlag(segment, "@Corridor Outside/Bat Needed", 0x02000364, 0x80)
        updateSectionChestCountFromByteAndFlag(segment, "@Merman Corridor Entrance/Entrance", 0x0200036B, 0x40)
        updateSectionChestCountFromByteAndFlag(segment, "@Merman Corridor Dead End/Dead End", 0x02000373, 0x20)
        updateSectionChestCountFromByteAndFlag(segment, "@Chapel Belfry Lower Left/Lower Left", 0x02000371, 0x20)
        updateSectionChestCountFromByteAndFlag(segment, "@Chapel Belfry Middle Left/Don't Forget It!", 0x02000364, 0x20)
        updateSectionChestCountFromByteAndFlag(segment, "@Chapel Belfry Top Right/Bone Pillar Jump", 0x0200036C, 0x01)
        updateSectionChestCountFromByteAndFlag(segment, "@Chapel Belfry Top Left/Top Left", 0x0200036D, 0x02)
        updateSectionChestCountFromByteAndFlag(segment, "@Chapel Belfry Top Left Long/Top Left Longjump", 0x0200036C, 0x10)
        updateSectionChestCountFromByteAndFlag(segment, "@Chapel Staircase/Little Alcove", 0x02000371, 0x40)
        updateSectionChestCountFromByteAndFlag(segment, "@Right Chapel Belfry/Only One in this Room", 0x02000362, 0x10)
        updateSectionChestCountFromByteAndFlag(segment, "@Manticore Chapel Secret/Skeleton Knight's Secret", 0x02000367, 0x04)
        updateSectionChestCountFromByteAndFlag(segment, "@Manticore Chapel Secret's Secret/Skeleton Knight's Secret's Secret", 0x02000371, 0x10)
        updateSectionChestCountFromByteAndFlag(segment, "@Manticore Chapel/Vanilla Blue Book", 0x02000365, 0x04)
        updateSectionChestCountFromByteAndFlag(segment, "@Study Double Jump Room/Double Jump Room", 0x02000365, 0x02)
        updateSectionChestCountFromByteAndFlag(segment, "@Study Bastard Sword Room/Bastard Sword", 0x02000362, 0x80)
        updateSectionChestCountFromByteAndFlag(segment, "@Study Butcher's Room/Some Healing Item", 0x02000370, 0x10)
        updateSectionChestCountFromByteAndFlag(segment, "@Study Box Puzzle Easy/Push Crate Right", 0x02000368, 0x08)
        updateSectionChestCountFromByteAndFlag(segment, "@Study Box Puzzle Hard/Drop the Crate", 0x02000362, 0x08)
        updateSectionChestCountFromByteAndFlag(segment, "@Study Box Puzzle Hard/Drop the Crate", 0x02000372, 0x01)
        updateSectionChestCountFromByteAndFlag(segment, "@Study Hall/Long Jump", 0x02000372, 0x01)
        updateSectionChestCountFromByteAndFlag(segment, "@Study Secret/Study Secret", 0x02000370, 0x20)
        updateSectionChestCountFromByteAndFlag(segment, "@Study Check/Winged Skeleton Doesn't Work", 0x02000369, 0x40)
        updateSectionChestCountFromByteAndFlag(segment, "@Study Above Backdash Room/Some Stuff", 0x02000372, 0x02)
        updateSectionChestCountFromByteAndFlag(segment, "@Study Backdash Room/Definitely Sequence Break It", 0x02000362, 0x40)
        updateSectionChestCountFromByteAndFlag(segment, "@Hammer Room/Malphas", 0x02000360, 0x08)
        updateSectionChestCountFromByteAndFlag(segment, "@Dancers Chapel Long Jump/Long Jump", 0x02000371, 0x80)
        updateSectionChestCountFromByteAndFlag(segment, "@Dancers Chapel/Une Room", 0x02000370, 0x08)
        updateSectionChestCountFromByteAndFlag(segment, "@Underground Reservoir Rahab's Sword/Rahab's Sword", 0x02000363, 0x08)
        updateSectionChestCountFromByteAndFlag(segment, "@Underground Reservoir Potion/Potion", 0x0200036D, 0x80)
        updateSectionChestCountFromByteAndFlag(segment, "@Underground Reservoir Milican Sword/Milican Sword", 0x02000363, 0x02)
        updateSectionChestCountFromByteAndFlag(segment, "@Underground Reservoir Above Waterfall/Above Waterfall", 0x02000372, 0x10)
        updateSectionChestCountFromByteAndFlag(segment, "@Underground Reservoir Handgun/Handgun", 0x02000366, 0x01)
        updateSectionChestCountFromByteAndFlag(segment, "@Underground Reservoir Yellow Book/Vanilla Yellow Book", 0x0200036A, 0x01)
        updateSectionChestCountFromByteAndFlag(segment, "@Underground Reservoir Air Bubble/Air Bubble", 0x02000372, 0x20)
        updateSectionChestCountFromByteAndFlag(segment, "@Underground Reservoir Tonic/Tonic", 0x0200036E, 0x02)
        updateSectionChestCountFromByteAndFlag(segment, "@Underground Reservoir Rare Ring/Rare Ring", 0x02000369, 0x02)
        updateSectionChestCountFromByteAndFlag(segment, "@Underground Reservoir Osafune/Osafune", 0x02000364, 0x40)
        updateSectionChestCountFromByteAndFlag(segment, "@Underground Reservoir Waterfall Top Left/Waterfall Top Left", 0x02000365, 0x20)
        updateSectionChestCountFromByteAndFlag(segment, "@Underground Reservoir Flesh Golem Room/Flesh Golem Room", 0x0200036D, 0x40)
        updateSectionChestCountFromByteAndFlag(segment, "@Behind Waterfall/Eversing", 0x02000367, 0x01)
        updateSectionChestCountFromByteAndFlag(segment, "@Forbidden Area Secret/Claimh Solais", 0x02000364, 0x08)
        updateSectionChestCountFromByteAndFlag(segment, "@The Most Enclosed Area/Joyeuse", 0x02000364, 0x10)
        updateSectionChestCountFromByteAndFlag(segment, "@Underground Reservoir Armor of Water/Armor of Water", 0x02000367, 0x20)
        updateSectionChestCountFromByteAndFlag(segment, "@Underground Reservoir Slide/Slide", 0x0200036E, 0x40)
        updateSectionChestCountFromByteAndFlag(segment, "@Underground Reservoir Cemetery Entrance/Cemetery Entrance", 0x02000370, 0x40)
        updateSectionChestCountFromByteAndFlag(segment, "@Underground Cemetery Werejaguar Room/Werejaguar Room", 0x02000372, 0x40)
        updateSectionChestCountFromByteAndFlag(segment, "@Underground Cemetery Backstab Fest/Backstab Fest", 0x02000361, 0x02)
        updateSectionChestCountFromByteAndFlag(segment, "@Underground Cemetery Cagnazzo Room/Cagnazzo Room", 0x02000369, 0x08)
        updateSectionChestCountFromByteAndFlag(segment, "@Underground Cemetery Legion Loot/Legion Loot", 0x0200036D, 0x01)
        updateSectionChestCountFromByteAndFlag(segment, "@Underground Reservoir Lots of Needles/Lots of Needles", 0x0200036D, 0x08)
        updateSectionChestCountFromByteAndFlag(segment, "@Red Minotaur Room/Laevatein", 0x02000363, 0x20)
        updateSectionChestCountFromByteAndFlag(segment, "@Trapped Room/Top Right Corner", 0x0200036C, 0x80)
        updateSectionChestCountFromByteAndFlag(segment, "@Fountain/Black Cloak", 0x02000368, 0x02)
        updateSectionChestCountFromByteAndFlag(segment, "@Lubicante Room/I CAME IN LIKE A WRECKING BAAAALL!!", 0x02000366, 0x40)
        updateSectionChestCountFromByteAndFlag(segment, "@Worst Room in the Game/Golden Medusa Room", 0x02000363, 0x01)
        updateSectionChestCountFromByteAndFlag(segment, "@DDR Room/Show Me Your Moves", 0x02000369, 0x01)
        updateSectionChestCountFromByteAndFlag(segment, "@Balore's Cave/Giant Bat Soul", 0x02000361, 0x01)
        update2ItemLocation(segment, "@Graham Reward/Almost Certainly Junk",  0x02000361, 0x04,  0x02000366, 0x80)
        updateSectionChestCountFromByteAndFlag(segment, "@You are in GO MODE/This can be Skula", 0x0200036E, 0x80)
        updateSectionChestCountFromByteAndFlag(segment, "@Why are you stopping?/This is not Claimh", 0x0200036E, 0x04)
        updateSectionChestCountFromByteAndFlag(segment, "@Why are you stopping??/This is still not Claimh", 0x0200036D, 0x10)
        
        updateMoneyCandleLocation(segment)

    end
end

ScriptHost:AddMemoryWatch("AoS Key Item Data", 0x02013354, 0x42, updateItemsFromMemorySegment)
ScriptHost:AddMemoryWatch("AoS Item Location Data Corridor", 0x02000360, 0x20, updateChestsFromMemorySegmentCorridor)
ScriptHost:AddMemoryWatch("AoS Book Data", 0x020132AE, 0x03, updateBooksFromMemorySegment)
ScriptHost:AddMemoryWatch("AoS Graham Killed", 0x02000343, 0x01, updateGrahamFromMemorySegment)
ScriptHost:AddMemoryWatch("AoS Candle Map Locations", 0x0200013C, 0x42, updateMoneyCandleLocationsPossibleFromSegment)