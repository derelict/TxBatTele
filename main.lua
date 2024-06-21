-- License https://www.gnu.org/licenses/gpl-3.0.en.html
-- OpenTX/EdgeTX Lua script
-- TELEMETRY

-- File Locations On The Transmitter's SD Card
--  This script file  /SCRIPTS/WIDGETS/
--  Sound files       /SCRIPTS/WIDGETS/TxBatTele/sounds/

-- Works On OpenTX Companion Version: 2.2
-- Works With Sensor: FrSky FAS40S, FCS-150A, FAS100, FLVS Voltage Sensors
--
-- Author: RCdiy
-- Web: http://RCdiy.ca
-- Date: 2016 June 28
-- Update: 2017 March 27
-- Update: 2019 November 21 by daveEccleston (Handles sensors returning a table of cell voltages)
-- Update: 2022 July 15 by David Morrison (Converted to OpenTX Widget for Horus and TX16S radios)
--
-- Reauthored: Dean Church
-- Date: 2017 March 25
-- Thanks: TrueBuild (ideas)
--
-- Re-Reauthored: David Morrison
-- Date: 2022 December 1
--
-- Changes/Additions:
-- 	Choose between using consumption sensor or voltage sensor to calculate
--		battery capacity remaining.
--	Choose between simple and detailed display.
--  Voice announcements of percentage remaining during active use.
--  After reset, warn if battery is not fully charged
--  After reset, check cells to verify that they are within VoltageDelta of each other


-- Description
-- 	Reads an OpenTX global variable to determine battery capacity in mAh
--		The sensors used are configurable
-- 	Reads an battery consumption sensor and/or a voltage sensor to
--		estimate mAh and % battery capacity remaining
--		A consumption sensor is a calculated sensor based on a current
--			sensor and the time elapsed.
--			http://rcdiy.ca/calculated-sensor-consumption/
-- 	Displays remaining battery mAh and percent based on mAh used
-- 	Displays battery voltage and remaining percent based on volts
--  Displays details such as minimum voltage, maximum current, mAh used, # of cells
-- 	Write remaining battery mAh to a Tx global variable
-- 	Write remaining battery percent to a Tx global variable
-- 		Writes are optional, off by default
--	Announces percentage remaining every 10% change
--		Announcements are optional, on by default
-- Reserve Percentage
-- 	All values are calculated with reference to this reserve.
--	% Remaining = Estimated % Remaining - Reserve %
--	mAh Remaining = Calculated mAh Remaining - (Size mAh x Reserve %)
--	The reserve is configurable, 20% is the set default
-- 	The following is an example of what is displayed at start up
-- 		800mAh remaining for a 1000mAh battery
--		80% remaining
--
--
-- 	Notes & Suggestions
-- 		The OpenTX global variables (GV) have a 1024 limit.
-- 		mAh values are stored in them as mAh/100
-- 		2800 mAh will be 28
-- 		800 mAh will be 8
--
-- 	 The GVs are global to that model, not between models.
-- 	 Standardize across your models which GV will be used for battery
-- 		capacity. For each model you can set different battery capacities.
-- 	  E.g. If you use GV7 for battery capacity/size then
--					Cargo Plane GV7 = 27
--					Quad 250 has GV7 = 13
--
--	Use Special Functions and Switches to choose between different battery
--		capacities for the same model.
--	E.g.
--		SF1 SA-Up Adjust GV7 Value 10 ON
--		SF2 SA-Mid Adjust GV7 Value 20 ON
--	To play your own announcements replace the sound files provided or
--		turn off sounds
-- 	Use Logical Switches (L) and Special Functions (SF) to play your own sound tracks
-- 		E.g.
-- 			L11 - GV9 < 50
-- 			SF4 - L11 Play Value GV9 30s
-- 			SF5 - L11 Play Track #PrcntRm 30s
-- 				After the remaining battery capicity drops below 50% the percentage
-- 				remaining will be announced every 30 seconds.
-- 	L12 - GV9 < 10
-- 	SF3 - L12 Play Track batcrit
-- 				After the remaining battery capicity drops below 50% a battery
-- 				critical announcement will be made every 10 seconds.

------------------------------------------------------------------------------------------------------------
-- todo
------------------------------------------------------------------------------------------------------------
-- turn on off logging using switch (arm disarm)
-- take a screenshot prior to reset (after first flight .. not on init)
-- say that a reset has occured but not on init
-- haptic feedback for warn and critical
-- process to generate new voice wavs with stock and custom (csv)
-- make a table to define all sensors and values per modelname, use defaults if missing
-- allow bat capacity to be choosen using a switch from a table that matches the model (modeltable)
-- compare detected cells vs. expected (modeltable)... Critical if not matching ... battery NOT full !!
-- make battery capacities selectable using switch(es) or 6 mode buttons
------------------------------------------------------------------------------------------------------------

local Title = "Flight Telemetry and Battery Monitor"

local DEBUG_ENABLED = true

--local invalidSensorList = {}

-- Sensors
-- 	Use Voltage and or mAh consumed calculated sensor based on VFAS, FrSky FAS-40
-- 	Use sensor names from OpenTX TELEMETRY screen
--  If you need help setting up a consumption sensor visit
--		http://rcdiy.ca/calculated-sensor-consumption/

-- https://ttsmaker.com/
-- https://online-audio-converter.com/de/

-- Change as desired

local verbosity = 3 --todo verbosity levels


idstatusTele = getSwitchIndex("TELE")


local SwitchAnnounceTable = {
  {"sf","armed","disarm"},
  {"sh","safeon"},
  {"se","fm-nrm","fm-1","fm-2"}
}

local line1statsensors = {
  {"RPM" ,"RPM","clh"},
  {"RSSI","RSSI","hl"},
  {"Tmp1","TMP1","c"}
}

local line2statsensors = {
  {"Curr","CUR","lh"},
  {"Fuel","FUL","clh"},
  {"Tmp2","TMP2","h"}
}

line1 = "RPM [ H: #RPM+# L: #RPM-# ]" --another way to do it -- todo
--local line1statsensors = {
--  {"RPM", "RPM", "clh", {"white", "green", "red"}},
--  {"RSSI", "RSSI", "hl", {"red", "green"}},
--  {"Tmp1", "TMP1", "c", {"white"}}
--}
--
--local line2statsensors = {
--  {"Curr", "CUR", "lh", {"green", "red"}},
--  {"Fuel", "FUL", "clh", {"white", "green", "red"}},
--  {"Tmp2", "TMP2", "h", {"red"}}
--}


local BattPackSelectorSwitch = {
  main = {
    { switchName = '6POS1', value = 1 },
    { switchName = '6POS2', value = 2 },
    { switchName = '6POS3', value = 3 },
    { switchName = '6POS4', value = 4 },
    { switchName = '6POS5', value = 5 },
    { switchName = '6POS6', value = 6 }
  },
  receiver = {
    { switchName = '6POS1', value = 1 },
    { switchName = '6POS2', value = 2 },
    { switchName = '6POS3', value = 3 },
    { switchName = '6POS4', value = 4 },
    { switchName = '6POS5', value = 5 },
    { switchName = '6POS6', value = 6 }
  }
}


local defaultAdlSensors = {
  {
      name = "RPM",
      unit = "",
      sensors = {
          { sensorName = "RPM+", prefix = "H:", color = GREEN  },
          { sensorName = "RPM-", prefix = "L:", color = RED    }
      }
  },
  {
    name = "RPM",
    unit = "",
    sensors = {
        { sensorName = "RPM+", prefix = "H:", color = GREEN  },
        { sensorName = "RPM-", prefix = "L:", color = RED    }
    }
},
{
  name = "RPM",
  unit = "",
  sensors = {
      { sensorName = "RPM+", prefix = "H:", color = GREEN  },
      { sensorName = "RPM-", prefix = "L:", color = RED    }
  }
},  
{
  name = "RPM",
  unit = "",
  sensors = {
      { sensorName = "RPM+", prefix = "H:", color = GREEN  },
      { sensorName = "RPM-", prefix = "L:", color = RED    }
  }
},
{
  name = "CEL",
  unit = "",
  sensors = {
      { sensorName = "Cels+", prefix = "H:", color = GREEN  },
      { sensorName = "Cels-", prefix = "L:", color = RED    }
  }
},
  {
      name = "RxBT",
      unit = "V",
      sensors = {
          { sensorName = "RxBt+", prefix = "H:", color = GREEN  },
          { sensorName = "RxBt-", prefix = "L:", color = RED    }
      }
  }
}




-- Based on results from http://rcdiy.ca/taranis-q-x7-battery-run-time/
-- https://blog.ampow.com/lipo-voltage-chart/

-- BatteryDefinition
-- todo only announce in steps of N
local Batteries = {
  lipo = {  -- normal lipo Battery
      dischargeCurve           = {
          {4.20, 100}, {4.17, 97.5}, {4.15, 95}, {4.13, 92.5},
          {4.11, 90}, {4.10, 87.5}, {4.08, 85}, {4.05, 82.5},
          {4.02, 80}, {4.00, 77.5}, {3.98, 75}, {3.97, 72.5},
          {3.95, 70}, {3.93, 67.5}, {3.91, 65}, {3.89, 62.5},
          {3.87, 60}, {3.86, 57.5}, {3.85, 55}, {3.85, 52.5},
          {3.84, 50}, {3.83, 47.5}, {3.82, 45}, {3.81, 42.5},
          {3.80, 40}, {3.80, 37.5}, {3.79, 35}, {3.78, 32.5},
          {3.77, 30}, {3.76, 27.5}, {3.75, 25}, {3.74, 22.5},
          {3.73, 20}, {3.72, 17.5}, {3.71, 15}, {3.70, 12.5},
          {3.69, 10}, {3.67, 7.5}, {3.61, 5}, {3.49, 2.5},
          {3.27, 0}
      },
      displayName                 = "LiPo",
      graceperiod                 = 4,      -- grace period for fluctuations 
      criticalThreshold           = 15,     -- Critical threshold in percentage
      warningThreshold            = 20,     -- Warning threshold in percentage
      notFullCriticalThreshold    = 96,     -- Not full critical threshold in percentage
      notFullWarningThreshold     = 98,     -- Not full warning threshold in percentage
      announceNotFullCriticalMode = "change", -- change, disable or integer intervall
      announceNotFullWarningMode  = "change", -- change, disable or integer intervall
      announceNormalMode          = 20, -- change, disable or integer intervall
      announceWarningMode         = "change", -- change, disable or integer intervall
      announceCriticalMode        = "change", -- change, disable or integer intervall
      highVoltage                 = 4.20,   -- High voltage
      lowVoltage                  = 3.27,   -- Low voltage
      cellDeltaVoltage            = 0.1,    -- Cell delta voltage
      isNotABattery               = false   -- DO NOT CHANGE for any Battery !!!
  },

  buffer = {  -- Buffer Pack (condensator)
      dischargeCurve              = nil,    -- This will be dynamically calculated based on voltage range
      displayName                 = "Buffer Pack",
      graceperiod                 = 4,      -- grace period for fluctuations 
      criticalThreshold           = 96,     -- Critical threshold in percentage
      warningThreshold            = 97,     -- Warning threshold in percentage
      notFullCriticalThreshold    = 98,     -- Not full critical threshold in percentage
      notFullWarningThreshold     = 99,     -- Not full warning threshold in percentage
      announceNotFullCriticalMode = "change", -- change, disable or integer intervall
      announceNotFullWarningMode  = "change", -- change, disable or integer intervall
      announceNormalMode          = 20, -- change, disable or integer intervall
      announceWarningMode         = "change", -- change, disable or integer intervall
      announceCriticalMode        = "change", -- change, disable or integer intervall      highVoltage              = nil,    -- High voltage -- will be set to rxReferenceVoltage from the model once it's loaded ... you can override it here ... but it's better to "calculate"/set it to the rxReferenceVoltage -- todo
      highVoltage                 = nil,   -- if nil will use model rxReferenceVoltage
      lowVoltage                  = 6,      -- Low voltage -- where your buffer pack shuts off completely ... all hope is lost after this ;-) .. please note... in the case of buffer packs ... we will device this value by 2 in order to get a theoretical 2s per cell value for the alerts and percentage left -- todo
      cellDeltaVoltage            = nil,     -- Cell delta voltage -- irrelevant for buffer or bec
      isNotABattery               = true   -- buffer is not a battery and values for high and low voltage represent real voltages and will be devided by 2 by the script to get a theoretical cell value
    },

  beconly = {  -- BEC only Definition
      dischargeCurve              = nil,    -- This will be dynamically calculated based on voltage range
      displayName                 = "BEC only",
      graceperiod                 = 4,      -- grace period for fluctuations 
      criticalThreshold           = 96,     -- Critical threshold in percentage
      warningThreshold            = 97,     -- Warning threshold in percentage
      notFullCriticalThreshold    = 98,     -- Not full critical threshold in percentage
      notFullWarningThreshold     = 99,     -- Not full warning threshold in percentage
      announceNotFullCriticalMode = "change", -- change, disable or integer intervall
      announceNotFullWarningMode  = "change", -- change, disable or integer intervall
      announceNormalMode          = 20, -- change, disable or integer intervall
      announceWarningMode         = "change", -- change, disable or integer intervall
      announceCriticalMode        = "change", -- change, disable or integer intervall      highVoltage              = nil,    -- High voltage -- will be set to rxReferenceVoltage from the model once it's loaded ... you can override it here ... but it's better to "calculate"/set it to the rxReferenceVoltage -- todo
      highVoltage                 = nil,   -- if nil will use model rxReferenceVoltage
      lowVoltage                  = 5,      -- Low voltage -- there is not such a thing as "lowvoltage" if only using a bec ... if you loose your bec you will recognize it before we can announce anything ... so lets set this to anything below what is "normal" ... like 5
      cellDeltaVoltage            = nil,     -- Cell delta voltage -- irrelevant for buffer or bec
      isNotABattery               = true   -- BEC is not a battery and values for high and low voltage represent real voltages and will be devided by 2 by the script to get a theoretical cell value
    },
  }



local modelTable = {
  {
      modelNameMatch         = "DEFAULT",
      modelName              = "DEFAULT",
      modelImage             = "goblin.png",
      modelWav               = "sg630",
      rxReferenceVoltage     = 8.2,
      resetSwitch            = "TELE",
      VoltageSensor          = {
        main =      { sensorName = "Cels"  },
        receiver =  { sensorName = "RxBt"  }
        },
      CurrentSensor          = {
        main =      { sensorName = "Curr"  },
        receiver =  { sensorName = "Curr"  }
        },
      MahSensor              = {
        main =      { sensorName = "mah"  },
        receiver =  { sensorName = "mah"  }
        },
      AdlSensors             = defaultAdlSensors,
      battery               = { main = Batteries.lipo ,    receiver = Batteries.buffer },
      CellCount              = { main = 12,        receiver = 2 },
      capacities             = { main = { 500, 1000, 1500, 2000, 2500, 3000 }, receiver = { 500, 1000, 1500, 2000, 2500, 3000 } },
      switchAnnounces        = SwitchAnnounceTable,
      BattPackSelectorSwitch = BattPackSelectorSwitch
  },
  {
      modelNameMatch         = "heli",
      modelName              = "SAB Goblin 630",
      modelImage             = "goblin.png",
      modelWav               = "sg630",
      rxReferenceVoltage     = 8.2,
      resetSwitch            = "TELE",
      VoltageSensor          = {
        main =      { sensorName = "Cels"  },
        receiver =  { sensorName = "RxBt"  }
        },
      CurrentSensor          = {
        main =      { sensorName = "Curr"  },
        receiver =  { sensorName = "Curr"  }
        },
      MahSensor              = {
        main =      { sensorName = "mah"  },
        receiver =  { sensorName = "mah"  }
        },
      AdlSensors             = defaultAdlSensors,
      battery               = { main = Batteries.lipo ,    receiver = Batteries.buffer },
      CellCount              = { main = 8,         receiver = 2 },
      capacities             = { main = { 500, 1000, 1500, 2000, 2500, 3000 }, receiver = { 500, 1000, 1500, 2000, 2500, 3000 } },
      switchAnnounces        = SwitchAnnounceTable,
      BattPackSelectorSwitch = BattPackSelectorSwitch
  }
}


local modelAlreadyLoaded = false

local priorizeSwitchAnnouncements = true


local ShowPostFlightSummary = true --todo
local ShowPreFlightStatus = true -- todo
local ActiveFlightIndicator = "choose switch" -- todo ... use arm switch or maybe there is a good tele sensor for this

local statusTable = {}

-- to support future functions like taking screenshot and logging on/off
local ver, radio, maj, minor, rev, osname = getVersion()
if DEBUG_ENABLED then

print("version: "..ver)
if radio then print ("version radio: "..radio) end
if maj then print ("version maj: "..maj) end
if minor then print ("version minor: "..minor) end
if rev then print ("version rev: "..rev) end
if osname then print ("version osname: "..osname) end
end

local AutomaticResetOnResetSwitchToggle = 4 -- 5 seconds for TELE Trigger .... maybe 1 second for switch trigger

local AutomaticResetOnNextChange = true

local TriggerTimers = {}


local announcementConfig = {
  -- Telemetry configuration
  telemetry = {
      normal   = { mode = "disable",           gracePeriod = 1 }, -- Mode to disable telemetry in normal state
      warning  = { mode = 10,            threshold = false }, -- Mode to change telemetry in warning state
      critical = { mode = "disable",           threshold = "undef" }  -- Mode to disable telemetry in critical state
  },

  -- Battery Missing Cell configuration
  BatteryMissingCell = {
      normal   = { mode = "disable",           gracePeriod = 1 }, -- Mode to disable in normal state
      warning  = { mode = 10,                  threshold = -1 },   -- Mode to change in warning state after threshold
      critical = { mode = 10,                  threshold = -2 }    -- Mode to change in critical state after threshold
  },

  -- Cell Delta configuration
  CellDelta = {
      normal   = { mode = "disable",           gracePeriod = 3 }, -- Mode to disable in normal state
      warning  = { mode = 10,                  threshold = "undef" }, -- Mode to change in warning state after threshold
      critical = { mode = 10,                  threshold = true }   -- Mode to change in critical state after threshold
  }

}


local announcementConfigDefault = {
  normal = {
    mode = "change", -- "disable", "change", or an interval in seconds
    gracePeriod = 4 -- Default grace period in seconds
  },
  warning = {
    threshold = 80, -- Default threshold for warning level
    mode = "change" -- "disable", "change", or an interval in seconds
  },
  critical = {
    threshold = 50, -- Default threshold for critical level
    mode = "change" -- "disable", "change", or an interval in seconds
}
}



--   local unitNames = {
--     [0] = "",                        -- Raw unit (no unit)
--     [1] = "V",                       -- Volts
--     [2] = "A",                       -- Amps
--     [3] = "mA",                      -- Milliamps
--     [4] = "kts",                     -- Knots
--     [5] = "m/s",                     -- Meters per Second
--     [6] = "ft/s",                    -- Feet per Second
--     [7] = "km/h",                    -- Kilometers per Hour
--     [8] = "mph",                     -- Miles per Hour
--     [9] = "m",                       -- Meters
--     [10] = "ft",                     -- Feet
--     [11] = "°C",                     -- Degrees Celsius
--     [12] = "°F",                     -- Degrees Fahrenheit
--     [13] = "%",                      -- Percent
--     [14] = "mAh",                    -- Milliamp Hour
--     [15] = "W",                      -- Watts
--     [16] = "mW",                     -- Milliwatts
--     [17] = "dB",                     -- dB
--     [18] = "rpm",                    -- RPM
--     [19] = "G",                      -- G
--     [20] = "°",                      -- Degrees
--     [21] = "rad",                    -- Radians
--     [22] = "ml",                     -- Milliliters
--     [23] = "floz",                   -- Fluid Ounces
--     [24] = "ml/min",                 -- Ml per minute
--     [35] = "h",                      -- Hours
--     [36] = "min",                    -- Minutes
--     [37] = "s",                      -- Seconds
--     [38] = "V",                      -- Virtual unit for Cells
-- 
-- }

-- todo -- really needed ?
local CapacityReservePercent = 0 -- set to zero to disable

local soundDirPath = "/WIDGETS/TxBatTele/sounds/" -- where you put the sound files

-- todo

-- Do not change the next line
local GV = {[1] = 0, [2] = 1, [3] = 2,[4] = 3,[5] = 4,[6] = 5, [7] = 6, [8] = 7, [9] = 8}

local WriteGVBatRemmAh = true -- set to false to turn off write
local WriteGVBatRemPer = true
-- If writes are false then the corresponding GV below will not be used and these
--	lines can be ignored.
local GVBatRemmAh = GV[8] -- Write remaining mAh, 2345 mAh will be writen as 23, floor(2345/100)
local GVBatRemPer = GV[9] -- Write remaining percentage, 76.7% will be writen as 76, floor(76)

-- If you have set either write to false you may set the corresponding
--	variable to ""
-- example local GVBatRemmAh = ""

-- ----------------------------------------------------------------------------------------
-- ----------------------------------------------------------------------------------------
-- AVOID EDITING BELOW HERE
--

local CanCallInitFuncAgain = false		-- updated in bg_func

local VoltageHistory = {}   -- updated in bg_func

-- Display
local x, y, fontSize, yColumn2
local xAlign = 0

local BlinkWhenZero = 0 -- updated in run_func
local Color = BLUE
local BGColor = BLACK



-- ########################## TESTING ##########################

function round(num, numDecimalPlaces) -- todo --- quick work arround ---- remove
  local mult = 10 ^ (numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end


local soundQueue = {}
local currentState = "idle"
local waitUntil = 0

local function debugPrint(message)
  if DEBUG_ENABLED then
      print(message)
  end
end

function setDebug(enabled)
  DEBUG_ENABLED = enabled
end

-- Function to add sound files to the queue
local function queueSound(file, duration, priority)

  priority = priority or false
  local position = priority and 1 or #soundQueue + 1

  debugPrint("PQ: insert: ", file)
  table.insert(soundQueue, position, {type = "file", value = soundDirPath..file, duration = duration})
end

local function queueSysSound(file, duration, priority)

  priority = priority or false
  local position = priority and 1 or #soundQueue + 1

  debugPrint(string.format("PQ: insert: %s pos: %s", file, position))
  table.insert(soundQueue, position, {type = "file", value = file, duration = duration})
end

-- Function to add numbers to the queue
local function queueNumber(number, unit, precision, duration)
  table.insert(soundQueue, {type = "number", value = number, unit = unit, precision = precision, duration = duration})
end

local function processQueue()

  local now = getTime()

  if currentState == "idle" and #soundQueue > 0 then
      local item = soundQueue[1]
      
      table.remove(soundQueue, 1)  -- Remove the processed item from the queue

      if item.type == "file" then
          playFile(item.value..".wav")
      elseif item.type == "number" then
          playNumber(item.value, item.unit, item.precision, 5)
      end


      debugPrint(string.format("PQ: Playing: %s Waiting: %s ... ", item.value, item.duration ))
      
      waitUntil = now + item.duration * 100  -- Convert duration from seconds to centiseconds
      currentState = "waiting"


  elseif currentState == "waiting" then
      
    if now >= waitUntil then
          -- table.remove(soundQueue, 1)  -- Remove the processed item from the queue
          currentState = "idle"
          debugPrint("PQ: Idle" )

    end

  end

  return 0  -- Keep the script running
end





local function print_table_structure(tbl)
  for i, v in ipairs(tbl) do
    debugPrint("TBLS: " .. i .. ": " .. v[1] .. ", " .. v[2])
  end
end

-- Function to simulate retrieving sensor values
local function get_sensor_values(sensor)

  local current_value = getValue(sensor)
  local lowest_value  = getValue(sensor .. "-")
  local highest_value = getValue(sensor .. "+")

  return current_value, lowest_value, highest_value

end

local function format_number(number)
  -- Check if the number has decimals
  if math.floor(number) == number then
      return tostring(number)  -- Return the number as-is if it's an integer
  else
      return string.format("%.2f", number)  -- Format to two decimal places if it's a float
  end
end

-- Function to build the formatted string
local function build_sensor_line(sensorinput)
  local result = {}

  for _, sens in ipairs(sensorinput) do
    local sensor_name = sens[2]
    local value_spec = sens[3]
    local sensor = sens[1]

    local current_value, lowest_value, highest_value = get_sensor_values(sensor)

    local sensor_line = sensor_name .. " ["

    -- Ensure correct order of output as per value_spec
    for i = 1, #value_spec do
      local spec = string.sub(value_spec, i, i)

      if spec == "c" then
        sensor_line = sensor_line .. "C: " .. format_number(current_value)
      elseif spec == "l" then
        sensor_line = sensor_line .. "L: " .. format_number(lowest_value)
      elseif spec == "h" then
        sensor_line = sensor_line .. "H: " .. format_number(highest_value)
      end

      -- Add space if there are more specs to follow
      if i < #value_spec then
        sensor_line = sensor_line .. " "
      end
    end

    sensor_line = sensor_line .. "]"

    table.insert(result, sensor_line)
  end
  
  return table.concat(result, " / ")
end
   


-- string.format("%.2f", number)
-- string.format("%.2f", number)
-- string.format("%.2f", number)


-- local sensor      = sens[1]  



-- Helper function to calculate linear discharge curve
-- BatteryTypeDefaults.buffer.dischargeCurve = calculateLinearDischargeCurve(low, high)

local function calculateLinearDischargeCurve(lowVoltage, highVoltage)
  local numberOfPoints = 41  -- Adjust as needed
  local curve = {}
  local step = (highVoltage - lowVoltage) / (numberOfPoints - 1)

  for i = 0, numberOfPoints - 1 do
      local voltage = highVoltage - (i * step)
      local percent = (i / (numberOfPoints - 1)) * 100
      table.insert(curve, {voltage, 100 - percent})
  end

  return curve
end



-- ########################## TESTING ##########################

local function printHumanReadableTable(tbl, indent)
  indent = indent or 0
  local function indentStr(level)
      return string.rep("  ", level)
  end

  for key, value in pairs(tbl) do
      local keyStr = tostring(key)
      local valueStr = tostring(value)

      if type(value) == "table" then
          debugPrint(indentStr(indent) .. "TBLDBG: " .. keyStr .. " = {")
          printHumanReadableTable(value, indent + 1)
          debugPrint(indentStr(indent) .. "TBLDBG: }")
      else
          debugPrint(indentStr(indent) .. "TBLDBG: " .. keyStr .. " = " .. valueStr)
      end
  end
end



-- Simplified wildcard matching function
local function matchModelName(mname, pattern)

  lmname = string.lower(mname)
  lpattern = string.lower(pattern)

  debugPrint("TEST modelName:", mname, "type:", type(mname))
  debugPrint("TEST pattern:", pattern, "type:", type(pattern))

 
  -- Check if the pattern is a substring of the currentModelName
  return string.find(lmname, lpattern) ~= nil


end

-- Function to get model details based on current model name
local function getModelDetails(name)
  local defaultDetails
  for _, model in ipairs(modelTable) do
    if model.modelNameMatch == "DEFAULT" then
      defaultDetails = model
    elseif matchModelName(name, model.modelNameMatch) then
      return model
    end
  end
  -- Return default values if no match is found
  return defaultDetails
end

-- ####################################################################
local function getCellVoltage( cellResult  ) 
  -- For voltage sensors that return a table of sensors, add up the cell 
  -- voltages to get a total cell voltage.
  -- Otherwise, just return the value
  -- cellResult = getValue( voltageSensorIn )
  cellSum = 0

  if (type(cellResult) == "table") then
    for i, v in ipairs(cellResult) do
      cellSum = cellSum + v

      debugPrint(string.format("getcellvoltage: cell: %s volts: %s", i, cellSum))


      -- update the historical voltage table
      if (VoltageHistory[i] and VoltageHistory[i] > v) or VoltageHistory[i] == nil then
        VoltageHistory[i] = v
      end

    end
  else 
    cellSum = cellResult
  end

  debugPrint(string.format("getcellvoltage: cellsum: %s", cellSum))

  -- if prevVolt < 1 or cellSum > 1 then
     return cellSum
  -- else
  --   return prevVolt
  -- end

  --return cellSum
end

local function getAmp(sensor)
  if sensor ~= "" then
    --amps = getValue( sensor.id )
    amps = sensor
    if type(amps) == "number" then
      --if type(MaxAmps) == "string" or (type(MaxAmps) == "number" and amps > MaxAmps) then
      --  MaxAmps = amps
      --end
      --watts = amps * voltsNow
      --if type(MaxWatts) == "string" or watts > MaxWatts then
      --  MaxWatts = watts
      --end
      --return amps

      -- debugPrint(string.format("AMPS: P: %s C: %s", prevAmp, amps))

      --if prevAmp < 0.0001 or amps > 0.0001 then
        return amps
      --else
      --  return prevAmp
      --end


    else
      return 0
    end
  end
end


-- ####################################################################

local function findPercentRem( cellVoltage, context )

  debugPrint("findPercentRem Cell Voltage: ", cellVoltage)
  debugPrint("findPercentRem context: ", context)

  --local low = batTypeLowHighValues[battype][1]
  --local high = batTypeLowHighValues[battype][2]

  -- local low = BatteryDefinition[battype] .lowVoltage
  -- local high = BatteryDefinition[battype].highVoltage

  --local low  = thisModel.battery[context].lowVoltage
  --local high = thisModel.battery[context].highVoltage


  --local discharcurve = BatteryTypeDischargeCurves[battype]
  -- local discharcurve = BatteryDefinition[battype].dischargeCurve
  --local discharcurve = thisModel.battery[context].dischargeCurve

  if cellVoltage > thisModel.battery[context].highVoltage then
    return 100
  elseif	cellVoltage < thisModel.battery[context].lowVoltage then
    return 0
  else
    -- method of finding percent in my array provided by on4mh (Mike)
    for i, v in ipairs( thisModel.battery[context].dischargeCurve ) do
      debugPrint(string.format("findPercentRem Check Voltage: %s ", v[ 1 ]))
      if cellVoltage >= v[ 1 ] then
        return v[ 2 ]
      end
    end
  end
end

-- ####################################################################
local function Timer(name, time )

  if name == nil then
    return
  end

  if time == nil or TriggerTimers[name] == nil or TriggerTimers[name] == 0 then -- start the timer
    TriggerTimers[name] = getTime()
    return false -- todo true or false here ??
end

  local curtime = getTime()
  local deltatime = curtime - TriggerTimers[name]
  local deltaseconds = deltatime/100

  debugPrint(string.format("TIMER DEBUG: delta: %s time: %s name: %s", deltaseconds, time , name))

  if deltaseconds > time then
    --if noreset ~= nil then
    TriggerTimers[name] = 0 --reset timer
    --end
    return true
  else
    return false
  end

end

-- ####################################################################
-- ####################################################################
-- ####################################################################

local function checkChangedInterval(currentStatus, item, context )
  -- Get the configuration for the item or use announcementConfigDefault
  --local config = announcementConfig[item] or announcementConfigDefault

  --returnStateOnly = returnStateOnly or false

  -- BatteryDefinition for BatteryNotFull and Battery

  -- Determine if the item has context-specific configurations

  local config, critTH, warnTH, critMD, warnMD, normMD, graceP

  if item ~= "Battery" and item ~= "BatteryNotFull" then
    

  local config = announcementConfig[item]

   if not config then
    -- Use the default configuration if item-specific configuration is not found
    config = announcementConfigDefault
  end

  -- if config then
  --   if context and config[context] then
  --     -- Use the context-specific configuration if available
  --     config = config[context]
  --   end
  -- else
  --   -- Use the default configuration if item-specific configuration is not found
  --   config = announcementConfigDefault
  -- end

  critTH = config.critical.threshold
  warnTH = config.warning.threshold
  critMD = config.critical.mode
  warnMD = config.warning.mode
  normMD = config.normal.mode
  graceP = config.normal.gracePeriod
  
end




--if item == "Battery" or item == "BatteryNotFull" then
  if item == "Battery" then

  config = thisModel.battery[context]

  critTH = config.criticalThreshold
  warnTH = config.warningThreshold
  critMD = config.announceCriticalMode
  warnMD = config.announceWarningMode
  normMD = config.announceNormalMode
  graceP = config.graceperiod


end


if item == "BatteryNotFull" then

  --config = BatteryDefinition[typeBattery[context]]
  config = thisModel.battery[context]

  critTH = config.notFullCriticalThreshold
  warnTH = config.notFullWarningThreshold
  critMD = config.announceNotFullCriticalMode
  warnMD = config.announceNotFullWarningMode
  normMD = "disable"
  graceP = config.graceperiod


end

  context = context or "global"

  local itemNameWithContext = context .. item

  -- Initialize statusTable entry for the item if it doesn't exist
  if not statusTable[itemNameWithContext] then
    statusTable[itemNameWithContext] = { lastStatus = nil, lastAnnounceTime = 0, changeStartTime = 0, context = context }
  end

  local itemStatus = statusTable[itemNameWithContext]
  local currentTime = getTime() / 100  -- Get current time in seconds

  debugPrint(string.format("DBGANO: Item: %s, Current Status: %s, Context: %s, Critical Threshold: %s, Warning Threshold: %s, Critical Mode: %s, Warning Mode: %s, Normal Mode: %s, Grace Period: %s",
  item, tostring(currentStatus), context, tostring(critTH), tostring(warnTH), tostring(critMD), tostring(warnMD), tostring(normMD), tostring(graceP)))

  -- Determine severity and mode
  local severity, mode = "normal", normMD
  if type(currentStatus) == "number" then
    if currentStatus <= critTH then
      severity, mode = "critical", critMD
    elseif currentStatus <= warnTH then
      severity, mode = "warning", warnMD
    end
  elseif type(currentStatus) == "boolean" then
    if currentStatus == warnTH then
      severity, mode = "warning", warnMD
    elseif currentStatus == critTH then
      severity, mode = "critical", critMD
    end
  end

  debugPrint("STCHDET: Item:", item, "Current Status:", currentStatus, "Severity Level:", severity, "Mode:", mode, "Context:", context)

  if mode == "disable" then
    -- Do nothing if announcements are disabled
    debugPrint("STCHDET: Announcements are disabled for item:", item, "Context:", context)
    return
  end

  local announceNow = false

  if mode == "change" then
    if itemStatus.lastStatus ~= currentStatus then
      if itemStatus.changeStartTime == 0 then
        -- Start the grace period
        itemStatus.changeStartTime = currentTime
        debugPrint("STCHDET: Change detected for item:", item, "Starting grace period at time:", currentTime, "Context:", context)
      else
        local elapsedGracePeriod = currentTime - itemStatus.changeStartTime
        debugPrint(string.format("STCHDET: Elapsed grace period for item %s: %.2f seconds", item, elapsedGracePeriod), "Context:", context)
        if elapsedGracePeriod >= graceP then
          -- Announce if grace period has passed (config.normal.gracePeriod is in seconds)
          announceNow = true
          debugPrint("STCHDET: Grace period passed for item:", item, "Announcing change", "Context:", context)
          itemStatus.lastStatus = currentStatus
        end
      end
    else
      -- Reset grace period if status reverts to previous within grace period
      if itemStatus.changeStartTime ~= 0 then
        debugPrint("STCHDET: Status reverted to previous within grace period for item:", item, "Resetting grace period", "Context:", context)
        itemStatus.changeStartTime = 0
      end
    end
  elseif type(mode) == "number" then
    -- Interval mode
    interval = mode
    if (currentTime - itemStatus.lastAnnounceTime) >= interval then
      announceNow = true
      debugPrint("STCHDET: Interval passed for item:", item, "Announcing at interval", "Context:", context)
    end
  end

  -- Collect announcements
  if announceNow then
    debugPrint("STCHDET: Adding announcement for item:", item, "Current status:", currentStatus, "Severity level:", severity, "Context:", context)
    table.insert(announcements, { item = item, status = currentStatus, severity = severity, context = context })
    itemStatus.lastAnnounceTime = currentTime
  end
end

local function doAnnouncements(context)
  -- checkChangedInterval(85, "telemetry", context) -- Numerical status example
  -- checkChangedInterval("online", "telemetry", context) -- Boolean status example
  -- checkChangedInterval(45, "unknownItem", context) -- Example with an item not in the config

  announcements = {}  -- Clear announcements table at the start of each call


  --setDebug(true)

  checkChangedInterval(statusTele, "telemetry")


  if  statusTele and allSensorsValid then -- do these only if telemetry true
-- here
--debugPrint("CCIV: " .. context )
  checkChangedInterval(thisModel.VoltageSensor[context].cellMissing, "BatteryMissingCell", context)
  checkChangedInterval(thisModel.VoltageSensor[context].PercRem, "BatteryNotFull", context)
  checkChangedInterval(thisModel.VoltageSensor[context].cellInconsistent, "CellDelta", context)
  checkChangedInterval(thisModel.VoltageSensor[context].PercRem, "Battery", context)

  end

  

    -- Process collected announcements
    if next(announcements) ~= nil then
      debugPrint("STCHDET: Found announcements to be done.")

      local contextAnnounceDone = false

      for _, announcement in ipairs(announcements) do
        debugPrint(string.format("STCHDET: Announcing item: %s, Severity: %s, Current value: %s", announcement.item, announcement.severity, announcement.status))
        -- Perform announcement logic here
        -- You can access announcement.item, announcement.severity, and announcement.status


      if announcement.item == "telemetry" then
        if announcement.severity == "normal" then
          queueSound("tele",0)
          queueSound("normal",1)
        else
        queueSound("wtf",0)
        queueSound("tele",1)
        end
      end

      if announcement.item ~= "telemetry" and not contextAnnounceDone then
        queueSound(context,0)
        queueSound("battery",0)
        contextAnnounceDone = true
      end

      if announcement.item == "BatteryMissingCell" then
        if announcement.severity == "critical" or announcement.severity == "warning" then

          --local reverseValue = math.abs(cellMissing[context])
          local reverseValue = math.abs(thisModel.VoltageSensor[context].cellMissing)

          

          --queueSound(context,0)
          --queueSound("battery",0)
          queueSound(announcement.severity,0)
          queueSound("missing",0)
          queueNumber(reverseValue, 0, 0 , 0 )
          queueSound("of",0)
          queueNumber(thisModel.CellCount[context], 0, 0 , 0 )
          queueSound("cell",0)


        end
      end


      if announcement.item == "CellDelta" then
        if announcement.severity == "critical" or announcement.severity == "warning" then
          --queueSound(context,0)
          --queueSound("battery",0)
          queueSound(announcement.severity,0)
          queueSound("icw",0)
        end
      end


      if announcement.item == "BatteryNotFull" then
        if announcement.severity == "critical" or announcement.severity == "warning" then

          --queueSound(context,0)
          --queueSound("battery",0)
          queueSound(announcement.severity,0)
          queueSound("notfull",0)

        end
      end
      
      

      if announcement.item == "Battery" then
        if announcement.severity == "critical" or announcement.severity == "warning" then

          --queueSound(context,0)
          --queueSound("battery",0)
          queueSound(announcement.severity,0)
          queueNumber(thisModel.VoltageSensor[context].PercRem, 13, 0 , 0 )

        else

          --queueSound(context,0)
          --queueSound("battery",0)
          queueNumber(thisModel.VoltageSensor[context].PercRem, 13, 0 , 0 )

        end
      end
      
      
      end
    else
      debugPrint("STCHDET: No announcements to be done.")
    end

    --setDebug(false)

end


  -- worst case scenario how events should be played on first init/tele
  -- main battery
  -- critical
  -- 11 of 12 cells detected
  -- 1 cell missing
  -- battery not full
  -- current voltage 22 volts
  -- 55%




-- ####################################################################
-- ####################################################################
-- ####################################################################
-- ####################################################################


-- ####################################################################
local function check_cell_delta_voltage(context)
  -- Check to see if all cells are within VoltageDelta volts of each other
  --  default is .3 volts, can be changed above

  --   check_cell_delta_voltage(thisModel.VoltageSensor[context].value)
-- thisModel.VoltageSensor[context].cellInconsistent

--local vDelta = BatteryDefinition[typeBattery[context]].cellDeltaVoltage
local vDelta = thisModel.battery[context].cellDeltaVoltage

  if (type(thisModel.VoltageSensor[context].value) == "table") then -- check to see if this is the dedicated voltage sensor

    thisModel.VoltageSensor[context].cellInconsistent = false

    for i, v1 in ipairs(thisModel.VoltageSensor[context].value) do
      for j,v2 in ipairs(thisModel.VoltageSensor[context].value) do
        -- debugPrint(string.format("i: %d v: %f j: %d v: %f", i, v1, j,v2))
        if i~=j and (math.abs(v1 - v2) > vDelta) then
          --debugPrint(string.format("i: %d v: %f j: %d v: %f", i, v1, j,v2))
          --timeElapsed = HasSecondsElapsed(10)  -- check to see if the 10 second timer has elapsed
          --if PlayFirstInconsistentCellWarning or (PlayInconsistentCellWarning == true and timeElapsed) then -- Play immediately upon detection and then every 10 seconds
          --  --playFile(soundDirPath.."icw.wav")
          --  queueSound("icw",2)
--
          --  PlayFirstInconsistentCellWarning = false -- clear the first play flag, only reset on reset switch toggle
          --  PlayInconsistentCellWarning = false -- clear the playing flag, only reset it at 10 second intervals
          --end
          --if not timeElapsed then  -- debounce so the sound is only played once in 10 seconds
          --  PlayInconsistentCellWarning = true
          --end
          --return
          thisModel.VoltageSensor[context].cellInconsistent = true
        end
      end
    end
  end
end

-- ####################################################################
local function check_for_missing_cells(context)
    -- check_for_missing_cells(thisModel.VoltageSensor[context].value, thisModel.CellCount[context])
    -- local function check_for_missing_cells(voltageSensorValue, expectedCells )

    --local CfullVolt = BatteryDefinition[typeBattery[context]].highVoltage
    local CfullVolt = thisModel.battery[context].highVoltage

debugPrint("MC VOL:" .. CfullVolt)

  -- If the number of cells detected by the voltage sensor does not match the value in GV6 then play the warning message
  -- This is only for the dedicated voltage sensor
  --debugPrint(string.format("CellCount: %d thisModel.VoltageSensor[context].value:", CellCount))
  --if thisModel.CellCount[context] > 0 then
    if thisModel.CellCount[context] > 0 then

    local missingCellDetected = false

    if (type(thisModel.VoltageSensor[context].value) == "table") then
      --tableSize = 0 -- Initialize the counter for the cell table size
      --for i, v in ipairs(thisModel.VoltageSensor[context].value) do
      --  tableSize = tableSize + 1
      --end
      --if tableSize ~= CellCount then
      thisModel.VoltageSensor[context].CellsDetectedCurrent = #thisModel.VoltageSensor[context].value
      if #thisModel.VoltageSensor[context].value ~= thisModel.CellCount[context] then
        --debugPrint(string.format("CellCount: %d tableSize: %d", CellCount, tableSize))
        
        missingCellDetected = true
      end
    --elseif VoltageSensor == "VFAS" and type(thisModel.VoltageSensor[context].value) == "number" then --this is for the vfas sensor
    elseif type(thisModel.VoltageSensor[context].value) == "number" then --this is for the vfas sensor
      thisModel.VoltageSensor[context].CellsDetectedCurrent = math.ceil( thisModel.VoltageSensor[context].value / ( CfullVolt + 0.3) ) --todo 0.3 ??
      --thisModel.VoltageSensor[context].CellsDetectedCurrent = math.floor( thisModel.VoltageSensor[context].value / 3.2 )
      --if (thisModel.CellCount[context] * 3.2) > (thisModel.VoltageSensor[context].value) then
        if thisModel.VoltageSensor[context].CellsDetectedCurrent ~= thisModel.CellCount[context]  then
          --debugPrint(string.format("vfas missing cell: %d", thisModel.VoltageSensor[context].value))
        
        missingCellDetected = true
      end
    end



    -- cellMissing[context] = missingCellDetected
    thisModel.VoltageSensor[context].cellMissing =  thisModel.VoltageSensor[context].CellsDetectedCurrent  - thisModel.CellCount[context]

    if thisModel.VoltageSensor[context].cellMissing == 0 then
      thisModel.VoltageSensor[context].CellsDetected = true
    end


  end

end

-- local function getInvalidSensorNames()
--   local invalidSensors = {}
--   local uniqueSensors = {}
-- 
--   -- Helper function to add a sensor name if it's not already in the set
--   local function addUniqueSensor(sensorName)
--       -- Extract the base sensor name without the suffixes "+", "-", or any numbers following
--       local baseName = string.match(sensorName, "^(.-)[+%-%d]*$")
--       if baseName and not uniqueSensors[baseName] then
--           uniqueSensors[baseName] = true
--           table.insert(invalidSensors, baseName)
--       end
--   end
-- 
--   -- Helper function to check and add invalid sensors
--   local function checkSensors(sensorList)
--       for _, sensor in ipairs(sensorList) do
--           if sensor.valid == false then
--               addUniqueSensor(sensor.sensorName)
--           end
--       end
--   end
-- 
--   -- Check standard sensors
--   checkSensors({
--       thisModel.VoltageSensor.main,
--       thisModel.VoltageSensor.receiver,
--       thisModel.CurrentSensor.main,
--       thisModel.CurrentSensor.receiver,
--       thisModel.MahSensor.main,
--       thisModel.MahSensor.receiver
--   })
-- 
--   -- Check additional sensors
--   for _, adlSensor in ipairs(thisModel.AdlSensors) do
--       checkSensors(adlSensor.sensors)
--   end
-- 
--   return invalidSensors
-- end




-- Function to initialize sensor IDs
-- local function initializeSensorId(sensor)
-- 
--   if not sensor.valid or sensor.valid == nil then
-- 
--   local fieldInfo = getFieldInfo(sensor.sensorName)
--   if fieldInfo then
--     sensor.sensorId = fieldInfo.id
--     sensor.valid = true
--     debugPrint("UPDSEN: INIT: " .. sensor.sensorName .. " ID: " .. fieldInfo.id)
--   else
--     print("Field info not found for sensor: " .. sensor.sensorName)
--     -- todo add to wrong sensor list
--     sensor.valid = false
-- 
--     --table.insert(badormissingsensors, sensor.sensorName)
-- 
--  end
-- 
-- end
-- 
-- end

local function initializeSensorId(sensor)
  if not sensor.valid or sensor.valid == nil then
      local fieldInfo = getFieldInfo(sensor.sensorName)
      if fieldInfo then
          sensor.sensorId = fieldInfo.id
          sensor.valid = true
          debugPrint("UPDSEN: INIT: " .. sensor.sensorName .. " ID: " .. fieldInfo.id)
          -- Sensor became valid, do nothing with invalid list
      else
          print("Field info not found for sensor: " .. sensor.sensorName)
          sensor.valid = false
          --local normalizedName = sensor.sensorName:gsub("[%+%-%s]", "")
          local normalizedName = string.gsub(sensor.sensorName, "[+%-%s]", "")
          if not string.find(invalidSensorList, normalizedName) then
            if invalidSensorList ~= "" then
                invalidSensorList = invalidSensorList .. ","
            end
            invalidSensorList = invalidSensorList .. normalizedName
          end
      
      end
  end
end


-- Function to update sensor values
local function updateSensorValue(sensor)
  
  if sensor.sensorId then
    sensor.value = getValue(sensor.sensorId)
    debugPrint("UPDSEN: VAL: " .. tostring(sensor.value) .. " ID: " .. sensor.sensorId)
  end
end

-- Initialize sensor IDs for all sensor groups
local function initializeAndCheckAllSensorIds()

  if not allSensorsValid then

  --invalidSensorList = {}

  invalidSensorList = ""

  initializeSensorId(thisModel.VoltageSensor.main)
  initializeSensorId(thisModel.VoltageSensor.receiver)
  initializeSensorId(thisModel.CurrentSensor.main)
  initializeSensorId(thisModel.CurrentSensor.receiver)
  initializeSensorId(thisModel.MahSensor.main)
  initializeSensorId(thisModel.MahSensor.receiver)


 for _, adlSensor in ipairs(thisModel.AdlSensors) do
    for _, sensor in ipairs(adlSensor.sensors) do
      initializeSensorId(sensor)
    end
  end
end

if not allSensorsValid then

if invalidSensorList == "" then

allSensorsValid = true

debugPrint("INVS: All Sensors valid")

pfStatus.text = "All Sensors valid"
pfStatus.color = GREEN

  -- todo: maybe consider/adapt to use cases with only current and/or mah sensors
  if thisModel.VoltageSensor.main.sensorId ~= nil then
    table.insert(contexts, "main")
    --CellsDetected["main"] = false
    thisModel.VoltageSensor.main.CellsDetected = false
    --numberOfBatteries = numberOfBatteries + 1
  else
    thisModel.VoltageSensor.main.CellsDetected = true
  end

  if thisModel.VoltageSensor.receiver.sensorId ~= nil then
    table.insert(contexts, "receiver")
    thisModel.VoltageSensor.receiver.CellsDetected = false
    --numberOfBatteries = numberOfBatteries + 1
  else
    thisModel.VoltageSensor.receiver.CellsDetected = true
  end

else
  debugPrint("INVS: Invalid Sensors: " .. invalidSensorList)

  pfStatus.text = "Invalid Sensors: " .. invalidSensorList
  pfStatus.color = YELLOW

end

end

end

-- -- Update sensor values for all sensor groups
-- local function updateAllSensorValues(model)
--   updateSensorValue(model.VoltageSensor.main)
--   updateSensorValue(model.VoltageSensor.receiver)
--   updateSensorValue(model.CurrentSensor.main)
--   updateSensorValue(model.CurrentSensor.receiver)
--   updateSensorValue(model.MahSensor.main)
--   updateSensorValue(model.MahSensor.receiver)
-- 
-- 
--  for _, adlSensor in ipairs(model.AdlSensors) do
--     for _, sensor in ipairs(adlSensor.sensors) do
--       updateSensorValue(sensor)
--     end
--   end
-- end






-- ####################################################################
local function init_func()

if not modelAlreadyLoaded then --todo --- maybe move all of this stuff out of init 

  local currentModelName = model.getInfo().name

  debugPrint ("TEST MODEL:" , currentModelName)

  modelDetails = getModelDetails(currentModelName)

  rxReferenceVoltage = modelDetails.rxReferenceVoltage
-- Call the resolve function to update thresholds based on BattType
--resolveDynamicValues()

-- printHumanReadableTable(announcementConfig)
-- typeBattery = {}
-- 
-- typeBattery["main"]           = modelDetails.BattType.main
-- typeBattery["receiver"]       = modelDetails.BattType.receiver

-- we are manipulating the battery definitions at runtime when the model is loaded ... let's work on a copy of the model
BatteryDefinition = BatteryTypeDefaults

thisModel = modelDetails

--thisModel.battery.main.lowVoltage

if thisModel.battery.main.lowVoltage == nil then
  thisModel.battery.main.lowVoltage = 3.27 --todo is this wise todo ?
end

if thisModel.battery.main.highVoltage == nil then
  thisModel.battery.main.highVoltage = 4.2 --todo is this wise todo ?
end

if thisModel.battery.main.dischargeCurve == nil then -- we have no discharge curve .... lets build a linear one at runtime

 debugPrint("NO DISCHARGE CURVE FOR MAIN")

 thisModel.battery.main.dischargeCurve = calculateLinearDischargeCurve(thisModel.battery.main.lowVoltage, thisModel.battery.main.highVoltage)

end



if thisModel.battery.receiver.lowVoltage == nil  then
 if thisModel.battery.receiver.isNotABattery then
  thisModel.battery.receiver.lowVoltage = 6 --todo is this wise todo ?
 else
  thisModel.battery.receiver.lowVoltage = 3.27
 end
end

if thisModel.battery.receiver.highVoltage == nil  then
 if thisModel.battery.receiver.isNotABattery then
  thisModel.battery.receiver.highVoltage = rxReferenceVoltage
 else
  thisModel.battery.receiver.highVoltage = 4.2
 end
end


if thisModel.battery.receiver.isNotABattery then

  thisModel.battery.receiver.lowVoltage  = thisModel.battery.receiver.lowVoltage / 2
  thisModel.battery.receiver.highVoltage = thisModel.battery.receiver.highVoltage / 2

end



if thisModel.battery.receiver.dischargeCurve == nil  then-- we have no discharge curve .... lets build a linear one at runtime

debugPrint("NO DISCHARGE CURVE FOR RECEIVER")



thisModel.battery.receiver.dischargeCurve = calculateLinearDischargeCurve(thisModel.battery.receiver.lowVoltage, thisModel.battery.receiver.highVoltage)

end


 

-- Call the function to update the config
--updateAnnouncementConfig(announcementConfig, BatteryTypeDefaults, typeBattery["main"], typeBattery["receiver"])


-- printHumanReadableTable(announcementConfig)

-- printHumanReadableTable(thisModel)





  contexts = {}
  currentContextIndex = 1
--- -- Add entries to the table
--- table.insert(contexts, "main")
--- table.insert(contexts, "receiver")
--- table.insert(contexts, "backup")

 --sensorVoltage = {}
 --sensorCurrent = {}
 --sensorMah = {}
 --countCell = {}

  --tableBatCapacity = {}

pfStatus = {
    text = "unknown",  -- This can be "ok", "warning", "error", or "unknown"
    color = GREY      -- Default color for unknown status
}
  switchIndexes = {}
  previousSwitchState = {}

  --currentSensorVoltageValue = {}
  --currentSensorCurrentValue = {}
  --currentSensorMahValue = {}

  --currentVoltageValueCurrent = {}
  --currentCurrentValueCurrent = {}
--
  --currentVoltageValueLatest = {}
  --currentCurrentValueLatest = {}
--
  --currentVoltageValueHigh = {}
  --currentCurrentValueHigh = {}

  --currentVoltageValueLow = {}
  --currentCurrentValueLow = {}

  ---valueVoltsPercentRemaining = {}

  --currentMahValue = {}

  --CellsDetected = {}

  --sensorline1 = nil
  --sensorline2 = nil

  -- todo --- build variables using context switching

  --CellsDetectedCurrent = {}
  --CellsDetectedCurrent["main"]      = 0
  --CellsDetectedCurrent["receiver"]  = 0

  thisModel.VoltageSensor.main.CellsDetectedCurrent = 0
  thisModel.VoltageSensor.receiver.CellsDetectedCurrent = 0

  -- thisModel.VoltageSensor[context].CellsDetectedCurrent

  detectedBattery = {}
  detectedBatteryValid = {}

  numberOfBatteries = 0
  --previousSwitchState = {}

  --modelName = modelDetails.modelName
  --modelImage = modelDetails.modelImage
  --modelWav = modelDetails.modelWav

  queueSound(modelDetails.modelWav,2)

  debugPrint("MODEL NAME: ", thisModel.modelName)
  debugPrint("MODEL IMAGE: ",thisModel.modelImage)
 
  -- sensorVoltage["main"]         = getFieldInfo(modelDetails.VoltageSensor.main)
  -- sensorVoltage["receiver"]     = getFieldInfo(modelDetails.VoltageSensor.receiver)
-- 
  -- sensorCurrent["main"]         = getFieldInfo(modelDetails.CurrentSensor.main)
  -- sensorCurrent["receiver"]     = getFieldInfo(modelDetails.CurrentSensor.receiver)
-- 
  -- sensorMah["main"]             = getFieldInfo(modelDetails.MahSensor.main)
  -- sensorMah["receiver"]         = getFieldInfo(modelDetails.MahSensor.receiver)

  --myid = getFieldInfo(sensorCurrent["main"])
--
  --debugPrint("GFI: id:" .. myid.id )
  --debugPrint("GFI: name:" .. myid.name )
  --debugPrint("GFI: desc:" .. myid.desc )
  --debugPrint("GFI: unit:" .. myid.unit )
  --debugPrint("GFI: test unit:" .. sensorVoltage["main"].unit )
  --debugPrint("GFI: test name:" .. sensorVoltage["main"].name )

  invalidSensorList = ""

  allSensorsValid = false

  

  -- initializeAllSensorIds()
-- 
  -- debugPrint("INVS:" .. invalidSensorList)


  -- countCell["main"]             = tonumber(modelDetails.CellCount.main)
  -- countCell["receiver"]         = tonumber(modelDetails.CellCount.receiver)
-- 
  -- tableBatCapacity["main"]      = modelDetails.capacities["main"]
  -- tableBatCapacity["receiver"]  = modelDetails.capacities["receiver"]
-- 
  -- currentVoltageValueCurrent["main"] = 0 -- current value even when tele lost
  -- currentVoltageValueLatest["main"] = 0  -- last value while tele was present
  -- currentVoltageValueHigh["main"] = 0
  -- currentVoltageValueLow["main"] = 0
-- 
  -- currentVoltageValueCurrent["receiver"] = 0 -- current value even when tele lost
  -- currentVoltageValueLatest["receiver"] = 0  -- last value while tele was present
  -- currentVoltageValueHigh["receiver"] = 0
  -- currentVoltageValueLow["receiver"] = 0
-- 
  -- currentCurrentValueCurrent["main"] = 0
  -- currentCurrentValueLatest["main"] = 0
  -- currentCurrentValueHigh["main"] = 0
  -- currentCurrentValueLow["main"] = 0
-- 
  -- currentCurrentValueCurrent["receiver"] = 0
  -- currentCurrentValueLatest["receiver"] = 0
  -- currentCurrentValueHigh["receiver"] = 0
  -- currentCurrentValueLow["receiver"] = 0

  -- valueVoltsPercentRemaining["main"] = 0
  -- valueVoltsPercentRemaining["receiver"] = 0

  thisModel.VoltageSensor.main.CurVolt = 0
  thisModel.VoltageSensor.main.LowestVolt = 0
  thisModel.VoltageSensor.main.HighestVolt = 0

  thisModel.CurrentSensor.main.CurAmp = 0
  thisModel.CurrentSensor.main.LowestAmp = 0
  thisModel.CurrentSensor.main.HighestAmp = 0

  thisModel.VoltageSensor.receiver.CurVolt = 0
  thisModel.VoltageSensor.receiver.LowestVolt = 0
  thisModel.VoltageSensor.receiver.HighestVolt = 0

  thisModel.CurrentSensor.receiver.CurAmp = 0
  thisModel.CurrentSensor.receiver.LowestAmp = 0
  thisModel.CurrentSensor.receiver.HighestAmp = 0

  thisModel.VoltageSensor.main.PercRem = 0
  thisModel.VoltageSensor.receiver.PercRem = 0

  
  -- thisModel.MahSensor.main.CurAmp = 0
  -- thisModel.MahSensor.main.LowestAmp = 0
  -- thisModel.MahSensor.main.HighestAmp = 0

  preFlightStatusTele = "unknown"
  preFlightStatusBat = "unknown"

  -- cellMissing = {}
  -- cellMissing["main"] = 0
  -- cellMissing["receiver"] = 0

  thisModel.VoltageSensor.main.cellMissing = 0
  thisModel.VoltageSensor.receiver.cellMissing = 0

-- 
  -- cellInconsistent = {}
  -- cellInconsistent["main"] = false
  -- cellInconsistent["receiver"] = false

  thisModel.VoltageSensor.main.cellInconsistent = false
  thisModel.VoltageSensor.receiver.cellInconsistent = false


  -- batteryNotFull = {}
  -- batteryNotFull["main"] = nil -- nil means not determined yet / on init
  -- batteryNotFull["receiver"] = nil -- nil means not determined yet / on init


  statusTele = false

  

  --switchReset                   = modelDetails.resetSwitch
  --statusTele                    = modelDetails.telemetryStatus


  --idswitchReset                 = getSwitchIndex(switchReset)
  --idstatusTele                  = getSwitchIndex(statusTele)
  debugPrint("INIVAL: " .. thisModel.resetSwitch)

  thisModel.resetswitchid = getSwitchIndex(thisModel.resetSwitch)

  --tableSwitchAnnounces          = modelDetails.switchAnnounces
  --tableLine1StatSensors         = modelDetails.line1statsensors
  --tableLine2StatSensors         = modelDetails.line2statsensors
  --tableBattPackSelectorSwitch   = modelDetails.BattPackSelectorSwitch

  -- todo ... is this really needed ?
  --detectedBattery["main"] = false
  --detectedBattery["receiver"] = false
--
  --detectedBatteryValid["main"] = false
  --detectedBatteryValid["receiver"] = false

  batCheckPassed = false

  --badormissingsensors = {}

  -- local invalidSensorNames = getInvalidSensorNames()
  -- if #invalidSensorNames > 0 then
  --     debugPrint("INVS: Invalid sensors: " .. table.concat(invalidSensorNames, ", "))
  -- else
  --   debugPrint("INVS: All sensors are valid.")
  -- end

  numOfBatPassedCellCheck = 0




  for _, switchInfo in ipairs(thisModel.switchAnnounces) do --todo --- maybe with a table and index too ?
    local switch = switchInfo[1]
    local switchIndex = getFieldInfo(switch).id
    debugPrint("ANN SW IDX: ", switch)
    switchIndexes[switch] = switchIndex
  end

  thisModel.bmpModelImage = Bitmap.open("/IMAGES/" .. thisModel.modelImage)

  thisModel.bmpSizedModelImage = Bitmap.resize(thisModel.bmpModelImage, 400, 300)


-- modelWav
  

  
  -- Called once when model is loaded
  --BatCapFullmAh = model.getGlobalVariable(GVBatCap, GVFlightMode) * 100
  -- BatCapmAh = BatCapFullmAh
  --BatCapmAh = BatCapFullmAh * (100-CapacityReservePercent)/100
  --BatRemainmAh = BatCapmAh
  --CellCount = model.getGlobalVariable(GVCellCount, GVFlightMode)

  BatRemainmAh = 0 -- todo

  BatRemPer = 0 -- todo remove

  modelAlreadyLoaded = true

end

end

-- ####################################################################
local function reset_if_needed()
  -- test if the reset switch is toggled, if so then reset all internal flags
  -- if not ResetSwitchState  then -- Update switch position
  -- if ResetSwitchState == nil or AutomaticResetOnResetPrevState ~= ResetSwitchState then -- Update switch position
    --if AutomaticResetOnResetPrevState ~= ResetSwitchState then -- Update switch position

    ResetSwitchState = getSwitchValue(thisModel.resetswitchid)

    --debugPrint("RESET: Switch state :", ResetSwitchState)

    if ResetSwitchState and not AutomaticResetOnNextChange then
      TriggerTimers["resetdelay"] = 0
      return -- no need to do anything when telemetry is on and no reset is needed
    end

    if not ResetSwitchState  and not AutomaticResetOnNextChange then -- no telemetry for longer then delay
  
      if Timer("resetdelay", AutomaticResetOnResetSwitchToggle) then
    --AutomaticResetOnResetPrevState = ResetSwitchState

    --TriggerTimers["resetdelay"] = getTime()

    --debugPrint(string.format("RESET: State change Triggered ... Trigger State: %s at Count: %s",ResetSwitchState, AutomaticResetStateChangeCount))

    debugPrint("RESET: no telemetry for longer than 4 seconds... will reset at next telemetry on")

    if maj >= 2 and minor >= 11 then
      debugPrint("RESET: Taking Screenshot")
    screenshot()
    end

    AutomaticResetOnNextChange = true
      end

    end




  if ResetSwitchState  and AutomaticResetOnNextChange then
    --return

    -- AutomaticResetOnResetPrevState = ResetSwitchState

    debugPrint("RESET: RESETTING")

    TriggerTimers["resetdelay"] = 0

    --if ResetDebounced and HasSecondsElapsed(2) and -1024 ~= getValue(SwReset) then -- reset switch
      --debugPrint("RESET")
      CheckBatNotFull = true
      --StartTime = nil
      PlayInconsistentCellWarning = true --todo
      PlayFirstMissingCellWarning = true --todo
      PlayMissingCellWarning = true --todo
      PlayFirstInconsistentCellWarning = true --todo
      InconsistentCellVoltageDetected = false

      PlayRxBatFirstWarning = true
      PlayRxBatWarning = false

      VoltageHistory = {}
      ResetDebounced = false



      AutomaticResetOnResetPrevState = nil

      AutomaticResetStateChangeCount = 0
      AutomaticResetOnNextChange = false


      MaxWatts = "-----"  -- todo ... do we want to display ---- ? makes sense if sensor not present
      MaxAmps = "-----"  -- todo ... do we want to display ---- ? makes sense if sensor not present

      -- CellsDetected = false



      FirstModelInit = true -- todo maybe there is a better place to put this ... maybe init ?


  end
end


-- ####################################################################
local function checkForTelemetry()

  local currentStatusTele = getSwitchValue(idstatusTele)




  if not statusTele and currentStatusTele and not Timer("telegrace", 2) then
    debugPrint("TELEDELAY:")
    return
  end

  -- thisModel.VoltageSensor.main.
  if not currentStatusTele then
    thisModel.VoltageSensor.main.CurVolt     = "--.--"
    thisModel.CurrentSensor.main.CurAmp      = "--.--"

    thisModel.VoltageSensor.receiver.CurVolt     = "--.--"
    thisModel.CurrentSensor.receiver.CurAmp      = "--.--"

    pfStatus.text = "Waiting for Telemetry"
    pfStatus.color = RED
  else
    pfStatus.text = "Telemetry OK"
    pfStatus.color = GREEN

    end

  TriggerTimers["telegrace"] = 0

  statusTele = getSwitchValue(idstatusTele)


end

-- ####################################################################
local function updateSensorValues(context)


  -- thisModel.VoltageSensor[context].value = getValue(sensorVoltage[context].id)
  -- currentSensorCurrentValue[context] = getValue(sensorCurrent[context].id)
  -- currentSensorMahValue[context]     = getValue(sensorMah[context].id)

  -- thisModel.VoltageSensor[context].sensorValue = getValue(thisModel.VoltageSensor[context].sensorId)
  -- thisModel.CurrentSensor[context].sensorValue = getValue(thisModel.CurrentSensor[context].sensorId)
  --     thisModel.MahSensor[context].sensorValue     = getValue(thisModel.MahSensor[context].sensorId)
debugPrint("UPDSEN: " .. context)

  updateSensorValue(thisModel.VoltageSensor[context])
  updateSensorValue(thisModel.CurrentSensor[context])
  updateSensorValue(thisModel.MahSensor[context])

  for _, adlSensor in ipairs(thisModel.AdlSensors) do
   for _, sensor in ipairs(adlSensor.sensors) do
     updateSensorValue(sensor)
   end
 end



  -- currentVoltageValueLatest[context] = getCellVoltage(thisModel.VoltageSensor[context].value)
  -- currentCurrentValueLatest[context] = getAmp(sensorCurrent[context]) --todo .. function calls getValue again

  -- currentVoltageValueCurrent[context] = math.floor(getCellVoltage(thisModel.VoltageSensor[context].value)  * 100) / 100   -- this will hold the current value ... even if no telemetry --> = 0
  -- currentCurrentValueCurrent[context] = math.floor(getAmp(sensorCurrent[context])   * 100) / 100 --todo .. function calls getValue again -- this will hold the current value ... even if no telemetry --> = 0

  thisModel.VoltageSensor[context].CurVolt = math.floor(getCellVoltage(thisModel.VoltageSensor[context].value)  * 100) / 100   -- this will hold the current value ... even if no telemetry --> = 0
  thisModel.CurrentSensor[context].CurAmp = math.floor(getAmp(thisModel.CurrentSensor[context].value)   * 100) / 100 --todo .. function calls getValue again -- this will hold the current value ... even if no telemetry --> = 0

  -- updateAllSensorValues(thisModel)

  -- local truncatedNumber = math.floor(number * 100) / 100

  -- string.format("%.2f", number)

  debugPrint(string.format("Updated Sensor Values: Context: %s Sensor Voltage: %s ( get Cell: %s ) Sensor Current: %s Sensor mah: %s Volt: %s Current: %s mAh: %s", context, thisModel.VoltageSensor[context].sensorName,  thisModel.VoltageSensor[context].CurVolt , thisModel.CurrentSensor[context].sensorName, thisModel.MahSensor[context].sensorName, thisModel.VoltageSensor[context].value, thisModel.CurrentSensor[context].value, thisModel.MahSensor[context].value))

  -- disabled --           if VoltsNow < 1 or volts > 1 then
  -- disabled --             VoltsNow = volts
  -- disabled --           end

  if thisModel.VoltageSensor[context].LatestVolt == 0  or thisModel.VoltageSensor[context].CurVolt ~= 0 then
    thisModel.VoltageSensor[context].LatestVolt = thisModel.VoltageSensor[context].CurVolt
  end

  if thisModel.VoltageSensor[context].HighestVolt == 0 or ( thisModel.VoltageSensor[context].CurVolt > thisModel.VoltageSensor[context].HighestVolt and thisModel.VoltageSensor[context].CurVolt ~= 0.00 ) then
    thisModel.VoltageSensor[context].HighestVolt = thisModel.VoltageSensor[context].CurVolt
  end

  if thisModel.VoltageSensor[context].LowestVolt == 0 or ( thisModel.VoltageSensor[context].CurVolt < thisModel.VoltageSensor[context].LowestVolt and thisModel.VoltageSensor[context].CurVolt ~= 0.00 ) then
    thisModel.VoltageSensor[context].LowestVolt = thisModel.VoltageSensor[context].CurVolt
    --debugPrint(string.format("Updated Sensor Values Low: Context: %s Sensor Voltage: %s ( get Cell: %s ) Sensor Current: %s Sensor mah: %s Volt: %s Current: %s mAh: %s", context, sensorVoltage[context].name, thisModel.VoltageSensor[context].CurVolt , sensorCurrent[context].name, sensorMah[context].name, thisModel.VoltageSensor[context].value, currentSensorCurrentValue[context], currentSensorMahValue[context]))
-- Updated Sensor Values Low: Context: main Sensor Voltage: Cels ( get Cell: nil ) Sensor Current: Curr Sensor mah:  Volt: 0 Current: 0 mAh: 0
  end




  if thisModel.CurrentSensor[context].LatestAmp == 0 or thisModel.CurrentSensor[context].CurAmp ~= 0 then
    thisModel.CurrentSensor[context].LatestAmp = thisModel.CurrentSensor[context].CurAmp
  end

  if thisModel.CurrentSensor[context].HighestAmp == 0 or ( thisModel.CurrentSensor[context].CurAmp > thisModel.CurrentSensor[context].HighestAmp and thisModel.CurrentSensor[context].CurAmp ~= 0.00 )   then
    thisModel.CurrentSensor[context].HighestAmp = thisModel.CurrentSensor[context].CurAmp
  end

  if thisModel.CurrentSensor[context].LowestAmp == 0 or ( thisModel.CurrentSensor[context].CurAmp < thisModel.CurrentSensor[context].LowestAmp  and thisModel.CurrentSensor[context].CurAmp ~= 0.00 )  then
    thisModel.CurrentSensor[context].LowestAmp = thisModel.CurrentSensor[context].CurAmp
  end


  

  --if not cellMissing[context] then
  thisModel.VoltageSensor[context].PercRem  = findPercentRem( thisModel.VoltageSensor[context].LatestVolt/thisModel.CellCount[context],  context)
    debugPrint(string.format("SUPD: Got Percent: %s for Context: %s", thisModel.VoltageSensor[context].PercRem, context))

    BatRemPer = thisModel.VoltageSensor[context].PercRem -- todo eliminate
  --end



  -- sensorline1 = build_sensor_line(tableLine1StatSensors)
  -- sensorline2 = build_sensor_line(tableLine2StatSensors)
  -- debugPrint("SENSLINE: " .. sensorline1)
  -- debugPrint("SENSLINE: " .. sensorline2)


  -- if VoltsNow < 1 or volts > 1 then
  --   VoltsNow = volts
  -- end

end

-- ####################################################################
local function switchAnnounce()

-- switch state announce
for _, switchInfo in ipairs(thisModel.switchAnnounces) do
  --local switch, action = switchInfo[1], switchInfo[2]
  local switch = switchInfo[1]

  debugPrint(string.format("SWITCH: %s", switch))

  --local swidx = getSwitchIndex(switch)
  local swidx = switchIndexes[switch]

  debugPrint(string.format("SWITCH IDX: %s", swidx))

  local state = getValue(swidx)

  local optionscount = #switchInfo - 1

  -- -1024 0 1024
  -- -1024   1024

  local downval = 1 + 1
  local midval = 2 + 1
  local upval = 3 + 1

  if optionscount == 2 then
    downval = 1 + 1
    midval = 0
    upval = 2 + 1
  end

  if optionscount == 1 then
    downval = 0
    midval = 0
    upval = 1 + 1
  end


  debugPrint(string.format("SWITCH OPTIONS COUNT: %s", optionscount))

-- SWITCH: sf STATE: 1024 pre State: -1024 downval: 2 midval: 0 upval: 3


  if previousSwitchState[switch] ~= state or previousSwitchState[switch] == nil then

    --if previousSwitchState[switch] ~=  nil then
    --  debugPrint(string.format("SWITCH: %s STATE: %s pre State: %s downval: %s midval: %s upval: %s",  switch, state, previousSwitchState[switch],switchInfo[downval],switchInfo[midval],switchInfo[upval] ) )
  --
    --  end

    if state < 0 and downval ~= 0 then
      queueSysSound(switchInfo[downval], 0, priorizeSwitchAnnouncements)
      debugPrint(string.format("SWITCH: %s STATE: %s pre State: %s downval: %s midval: %s upval: %s Play: %s",  switch, state, previousSwitchState[switch],switchInfo[downval],switchInfo[midval],switchInfo[upval],switchInfo[downval] ) )
    elseif state > 0 and upval ~= 0 then
      queueSysSound(switchInfo[upval], 0, priorizeSwitchAnnouncements)
      debugPrint(string.format("SWITCH: %s STATE: %s pre State: %s downval: %s midval: %s upval: %s Play: %s",  switch, state, previousSwitchState[switch],switchInfo[downval],switchInfo[midval],switchInfo[upval],switchInfo[upval] ) )

    elseif midval ~= 0 then
      queueSysSound(switchInfo[midval], 0, priorizeSwitchAnnouncements)
      debugPrint(string.format("SWITCH: %s STATE: %s pre State: %s downval: %s midval: %s upval: %s Play: %s",  switch, state, previousSwitchState[switch],switchInfo[downval],switchInfo[midval],switchInfo[upval],switchInfo[midval] ) )

    end
  end


  --if ( state and not previousSwitchState[switch] ) or previousSwitchState[switch] == nil then
  -- if state then
  --   if not previousSwitchState[switch] or previousSwitchState[switch] == nil then
  --     playFile(action..".wav", 5)
  --   end
  -- end

  previousSwitchState[switch] = state

  

end

end




-- ####################################################################
local function bg_func()


  --local sdf = getValue("Cels")
--
  --debugPrint("Updated Sensor Values TEST: ", sdf)
  



processQueue()

checkForTelemetry()

initializeAndCheckAllSensorIds()

switchAnnounce()


  reset_if_needed() -- test if the reset switch is toggled, if so then reset all internal flags
  

 if statusTele and allSensorsValid then -- if we have no telemetry .... don't waste time doing anything that requires telemetry

  currentContext = contexts[currentContextIndex]

  debugPrint("Current Context:", currentContext)

  --updateSensorValues(thisModel.VoltageSensor.main.cellMissing)

  updateSensorValues(currentContext)


  check_for_missing_cells(currentContext)

  if thisModel.VoltageSensor[currentContext].cellMissing == 0 then -- if cell number is fine we have got voltage and can do the rest of the checks

  -- check_for_full_battery(currentSensorVoltageValue[currentContext], BatNotFullThresh[typeBattery[currentContext]], countCell[currentContext], batTypeLowHighValues[typeBattery[currentContext]][1], batTypeLowHighValues[typeBattery[currentContext]][2])
  -- check_for_full_battery(currentContext)

  check_cell_delta_voltage(currentContext)

  end



  if thisModel.VoltageSensor.receiver.CellsDetected and thisModel.VoltageSensor.main.CellsDetected then -- sanity checks passed ... we can move to normal operation and switch the status widget
   batCheckPassed = true
   pfStatus.text = "OK"
   pfStatus.color = GREEN
   else
    pfStatus.text = "Check Battery"
    pfStatus.color = YELLOW
    batCheckPassed = false
  end


end -- end of if telemetry

doAnnouncements(currentContext)

if statusTele and allSensorsValid then
      -- Update the index to cycle through the contexts using the modulo operator
      currentContextIndex = (currentContextIndex % #contexts) + 1
end


end

-- ####################################################################
local function getPercentColor(cpercent, battery)
  -- This function returns green at 100%, red bellow 30% and graduate in between

  --local warn = batTypeWarnCritThresh[battype][1] 
  local warn = battery.warningThreshold



  if cpercent < warn then
    return lcd.RGB(0xff, 0, 0)
  else
    g = math.floor(0xdf * cpercent / 100)
    r = 0xdf - g
    return lcd.RGB(r, g, 0)
  end
end

-- ####################################################################
local function formatCellVoltage(voltage)
  if type(voltage) == "number" then
    vColor, blinking = Color, 0
    if voltage < 3.7 then vColor, blinking = RED, BLINK end
    return string.format("%.2f", voltage), vColor, blinking
  else
    return "------", Color, 0
  end
end

-- ####################################################################
local function drawCellVoltage(wgt, cellResult)
  -- Draw the voltage table for the current/low cell voltages
  -- this should use ~1/4 screen
  cellResult = getValue( VoltageSensor )
  if (type(cellResult) ~= "table") then
   cellResult = {}
  end

  for i=1, 7, 2 do
    cell1, cell1Color, cell1Blink = formatCellVoltage(cellResult[i])
    history1, history1Color, history1Blink = formatCellVoltage(VoltageHistory[i])
    cell2, cell2Color, cell2Blink = formatCellVoltage(cellResult[i+1])
    history2, history2Color, history2Blink = formatCellVoltage(VoltageHistory[i+1])

    -- C1: C.cc/H.hh  C2: C.cc/H.hh
    lcd.drawText(wgt.zone.x, wgt.zone.y  + 10*(i-1), string.format("C%d:", i), Color)
    lcd.drawText(wgt.zone.x + 25, wgt.zone.y  + 10*(i-1), string.format("%s", cell1), cell1Color+cell1Blink)
    lcd.drawText(wgt.zone.x + 55, wgt.zone.y  + 10*(i-1), string.format("/"), Color)
    lcd.drawText(wgt.zone.x + 60, wgt.zone.y  + 10*(i-1), string.format("%s", history1), history1Color+history1Blink)

    lcd.drawText(wgt.zone.x + 100, wgt.zone.y  + 10*(i-1), string.format("C%d:", i+1), Color)
    lcd.drawText(wgt.zone.x + 125, wgt.zone.y  + 10*(i-1), string.format("%s", cell2), cell2Color+cell2Blink)
    lcd.drawText(wgt.zone.x + 155, wgt.zone.y  + 10*(i-1), string.format("/"), Color)
    lcd.drawText(wgt.zone.x + 160, wgt.zone.y  + 10*(i-1), string.format("%s", history2), history2Color+history2Blink)
  end
end

-- ####################################################################
local function drawBattery(xOrigin, yOrigin, percentage, wgt, battery)
    local myBatt = { ["x"] = xOrigin,
                     ["y"] = yOrigin,
                     ["w"] = 120,
                     ["h"] = 30,
                     ["segments_w"] = 15,
                     ["color"] = WHITE,
                     ["cath_w"] = 6,
                     ["cath_h"] = 18 }

  lcd.setColor(CUSTOM_COLOR, wgt.options.Color)

  if percentage > 0 then -- Don't blink
    BlinkWhenZero = 0
  else
    BlinkWhenZero = BLINK
  end

  FSIZE = 0
  --FSIZE = MIDSIZE
  
  -- fill batt
  lcd.setColor(CUSTOM_COLOR, getPercentColor(percentage, battery))
  lcd.drawGauge(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y, myBatt.w, myBatt.h, percentage, 100, CUSTOM_COLOR)

  -- draws bat
  lcd.setColor(CUSTOM_COLOR, WHITE)
  lcd.drawRectangle(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y, myBatt.w, myBatt.h, CUSTOM_COLOR, 2)
  lcd.drawFilledRectangle(wgt.zone.x + myBatt.x + myBatt.w,
          --wgt.zone.y + myBatt.h / 2 - myBatt.cath_h / 2,
          wgt.zone.y + myBatt.y + myBatt.cath_h / 2 - 2.5,
          myBatt.cath_w,
          myBatt.cath_h,
          CUSTOM_COLOR)
  lcd.drawText(wgt.zone.x + myBatt.x + 20, wgt.zone.y + myBatt.y + 5, string.format("%d%%", percentage), LEFT + FSIZE + CUSTOM_COLOR)

    -- draw values
  lcd.drawText(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y + 30,
          string.format("%d mAh", BatRemainmAh), FSIZE + Color + BlinkWhenZero)
end

-- ####################################################################
local function drawNewBattery(xOrigin, yOrigin, context, wgt,  batCol, txtCol, size)

  local myBatt = { ["x"] = xOrigin,
                   ["y"] = yOrigin,
                   ["w"] = 120,
                   ["h"] = 30,
                   ["segments_w"] = 15,
                   ["color"] = WHITE,
                   ["cath_w"] = 4,
                   ["font"] = 0,
                   ["cath_h"] = 18 }

if size == "x" then
  myBatt.h = 40
  myBatt.cath_w = 6
  myBatt.cath_h = 22
  myBatt.w = 160
  myBatt.font = MIDSIZE

end                   

local percentage = thisModel.VoltageSensor[context].PercRem
local battery = thisModel.battery[context]

--lcd.setColor(CUSTOM_COLOR, wgt.options.Color)

if percentage > 0 then -- Don't blink
  BlinkWhenZero = 0
else
  BlinkWhenZero = BLINK
end


-- fill batt
lcd.setColor(CUSTOM_COLOR, getPercentColor(percentage, battery))
lcd.drawGauge(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y, myBatt.w, myBatt.h, percentage, 100, CUSTOM_COLOR)

-- draws bat
--lcd.setColor(CUSTOM_COLOR, batCol)
lcd.drawRectangle(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y, myBatt.w, myBatt.h, batCol, 2)
lcd.drawFilledRectangle(wgt.zone.x + myBatt.x + myBatt.w,
        --wgt.zone.y + myBatt.h / 2 - myBatt.cath_h / 2,
        wgt.zone.y + myBatt.y + myBatt.cath_h / 2 - 2.5,
        myBatt.cath_w,
        myBatt.cath_h,
        batCol)

lcd.drawText(wgt.zone.x + myBatt.x + 20, wgt.zone.y + myBatt.y + 5, string.format("%d%%", percentage), LEFT + myBatt.font + batCol)

  -- draw values
lcd.drawText(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y + myBatt.h,
string.format("%d mAh used", thisModel.MahSensor[context].value), myBatt.font + txtCol + BlinkWhenZero) -- todo -- original line --below just for display testing
--"3456 mAh (8000)", myBatt.font + txtCol + BlinkWhenZero)
end


local function draw_sensor_line(wgt, sensor_line_data, x, y)
  local line_x = x

  for _, entry in ipairs(sensor_line_data) do
    local current_x = line_x

    -- Draw sensor name with primary color
    lcd.setColor(CUSTOM_COLOR, COLOR_THEME_PRIMARY1)
    lcd.drawText(current_x, y, entry.sensor_name .. " [", SMLSIZE)

    current_x = current_x + #entry.sensor_name * 6  -- Adjust spacing based on your font width

    -- Draw each value segment with its respective color
    for _, value_str in ipairs(entry.values) do
      lcd.setColor(CUSTOM_COLOR, value_str.color)
      lcd.drawText(current_x, y, value_str.text, SMLSIZE)

      current_x = current_x + #value_str.text * 6  -- Adjust spacing based on your font width
    end

    -- Add closing bracket with primary color
    lcd.setColor(CUSTOM_COLOR, COLOR_THEME_PRIMARY1)
    lcd.drawText(current_x, y, "]", SMLSIZE)

    -- Move to the next line (adjust the y position if needed)
    y = y + 12  -- Adjust vertical spacing as needed
  end
end




-- ####################################################################
local function refreshZoneTiny(wgt)
  -- This size is for top bar wgts
  --- Zone size: 70x39 1/8th top bar
  local myString = string.format("%d", BatRemainmAh)
  lcd.drawText(wgt.zone.x + wgt.zone.w -25, wgt.zone.y + 5, BatRemPer .. "%", RIGHT + SMLSIZE + CUSTOM_COLOR + BlinkWhenZero)
  lcd.drawText(wgt.zone.x + wgt.zone.w -25, wgt.zone.y + 20, myString, RIGHT + SMLSIZE + CUSTOM_COLOR + BlinkWhenZero)
  -- draw batt
  lcd.drawRectangle(wgt.zone.x + 50, wgt.zone.y + 9, 16, 25, CUSTOM_COLOR, 2)
  lcd.drawFilledRectangle(wgt.zone.x +50 + 4, wgt.zone.y + 7, 6, 3, CUSTOM_COLOR)
  local rect_h = math.floor(25 * BatRemPer / 100)
  lcd.drawFilledRectangle(wgt.zone.x +50, wgt.zone.y + 9 + 25 - rect_h, 16, rect_h, CUSTOM_COLOR + BlinkWhenZero)
end

-- ####################################################################
local function refreshZoneSmall(wgt)
  --- Size is 160x32 1/8th
  local myBatt = { ["x"] = 0, ["y"] = 0, ["w"] = 155, ["h"] = 35, ["segments_w"] = 25, ["color"] = WHITE, ["cath_w"] = 6, ["cath_h"] = 20 }

  -- draws bat
  lcd.setColor(CUSTOM_COLOR, WHITE)
  lcd.drawRectangle(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y, myBatt.w, myBatt.h, CUSTOM_COLOR, 2)

  -- fill batt
  lcd.setColor(CUSTOM_COLOR, getPercentColor(BatRemPer))
  lcd.drawGauge(wgt.zone.x + 2, wgt.zone.y + 2, myBatt.w - 4, wgt.zone.h, BatRemPer, 100, CUSTOM_COLOR)

  -- write text
  lcd.setColor(CUSTOM_COLOR, wgt.options.Color)
  local topLine = string.format("%d      %d%%", BatRemainmAh, BatRemPer)
  lcd.drawText(wgt.zone.x + 20, wgt.zone.y + 2, topLine, MIDSIZE + CUSTOM_COLOR + BlinkWhenZero)
end

-- ####################################################################
local function refreshZoneMedium(wgt)
  --- Size is 225x98 1/4th  (no sliders/trim)
  drawBattery(0,0, BatRemPer, wgt,typeBattery["receiver"])

  --drawBattery(270, 100, valueVoltsPercentRemaining["receiver"], wgt,typeBattery["receiver"] )


  --local myBatt = { ["x"] = 0, ["y"] = 0, ["w"] = 85, ["h"] = 35, ["segments_w"] = 15, ["color"] = WHITE, ["cath_w"] = 6, ["cath_h"] = 20 }
  --
  --lcd.setColor(CUSTOM_COLOR, wgt.options.Color)
  --
  --if BatRemPer > 0 then -- Don't blink
  --  BlinkWhenZero = 0
  --else
  --  BlinkWhenZero = BLINK
  --end
  --
  ---- fill batt
  --lcd.setColor(CUSTOM_COLOR, getPercentColor(BatRemPer))
  --lcd.drawGauge(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y, myBatt.w, myBatt.h, BatRemPer, 100, CUSTOM_COLOR)
  --
  ---- draws bat
  --lcd.setColor(CUSTOM_COLOR, WHITE)
  --lcd.drawRectangle(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y, myBatt.w, myBatt.h, CUSTOM_COLOR, 2)
  --lcd.drawFilledRectangle(wgt.zone.x + myBatt.x + myBatt.w, wgt.zone.y + myBatt.h / 2 - myBatt.cath_h / 2, myBatt.cath_w, myBatt.cath_h, CUSTOM_COLOR)
  --lcd.drawText(wgt.zone.x + myBatt.x + 20, wgt.zone.y + myBatt.y + 5, string.format("%d%%", BatRemPer), LEFT + MIDSIZE + CUSTOM_COLOR)
  --
  --  -- draw values
  --lcd.drawText(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y + 35,
  --        string.format("%d mAh", BatRemainmAh), DBLSIZE + CUSTOM_COLOR + BlinkWhenZero)

end

local function lcdText(text,width,height,fontsize,color,rowDirection,row,colDirection,column)

  local smallestStepY = 14
  local smallestStepX = 12
  local maxMaxCol = 19 -- for RM TX16S ! -- todo get screen maxsize somehow ?

  if     fontsize == "xl"  then FONT , fontpxl, lineSpaceing, colSpacing  = XXLSIZE , 72 , 6 , 19
  elseif fontsize == "x"   then FONT , fontpxl, lineSpaceing, colSpacing  = DBLSIZE , 32 , 5 , 18
  elseif fontsize == "l"   then FONT , fontpxl, lineSpaceing, colSpacing  = MIDSIZE , 24 , 4 , 17   -- <----
  elseif fontsize == "m"   then FONT , fontpxl, lineSpaceing, colSpacing  = 0       , 16 , 3 , 16
  else                          FONT , fontpxl, lineSpaceing, colSpacing  = SMLSIZE , 12 , 2 , 8
  end

 linex = 0
 liney = 0

 maxrow = math.floor(height / ( fontpxl + lineSpaceing ) )
 maxcol = math.floor(width / colSpacing )

 xStep = colSpacing
 yStep = fontpxl + lineSpaceing

 column = column - 1



  debugPrint("SCREEN: maxrow: " .. maxrow .. " maxcol: " .. maxcol .. " Size: " .. fontsize )

  if rowDirection == "b" then
    liney = (maxrow - row) * yStep
  else
    liney = yStep * ( row - 1)
  end


  if colDirection == "r" then
    linex = (maxcol - column) * colSpacing
  else
    linex = linex +  ( column * colSpacing )
  end


  lcd.drawText(linex, liney , text, FONT + color )



end


local function renderScreen(layout, width, height)
  local smallestStepY = 14
  local smallestStepX = 12

  local fontSizes = {
      xl = { FONT = XXLSIZE, fontpxl = 72, lineSpacing = 6, colSpacing = 19 },
      x  = { FONT = DBLSIZE, fontpxl = 32, lineSpacing = 5, colSpacing = 18 },
      l  = { FONT = MIDSIZE, fontpxl = 24, lineSpacing = 4, colSpacing = 17 },
      m  = { FONT = 0,       fontpxl = 16, lineSpacing = 3, colSpacing = 16 },
      s  = { FONT = SMLSIZE, fontpxl = 12, lineSpacing = 2, colSpacing = 8 }
  }





  local maxrow = math.floor(height / (fontSizes["l"].fontpxl + fontSizes["l"].lineSpacing))
  local maxcol = math.floor(width / fontSizes["l"].colSpacing)

  -- Define the starting positions
  local y = 0
  local x = 0

  -- Function to draw text with given parameters
  local function drawText(text, x, y, fontsize, color)
    local offsetX = x + 2 -- a little bit from left

      local fontData = fontSizes[fontsize]
      lcd.drawText(offsetX, y, text, fontData.FONT + color)
  end

  -- Function to draw a sensor line
  local function drawSensorLine(sensors, y)
      local offsetX = x + 2 -- a little bit from left
      for _, sensor in ipairs(sensors) do
          drawText(sensor.label, offsetX, y, "m", sensor.labelColor)
          drawText(sensor.value, offsetX + fontSizes["m"].colSpacing * 2, y, "m", sensor.valuecolor)
          offsetX = offsetX + fontSizes["m"].colSpacing * 6
      end
  end

  -- Function to draw a bottom sensor line with high and low values
  --local function drawBottomSensorLine(sensors, y)
  --    local offsetX = x + 1 -- a little bit from left
  --    for _, sensor in ipairs(sensors) do
  --        drawText(sensor.label, offsetX, y, "s", sensor.labelColor)
  --        drawText(":", offsetX + fontSizes["s"].colSpacing * 5, y, "s", WHITE)
  --        drawText("[", offsetX + fontSizes["s"].colSpacing * 6, y, "s", WHITE)
  --        drawText("L:", offsetX + fontSizes["s"].colSpacing * 7, y, "s", sensor.labelColor)
  --        drawText(sensor.lowValue, offsetX + fontSizes["s"].colSpacing * 9, y, "s", sensor.lowValueColor)
  --        drawText("H:", offsetX + fontSizes["s"].colSpacing * 13, y, "s", sensor.labelColor)
  --        drawText(sensor.highValue, offsetX + fontSizes["s"].colSpacing * 15, y, "s", sensor.highValueColor)
  --        drawText("]", offsetX + fontSizes["s"].colSpacing * 19, y, "s", WHITE)
  --        offsetX = offsetX + fontSizes["s"].colSpacing * 20
  --    end
  --end

  local function drawBottomSensorLine(sensors, y)
    local offsetX = x + 1 -- a little bit from left
    local totalSensors = #sensors
    local sensorsPerLine = 2
    local sensorWidth = width / sensorsPerLine

    for i, sensor in ipairs(sensors) do
        local currentLine = math.floor((i - 1) / sensorsPerLine)
        local colIndex = (i - 1) % sensorsPerLine
        local lineOffsetX = offsetX + colIndex * sensorWidth

        drawText(sensor.label, lineOffsetX, y, "s", sensor.labelColor)
        drawText("[", lineOffsetX + fontSizes["s"].colSpacing * 6, y, "s", WHITE)
        drawText("L:", lineOffsetX + fontSizes["s"].colSpacing * 7, y, "s", sensor.labelColor)
        drawText(sensor.lowValue, lineOffsetX + fontSizes["s"].colSpacing * 9, y, "s", sensor.lowValueColor)
        drawText("H:", lineOffsetX + fontSizes["s"].colSpacing * 15, y, "s", sensor.labelColor)
        drawText(sensor.highValue, lineOffsetX + fontSizes["s"].colSpacing * 17, y, "s", sensor.highValueColor)
        drawText("]", lineOffsetX + fontSizes["s"].colSpacing * 23, y, "s", WHITE)

        -- Move to the next line if it's a new set of sensors
        if colIndex == sensorsPerLine - 1 and i < totalSensors then
            y = y + fontSizes["s"].fontpxl + fontSizes["s"].lineSpacing
        end
    end
end

  -- Iterate through the layout and render each element
  for _, item in ipairs(layout) do
      if item.type == "header" then
          drawText(item.text, x, y, "l", item.color)
          y = y + fontSizes["l"].fontpxl + fontSizes["l"].lineSpacing
      elseif item.type == "sensorLine" then
          drawSensorLine(item.sensors, y)
          y = y + fontSizes["m"].fontpxl + fontSizes["m"].lineSpacing
      elseif item.type == "bottom" then
          drawBottomSensorLine(item.sensors, height - fontSizes["s"].fontpxl - fontSizes["s"].lineSpacing - 8) -- -8 to lift it from the bottom ... but should be adapted to screen height
          height = height - fontSizes["s"].fontpxl - fontSizes["s"].lineSpacing
      end
  end
end





local function preFlightStatusScreen(layout, width, height)
  local y = 0
  local xlineStart = 10
  local ylineStart = 25
  local ylineinc = 20
  local fontSizes = {
      l = { FONT = DBLSIZE, lineSpacing = 5 },
      m = { FONT = MIDSIZE, lineSpacing = 3 }
  }

  -- Helper function to draw text with given parameters
  local function drawText(text, x, y, fontsize, color, alignment)
      local fontData = fontSizes[fontsize]
      local textColor = color or WHITE  -- Default color if not provided
      local textAlignment = alignment or TEXT_LEFT  -- Default alignment if not provided
      lcd.drawText(x, y, text, fontData.FONT + textColor )
      y = y + fontData.lineSpacing
      return y
  end

  -- Iterate through the layout and render each element
  for _, item in ipairs(layout) do
      if item.type == "header" then
          y = drawText(item.text, xlineStart, y, "l", item.color, CENTER)
      elseif item.type == "modelInfo" then
          -- Draw model name and image
          lcd.drawText(width / 2, y, item.modelName, MIDSIZE + COLOR_THEME_PRIMARY1 + DBLSIZE + CENTER)
          lcd.drawBitmap(item.modelImage, width / 2 - 25, y + 20, 50)
          y = y + 70  -- Adjust based on image size and spacing
      elseif item.type == "sensorValue" then
          y = drawText(item.label, xlineStart, y, "m", item.labelColor)
          lcd.drawText(xlineStart + 100, y - fontSizes["m"].lineSpacing, ":", COLOR_THEME_PRIMARY2 + BOLD)
          lcd.drawText(xlineStart + 120, y - fontSizes["m"].lineSpacing, item.value, WHITE + BOLD)
      elseif item.type == "statusMessage" then
          -- Render status message with wrapping
          local lines = lcd.drawText(xlineStart, y, item.text, MIDSIZE + item.color , width - 20)
          y = y + lines * (MIDSIZE.lineSpacing + 1)  -- Adjust based on line spacing and wrapping
      end
  end
end

local function preFlightStatusScreen(layout, width, height)

  

  local headerSpacing = 0

  local firstHeader = true

  local fontSizes = {
      -- xl = { FONT = XXLSIZE, fontpxl = 72, lineSpacing = 6, colSpacing = 19 },
      -- x  = { FONT = DBLSIZE, fontpxl = 32, lineSpacing = 5, colSpacing = 18 },
      l  = { FONT = MIDSIZE, fontpxl = 24, lineSpacing = 4, colSpacing = 17 },
      m  = { FONT = 0,       fontpxl = 16, lineSpacing = 3, colSpacing = 16 },
      s  = { FONT = SMLSIZE, fontpxl = 12, lineSpacing = 2, colSpacing = 8 }
  }


if height >= 272 then

  fontSizes = {
    -- xl = { FONT = XXLSIZE, fontpxl = 72, lineSpacing = 6, colSpacing = 19 },
    l  = { FONT = DBLSIZE, fontpxl = 32, lineSpacing = 4, colSpacing = 18 },
    m  = { FONT = MIDSIZE, fontpxl = 24, lineSpacing = 3, colSpacing = 22 }, -- <<
    s  = { FONT = 0,       fontpxl = 16, lineSpacing = 2, colSpacing = 10 },
    -- ss  = { FONT = SMLSIZE, fontpxl = 12, lineSpacing = 2, colSpacing = 8 }
}

headerSpacing = 10
 
end




  -- Define the starting positions
  local y = 0
  local x = 0

  local xlineStart = x
  local ylineStart = x

  -- Function to draw text with given parameters
  local function drawText(text, x, y, fontsize, color)
    debugPrint("SCRN:" .. text)
    local offsetX = x + 2 -- a little bit from left
          local fontData = fontSizes[fontsize]
      lcd.drawText(offsetX, y, text, fontData.FONT + color)

      y = y + headerSpacing

  end

  -- Function to draw a sensor line
  local function drawKeyValLine(key, value, keycol, valcol, y)
    local offsetX = x + 2 -- a little bit from left
    --for _, sensor in ipairs(sensors) do
        drawText(key  , offsetX, y, "s", keycol)
        drawText(":", offsetX + fontSizes["s"].colSpacing * 10, y, "s", WHITE)
        drawText(value, offsetX + fontSizes["s"].colSpacing * 11, y, "s", valcol)
        --offsetX = offsetX + fontSizes["m"].colSpacing * 6
    --end
end



-- string.format("%.2f", sensor.val1)

  -- Iterate through the layout and render each element
  for _, item in ipairs(layout) do
      if item.type == "header" then
        if not firstHeader then y = y + headerSpacing end
          drawText(item.text, x, y, "m", item.color)
          firstHeader = false
          y = y + fontSizes["m"].fontpxl + fontSizes["m"].lineSpacing
        elseif item.type == "modelInfo" then
          -- Draw model name and image
          drawText(item.modelName, width / 2, ylineStart, "l", item.labelColor)
          lcd.drawBitmap(item.modelImage, width / 2 , ylineStart + fontSizes["l"].fontpxl + fontSizes["l"].lineSpacing, 50)
          --y = y + 70  -- Adjust based on image size and spacing          
      elseif item.type == "keyvalue" then
        --drawKeyValue(item.keyvalue, y)
        --  y = y + fontSizes["m"].fontpxl + fontSizes["m"].lineSpacing

        drawKeyValLine(item.label, item.value, item.labelColor, item.valuecolor , y)
        y = y + fontSizes["s"].fontpxl + fontSizes["s"].lineSpacing

        --drawText(item.label, xlineStart, y, "m", item.labelColor)
        --lcd.drawText(xlineStart + 100, y - fontSizes["m"].lineSpacing, ":", COLOR_THEME_PRIMARY2 + BOLD)
        --lcd.drawText(xlineStart + 120, y - fontSizes["m"].lineSpacing, item.value, WHITE + BOLD)
        elseif item.type == "statusMessage" then
          drawText(item.status.text, x, y, "s", item.status.color)
          -- Render status message with wrapping
          --local lines = lcd.drawText(xlineStart, y, item.text, MIDSIZE + item.color , width - 20)
          --y = y + lines * (MIDSIZE.lineSpacing + 1)  -- Adjust based on line spacing and wrapping
          --y = y + fontSizes["m"].fontpxl + fontSizes["m"].lineSpacing
      end
  end
end




local function renderScreen(layout, width, height)
  local smallestStepY = 14
  local smallestStepX = 12

  local headerSpacing = 0

  local firstHeader = true

  local fontSizes = {
      -- xl = { FONT = XXLSIZE, fontpxl = 72, lineSpacing = 6, colSpacing = 19 },
      -- x  = { FONT = DBLSIZE, fontpxl = 32, lineSpacing = 5, colSpacing = 18 },
      l  = { FONT = MIDSIZE, fontpxl = 24, lineSpacing = 4, colSpacing = 17 },
      m  = { FONT = 0,       fontpxl = 16, lineSpacing = 3, colSpacing = 16 },
      s  = { FONT = SMLSIZE, fontpxl = 12, lineSpacing = 2, colSpacing = 8 }
  }


if height >= 272 then

  fontSizes = {
    -- xl = { FONT = XXLSIZE, fontpxl = 72, lineSpacing = 6, colSpacing = 19 },
    l  = { FONT = DBLSIZE, fontpxl = 32, lineSpacing = 4, colSpacing = 18 },
    m  = { FONT = MIDSIZE, fontpxl = 24, lineSpacing = 3, colSpacing = 22 }, -- <<
    s  = { FONT = 0,       fontpxl = 16, lineSpacing = 2, colSpacing = 10 },
    -- ss  = { FONT = SMLSIZE, fontpxl = 12, lineSpacing = 2, colSpacing = 8 }
}

headerSpacing = 15
 
end


  local maxrow = math.floor(height / (fontSizes["l"].fontpxl + fontSizes["l"].lineSpacing))
  local maxcol = math.floor(width / fontSizes["l"].colSpacing)

  -- Define the starting positions
  local y = 0
  local x = 0

  -- Function to draw text with given parameters
  local function drawText(text, x, y, fontsize, color)
    debugPrint("SCRN:" .. text)
    local offsetX = x + 2 -- a little bit from left
          local fontData = fontSizes[fontsize]
      lcd.drawText(offsetX, y, text, fontData.FONT + color)

      y = y + headerSpacing

  end

  -- Function to draw a sensor line
  local function drawSensorLine(sensors, y)
      local offsetX = x + 2 -- a little bit from left
      for _, sensor in ipairs(sensors) do
          drawText(sensor.label, offsetX, y, "m", sensor.labelColor)
          drawText(sensor.value, offsetX + fontSizes["m"].colSpacing * 2, y, "m", sensor.valuecolor)
          offsetX = offsetX + fontSizes["m"].colSpacing * 6
      end
  end

  -- Function to draw a bottom sensor line with high and low values
  --local function drawBottomSensorLine(sensors, y)
  --    local offsetX = x + 1 -- a little bit from left
  --    for _, sensor in ipairs(sensors) do
  --        drawText(sensor.label, offsetX, y, "s", sensor.labelColor)
  --        drawText(":", offsetX + fontSizes["s"].colSpacing * 5, y, "s", WHITE)
  --        drawText("[", offsetX + fontSizes["s"].colSpacing * 6, y, "s", WHITE)
  --        drawText("L:", offsetX + fontSizes["s"].colSpacing * 7, y, "s", sensor.labelColor)
  --        drawText(sensor.lowValue, offsetX + fontSizes["s"].colSpacing * 9, y, "s", sensor.lowValueColor)
  --        drawText("H:", offsetX + fontSizes["s"].colSpacing * 13, y, "s", sensor.labelColor)
  --        drawText(sensor.highValue, offsetX + fontSizes["s"].colSpacing * 15, y, "s", sensor.highValueColor)
  --        drawText("]", offsetX + fontSizes["s"].colSpacing * 19, y, "s", WHITE)
  --        offsetX = offsetX + fontSizes["s"].colSpacing * 20
  --    end
  --end

--   local function drawBottomSensorLine(sensors, y)
--     local offsetX = x + 1 -- a little bit from left
--     local totalSensors = #sensors
--     local sensorsPerLine = 2
--     local sensorWidth = width / sensorsPerLine
-- 
--     for i, sensor in ipairs(sensors) do
--         local currentLine = math.floor((i - 1) / sensorsPerLine)
--         local colIndex = (i - 1) % sensorsPerLine
--         local lineOffsetX = offsetX + colIndex * sensorWidth
-- 
--         drawText(sensor.label, lineOffsetX, y, "s", sensor.labelColor)
--         drawText("[", lineOffsetX + fontSizes["s"].colSpacing * 6, y, "s", WHITE)
--         drawText("L:", lineOffsetX + fontSizes["s"].colSpacing * 7, y, "s", sensor.labelColor)
--         drawText(sensor.lowValue, lineOffsetX + fontSizes["s"].colSpacing * 9, y, "s", sensor.lowValueColor)
--         drawText("H:", lineOffsetX + fontSizes["s"].colSpacing * 15, y, "s", sensor.labelColor)
--         drawText(sensor.highValue, lineOffsetX + fontSizes["s"].colSpacing * 17, y, "s", sensor.highValueColor)
--         drawText("]", lineOffsetX + fontSizes["s"].colSpacing * 23, y, "s", WHITE)
-- 
--         -- Move to the next line if it's a new set of sensors
--         if colIndex == sensorsPerLine - 1 and i < totalSensors then
--             y = y + fontSizes["s"].fontpxl + fontSizes["s"].lineSpacing
--         end
--     end
-- end

local function drawBottomSensorLine(sensors, y)
  local offsetX = x + 1
  local totalSensors = #sensors
  local sensorsPerLine = 2
  local sensorWidth = width / sensorsPerLine


  for i = 1, totalSensors do

    if height <= 168 and i > 4 then 
      break
    end

      local sensor = sensors[i]
      local currentLine = math.floor((i - 1) / sensorsPerLine)
      local colIndex = (i - 1) % sensorsPerLine
      local lineOffsetX = offsetX + colIndex * sensorWidth

      drawText(sensor.name, lineOffsetX, y - currentLine * (fontSizes["s"].fontpxl + fontSizes["s"].lineSpacing), "s", COLOR_THEME_SECONDARY2)
      drawText("[", lineOffsetX + fontSizes["s"].colSpacing * 6, y - currentLine * (fontSizes["s"].fontpxl + fontSizes["s"].lineSpacing), "s", WHITE)
      drawText(sensor.val1prefix, lineOffsetX + fontSizes["s"].colSpacing * 7, y - currentLine * (fontSizes["s"].fontpxl + fontSizes["s"].lineSpacing), "s", WHITE)
      drawText(sensor.val1 .. sensor.unit, lineOffsetX + fontSizes["s"].colSpacing * 9, y - currentLine * (fontSizes["s"].fontpxl + fontSizes["s"].lineSpacing), "s", sensor.val1Color)
      drawText(sensor.val2prefix, lineOffsetX + fontSizes["s"].colSpacing * 15, y - currentLine * (fontSizes["s"].fontpxl + fontSizes["s"].lineSpacing), "s", WHITE)
      drawText(sensor.val2 .. sensor.unit, lineOffsetX + fontSizes["s"].colSpacing * 17, y - currentLine * (fontSizes["s"].fontpxl + fontSizes["s"].lineSpacing), "s", sensor.val2Color)
      drawText("]", lineOffsetX + fontSizes["s"].colSpacing * 23, y - currentLine * (fontSizes["s"].fontpxl + fontSizes["s"].lineSpacing), "s", WHITE)

      if colIndex == sensorsPerLine - 1 and i < totalSensors then
          y = y -  fontSizes["s"].lineSpacing
      end
  end
end

-- string.format("%.2f", sensor.val1)

  -- Iterate through the layout and render each element
  for _, item in ipairs(layout) do
      if item.type == "header" then
        if not firstHeader then y = y + headerSpacing end
          drawText(item.text, x, y, "l", item.color)
          firstHeader = false
          y = y + fontSizes["l"].fontpxl + fontSizes["l"].lineSpacing
      elseif item.type == "sensorLine" then
          drawSensorLine(item.sensors, y)
          y = y + fontSizes["m"].fontpxl + fontSizes["m"].lineSpacing
      elseif item.type == "bottom" then
          drawBottomSensorLine(item.sensors, height - fontSizes["s"].fontpxl - fontSizes["s"].lineSpacing - 5) -- -8 to lift it from the bottom ... but should be adapted to screen height
          -- height = height - fontSizes["s"].fontpxl - fontSizes["s"].lineSpacing
      end
  end
end




-- ####################################################################
local function refreshZoneLarge(wgt)
  --- Size is 192x152 1/2
  lcd.setColor(CUSTOM_COLOR, wgt.options.Color)
  
  fontSize = 10

  debugPrint("WIDGET:", BatRemPer)
  
    if BatRemPer > 0 then -- Don't blink
    BlinkWhenZero = 0
  else
    BlinkWhenZero = BLINK
  end
  lcd.drawText(wgt.zone.x + 5, wgt.zone.y + fontSize, "BATTERY LEFT", SHADOWED)
  lcd.setColor(CUSTOM_COLOR, getPercentColor(BatRemPer,typeBattery["receiver"]))
  lcd.drawText(wgt.zone.x + 5, wgt.zone.y + fontSize + 25, round(BatRemPer).."%" , DBLSIZE + SHADOWED + BlinkWhenZero)
  lcd.drawText(wgt.zone.x + 5, wgt.zone.y + fontSize + 55, math.floor(BatRemainmAh).."mAh" , DBLSIZE + SHADOWED + BlinkWhenZero)

  lcd.setColor(CUSTOM_COLOR, wgt.options.Color)
  lcd.drawRectangle((wgt.zone.x - 1) , (wgt.zone.y + (wgt.zone.h - 31)), (wgt.zone.w + 2), 32, 0)
  lcd.setColor(CUSTOM_COLOR, getPercentColor(BatRemPer,typeBattery["receiver"]))
  lcd.drawGauge(wgt.zone.x , (wgt.zone.y + (wgt.zone.h - 30)), wgt.zone.w, 30, BatRemPer, 100, BlinkWhenZero)
end

-- ####################################################################

-- local function refreshZoneXLarge(wgt)
--   --- Size is 390x172 1/1
--   --- Size is 460x252 1/1 (no sliders/trim/topbar)
--   lcd.setColor(CUSTOM_COLOR, wgt.options.Color)
--   local CUSTOM_COLOR = WHITE
--   fontSize = 10
-- 
--   if BatRemPer > 0 then -- Don't blink
--     BlinkWhenZero = 0
--   else
--     BlinkWhenZero = BLINK
--   end
-- 
--   -- Draw the top-left 1/4 of the screen
--   drawCellVoltage(wgt, cellResult)
-- 
--   -- Draw the bottom-left 1/4 of the screen
--   drawBattery(0, 100, wgt)
-- 
--   -- Draw the top-right 1/4 of the screen
--   --lcd.drawText(wgt.zone.x + 270, wgt.zone.y + -5, string.format("%.2fV", VoltsNow), DBLSIZE + Color)
--   lcd.drawText(wgt.zone.x + 210, wgt.zone.y + -5, "Current/Max", DBLSIZE + Color + SHADOWED)
--   amps = getValue( CurrentSensor )
--   --lcd.drawText(wgt.zone.x + 270, wgt.zone.y + 25, string.format("%.1fA", amps), DBLSIZE + Color)
--   lcd.drawText(wgt.zone.x + 210, wgt.zone.y + 30, string.format("%.0fA/%.0fA", amps, MaxAmps), MIDSIZE + Color)
--   watts = math.floor(amps * VoltsNow)
-- 
--   if type(MaxWatts) == "string" then
--     sMaxWatts = MaxWatts
--   elseif type(MaxWatts) == "number" then
--     sMaxWatts = string.format("%.0f", MaxWatts)
--   end
--   lcd.drawText(wgt.zone.x + 210, wgt.zone.y + 55, string.format("%.0fW/%sW", watts, sMaxWatts), MIDSIZE + Color)
-- 
--   -- Draw the bottom-right of the screen
--   --lcd.drawText(wgt.zone.x + 190, wgt.zone.y + 85, string.format("%sW", MaxWatts), XXLSIZE + Color)
--   lcd.drawText(wgt.zone.x + 185, wgt.zone.y + 85, string.format("%.2fV", VoltsNow), XXLSIZE + Color)
-- 
--   --lcd.drawText(wgt.zone.x + 5, wgt.zone.y + fontSize, "BATTERY LEFT", SHADOWED)
--   --lcd.setColor(CUSTOM_COLOR, getPercentColor(BatRemPer))
--   --lcd.drawText(wgt.zone.x + 5, wgt.zone.y + fontSize + 25, round(BatRemPer).."%" , DBLSIZE + SHADOWED + BlinkWhenZero)
--   --lcd.drawText(wgt.zone.x + 5, wgt.zone.y + fontSize + 55, math.floor(BatRemainmAh).."mAh" , DBLSIZE + SHADOWED + BlinkWhenZero)
--   --
--   --lcd.setColor(CUSTOM_COLOR, wgt.options.Color)
--   --lcd.drawRectangle((wgt.zone.x - 1) , (wgt.zone.y + (wgt.zone.h - 31)), (wgt.zone.w + 2), 32, 0)
--   --lcd.setColor(CUSTOM_COLOR, getPercentColor(BatRemPer))
--   --lcd.drawGauge(wgt.zone.x , (wgt.zone.y + (wgt.zone.h - 30)), wgt.zone.w, 30, BatRemPer, 100, BlinkWhenZero)
-- end

local function refreshZoneXLarge(wgt)
  --- Size is 390x172 1/1
  --- Size is 460x252 1/1 (no sliders/trim/topbar)
  lcd.setColor(CUSTOM_COLOR, wgt.options.Color)
  local CUSTOM_COLOR = WHITE
  fontSize = 10

  if BatRemPer > 0 then -- Don't blink
    BlinkWhenZero = 0
  else
    BlinkWhenZero = BLINK
  end

  if type(thisModel.VoltageSensor.main.CurVolt) ~= "number" or thisModel.VoltageSensor.main.CurVolt == 0 then -- Blink
    mainVoltBlink = BLINK
  else
    mainVoltBlink = 0
  end

  if type(thisModel.CurrentSensor.main.CurAmp) ~= "number" or thisModel.CurrentSensor.main.CurAmp == 0 then -- Blink
    mainCurrentBlink = BLINK
  else
    mainCurrentBlink = 0
  end


  if type(thisModel.VoltageSensor.receiver.CurVolt) ~= "number" or thisModel.VoltageSensor.receiver.CurVolt == 0 then -- Blink
    rxVoltBlink = BLINK
  else
    rxVoltBlink = 0
  end

  if type(thisModel.CurrentSensor.receiver.CurAmp) ~= "number" or thisModel.CurrentSensor.receiver.CurAmp == 0 then -- Blink
    rxCurrentBlink = BLINK
  else
    rxCurrentBlink = 0
  end

testing = true



if testing then

  x = 0
  y = 0
  w = wgt.zone.w
  h = wgt.zone.h
  hw = math.floor(w / 2)
  hh = math.floor(h / 2)

  dhw = math.floor(hw / 2)
  dhh = math.floor(hh / 2)

  ddhw = math.floor(dhw / 2) -- or w / 8
  ddhh = math.floor(dhh / 2) -- or h / 8

  line1 = y
  line2 = y +   ddhh
  line3 = y + ( ddhh * 2 )
  line4 = y + ( ddhh * 3 )
  line5 = y + ( ddhh * 4 )
  line6 = y + ( ddhh * 5 )
  line7 = y + ( ddhh * 6 )
  line8 = y + ( ddhh * 7 )

  col1 = x
  col2 = x +   ddhw
  col3 = x + ( ddhw * 2 )
  col4 = x + ( ddhw * 3 )
  col5 = x + ( ddhw * 4 )
  col6 = x + ( ddhw * 5 )
  col7 = x + ( ddhw * 6 )
  col8 = x + ( ddhw * 7 )

  
  local FONT_38 = XXLSIZE -- 38px -- 72
  local FONT_16 = DBLSIZE -- 16px -- 32
  local FONT_12 = MIDSIZE -- 12px -- 24
  local FONT_8 = 0 -- Default 8px -- 16
  local FONT_6 = SMLSIZE -- 6px --   12 -- 14

  debugPrint("SCREEN: x: ".. x .. " Y: " .. y .. " w: " .. w .. " h: " .. h)
  debugPrint("SCREEN: hw: ".. hw .. " hh: " .. hh .. " dhw: ".. dhw .. " dhh: " .. dhh )
  debugPrint("SCREEN: ddhw: ".. ddhw .. " ddhh: " .. ddhh  )

  lcd.drawFilledRectangle(0, 0, w, h, BLACK, 5)



  if batCheckPassed or not ShowPreFlightStatus then




  -- lcdText("RpM [H: 3200 p: 2601]",w,h,"s",WHITE,"t",1 ,"l",1)
  -- lcdText("RpM [H: 3200 p: 2602]",w,h,"s",WHITE,"t",2 ,"l",1)
  -- lcdText("RpM [H: 3200 p: 2603]",w,h,"s",WHITE,"t",3 ,"l",1)
  -- lcdText("RpM [H: 3200 p: 2604]",w,h,"s",WHITE,"t",4 ,"l",1)
  -- lcdText("RpM [H: 3200 p: 2605]",w,h,"s",WHITE,"t",5 ,"l",1)
  -- lcdText("RpM [H: 3200 p: 2606]",w,h,"s",WHITE,"t",6 ,"l",1)
  -- lcdText("RpM [H: 3200 p: 2607]",w,h,"s",WHITE,"t",7 ,"l",1)
  -- lcdText("RpM [H: 3200 p: 2608]",w,h,"s",WHITE,"t",8 ,"l",1)

  -- lcdText("RpM [H: 3200 p: 2609]",w,h,"s",WHITE,"t",9 ,"l",1)
  -- lcdText("RpM [H: 3200 p: 2610]",w,h,"s",WHITE,"t",10,"l",1)
  -- lcdText("RpM [H: 3200 p: 2611]",w,h,"s",WHITE,"t",11,"l",1)
  -- lcdText("RpM [H: 3200 p: 2612]",w,h,"s",WHITE,"t",12,"l",1)
  -- lcdText("RpM [H: 3200 p: 2613]",w,h,"s",WHITE,"t",13,"l",1)
  -- lcdText("RpM [H: 3200 p: 2614]",w,h,"s",WHITE,"t",14,"l",1)
  -- lcdText("RpM [H: 3200 p: 2615]",w,h,"s",WHITE,"t",15,"l",1)
  -- lcdText("RpM [H: 3200 p: 2616]",w,h,"s",WHITE,"t",16,"l",1)

-- works --     lcdText("Main",w,h,"l",  COLOR_THEME_SECONDARY2,"t",1,"l",2)
-- works --   
-- works --     lcdText("C:",w,h,"m",  COLOR_THEME_SECONDARY2,"t",3,"l",2)
-- works --     lcdText("54.24V",w,h,"m",               GREEN,"t",3,"l",3)
-- works --   
-- works --     lcdText("L:",w,h,"m",  COLOR_THEME_SECONDARY2,"t",3,"l",7)
-- works --     lcdText("54.24V",w,h,"m",                 RED,"t",3,"l",8)
-- works --   
-- works --     lcdText("C:",w,h,"m",  COLOR_THEME_SECONDARY2,"t",4,"l",2)
-- works --     lcdText("54.24V",w,h,"m",               GREEN,"t",4,"l",3)
-- works --   
-- works --     lcdText("L:",w,h,"m",  COLOR_THEME_SECONDARY2,"t",4,"l",7)
-- works --     lcdText("54.24V",w,h,"m",                 RED,"t",4,"l",8)
-- works --   
-- works --   
-- works --     lcdText("Receiver",w,h,"l",  COLOR_THEME_SECONDARY2,"t",4,"l",2)
-- works --   
-- works --     lcdText("C:",w,h,"m",  COLOR_THEME_SECONDARY2,"t",7,"l",2)
-- works --     lcdText("54.24V",w,h,"m",               GREEN,"t",7,"l",3)
-- works --   
-- works --     lcdText("L:",w,h,"m",  COLOR_THEME_SECONDARY2,"t",7,"l",7)
-- works --     lcdText("54.24V",w,h,"m",                 RED,"t",7,"l",8)
-- works --   
-- works --     lcdText("C:",w,h,"m",  COLOR_THEME_SECONDARY2,"t",8,"l",2)
-- works --     lcdText("54.24V",w,h,"m",               GREEN,"t",8,"l",3)
-- works --   
-- works --     lcdText("L:",w,h,"m",  COLOR_THEME_SECONDARY2,"t",8,"l",7)
-- works --     lcdText("54.24V",w,h,"m",                 RED,"t",8,"l",8)
-- works --   
-- works --   
-- works --     
-- works --     --lcdText("L: 54.24V",w,h,"m",  COLOR_THEME_SECONDARY2,"t",3,"l",7)
-- works --   
-- works --   
-- works --     lcdText("RPM:",w,h,"s",   COLOR_THEME_SECONDARY2,"b",2,"l",1)
-- works --     lcdText("[",w,h,"s",      COLOR_THEME_SECONDARY1,"b",2,"l",6)
-- works --     lcdText("L:",w,h,"s",          COLOR_THEME_FOCUS,"b",2,"l",7)
-- works --     lcdText("3000",w,h,"s",                      RED,"b",2,"l",9)
-- works --     lcdText("H:",w,h,"s",          COLOR_THEME_FOCUS,"b",2,"l",13)
-- works --     lcdText("3000",w,h,"s",                    GREEN,"b",2,"l",15)
-- works --     lcdText("]",w,h,"s",      COLOR_THEME_SECONDARY1,"b",2,"l",19)
-- works --    
-- works --     lcdText("RPM:",w,h,"s",   COLOR_THEME_SECONDARY2,"b",2,"l",20)
-- works --     lcdText("[",w,h,"s",      COLOR_THEME_SECONDARY1,"b",2,"l",25)
-- works --     lcdText("L:",w,h,"s",          COLOR_THEME_FOCUS,"b",2,"l",26)
-- works --     lcdText("3000",w,h,"s",                      RED,"b",2,"l",28)
-- works --     lcdText("H:",w,h,"s",          COLOR_THEME_FOCUS,"b",2,"l",32)
-- works --     lcdText("3000",w,h,"s",                    GREEN,"b",2,"l",34)
-- works --     lcdText("]",w,h,"s",      COLOR_THEME_SECONDARY1,"b",2,"l",38)
-- works --   
-- works --     lcdText("RPM:",w,h,"s",   COLOR_THEME_SECONDARY2,"b",2,"l",39)
-- works --     lcdText("[",w,h,"s",      COLOR_THEME_SECONDARY1,"b",2,"l",44)
-- works --     lcdText("L:",w,h,"s",          COLOR_THEME_FOCUS,"b",2,"l",45)
-- works --     lcdText("3000",w,h,"s",                      RED,"b",2,"l",47)
-- works --     lcdText("H:",w,h,"s",          COLOR_THEME_FOCUS,"b",2,"l",51)
-- works --     lcdText("3000",w,h,"s",                    GREEN,"b",2,"l",53)
-- works --     lcdText("]",w,h,"s",      COLOR_THEME_SECONDARY1,"b",2,"l",57)

--print("GFI:", sensorVoltage["main"].unit)
-- Example usage

local screenLayout = {
  { type = "header", text = "Main", color = COLOR_THEME_SECONDARY2 },
  { type = "sensorLine", sensors = {
      { label = "C:", value = thisModel.VoltageSensor.main.CurVolt     .. "V", labelColor = COLOR_THEME_FOCUS, valuecolor = GREEN },
      { label = "L:", value = thisModel.VoltageSensor.main.LowestVolt  .. "V", labelColor = COLOR_THEME_FOCUS, valuecolor = RED }
  }},
  { type = "sensorLine", sensors = {
      { label = "C:", value = thisModel.CurrentSensor.main.CurAmp     .. "A", labelColor = COLOR_THEME_FOCUS, valuecolor = GREEN },
      { label = "H:", value = thisModel.CurrentSensor.main.HighestAmp .. "A", labelColor = COLOR_THEME_FOCUS, valuecolor = RED }
  }},
  { type = "header", text = "Receiver", color = COLOR_THEME_SECONDARY2 },
  { type = "sensorLine", sensors = {
      { label = "C:", value = thisModel.VoltageSensor.receiver.CurVolt     .. "V", labelColor = COLOR_THEME_FOCUS, valuecolor = GREEN },
      { label = "L:", value = thisModel.VoltageSensor.receiver.LowestVolt  .. "V", labelColor = COLOR_THEME_FOCUS, valuecolor = RED }
  }},
  { type = "sensorLine", sensors = {
      { label = "C:", value = thisModel.CurrentSensor.receiver.CurAmp     .. "A", labelColor = COLOR_THEME_FOCUS, valuecolor = GREEN },
      { label = "H:", value = thisModel.CurrentSensor.receiver.HighestAmp .. "A", labelColor = COLOR_THEME_FOCUS, valuecolor = RED }
  }},

}





-- for _, adlSensor in ipairs(thisModel.AdlSensors) do
-- 
--   -- debugPrint("SCRN Name:" .. adlSensor.name)
--   -- debugPrint("SCRN TEST:" .. adlSensor.sensors[1].sensorName)
--   -- debugPrint("SCRN VAL1:" .. adlSensor.sensors[1].value)
--   
--   local bottomSection = {
--       type = "bottom",
--       sensors = {
--           { name = adlSensor.name, unit = adlSensor.unit, val1 = adlSensor.sensors[1].value or 0 , val2 = adlSensor.sensors[2].value or 0 , val1Color = adlSensor.sensors[1].color, val2Color = adlSensor.sensors[2].color, val1prefix = adlSensor.sensors[1].prefix, val2prefix = adlSensor.sensors[2].prefix }
--       }
--   }
--   table.insert(screenLayout, bottomSection)
-- 
-- end



-- Create a single bottom section
local bottomSection = {
  type = "bottom",
  sensors = {}
}

-- Populate the bottom section dynamically from thisModel.AdlSensors
for _, adlSensor in ipairs(thisModel.AdlSensors) do
  table.insert(bottomSection.sensors, {
    name = adlSensor.name,
    unit = adlSensor.unit,
    val1prefix = adlSensor.sensors[1].prefix,
    val1 = format_number(adlSensor.sensors[1].value or 0),
    val1Color = adlSensor.sensors[1].color,
    val2prefix = adlSensor.sensors[2].prefix,
    val2 = format_number(adlSensor.sensors[2].value or 0),
    val2Color = adlSensor.sensors[2].color,
    })
end

-- Insert the bottom section into the screen layout
table.insert(screenLayout, bottomSection)

-- 


renderScreen(screenLayout, wgt.zone.w, wgt.zone.h)

if wgt.zone.h >= 272 then

-- local function drawNewBattery(xOrigin, yOrigin, percentage, wgt, battery, batCol, txtCol, size)

drawNewBattery(280, 25,  "main"     , wgt , COLOR_THEME_PRIMARY2, COLOR_THEME_ACTIVE, "x" )
drawNewBattery(280, 135, "receiver" , wgt , COLOR_THEME_PRIMARY2, COLOR_THEME_ACTIVE,"x")

else

  drawNewBattery(230, 15, "main"     , wgt  , COLOR_THEME_PRIMARY2, COLOR_THEME_ACTIVE,"l" )
drawNewBattery(230, 80,   "receiver" , wgt  , COLOR_THEME_PRIMARY2, COLOR_THEME_ACTIVE, "l")

end




  
  else

    

    local screenLayout = {
      { type = "header", text = "Main Battery", color = COLOR_THEME_SECONDARY2 },
      { type = "modelInfo", modelName = thisModel.modelName, modelImage = thisModel.bmpSizedModelImage , labelColor = COLOR_THEME_SECONDARY2 },
      { type = "keyvalue", label = "Battery Type", value = thisModel.battery.main.displayName, labelColor = COLOR_THEME_FOCUS, valuecolor = GREEN },
      { type = "keyvalue", label = "Cell Count", value = string.format("%s (%s)", thisModel.CellCount.main, thisModel.VoltageSensor.main.CellsDetectedCurrent), labelColor = COLOR_THEME_FOCUS, valuecolor = GREEN },
      { type = "keyvalue", label = "Voltage", value = thisModel.VoltageSensor.main.CurVolt, labelColor = COLOR_THEME_FOCUS, valuecolor = GREEN },
      { type = "keyvalue", label = "Percentage", value = thisModel.VoltageSensor.main.PercRem, labelColor = COLOR_THEME_FOCUS, valuecolor = GREEN },
  
      { type = "header", text = "Receiver Battery", color = COLOR_THEME_SECONDARY2 },
      { type = "keyvalue", label = "Battery Type", value = thisModel.battery.receiver.displayName, labelColor = COLOR_THEME_FOCUS, valuecolor = GREEN },
      { type = "keyvalue", label = "Cell Count", value = string.format("%s (%s)", thisModel.CellCount.receiver, thisModel.VoltageSensor.receiver.CellsDetectedCurrent), labelColor = COLOR_THEME_FOCUS, valuecolor = GREEN },
      { type = "keyvalue", label = "Voltage", value = thisModel.VoltageSensor.receiver.CurVolt, labelColor = COLOR_THEME_FOCUS, valuecolor = GREEN },
      { type = "keyvalue", label = "Percentage", value = thisModel.VoltageSensor.receiver.PercRem, labelColor = COLOR_THEME_FOCUS, valuecolor = GREEN },
  
      { type = "header", text = "Status:", color = COLOR_THEME_SECONDARY2 },
      { type = "statusMessage", status = pfStatus  , color = GREEN}  -- Placeholder for dynamic status message
  }
    
  preFlightStatusScreen(screenLayout, wgt.zone.w, wgt.zone.h)


end

  -- lcdText("RPM:",w,h,"s",  WHITE,"b",5,"l",1)
  -- lcdText("[",w,h,"s",     WHITE,"b",5,"l",4)
  -- lcdText("L:",w,h,"s",    WHITE,"b",5,"l",5)
  -- lcdText("3000",w,h,"s",  GREEN,"b",5,"l",6)
  -- lcdText("H:",w,h,"s",    WHITE,"b",5,"l",9)
  -- lcdText("3000",w,h,"s",  WHITE,"b",5,"l",10)
  -- lcdText("]",w,h,"s",     WHITE,"b",5,"l",13)
-- 
  -- lcdText("RPM:",w,h,"s",  WHITE,"b",5,"l",14)
  -- lcdText("[",w,h,"s",     WHITE,"b",5,"l",17)
  -- lcdText("L:",w,h,"s",    WHITE,"b",5,"l",18)
  -- lcdText("3000",w,h,"s",  GREEN,"b",5,"l",19)
  -- lcdText("H:",w,h,"s",    WHITE,"b",5,"l",22)
  -- lcdText("3000",w,h,"s",  WHITE,"b",5,"l",23)
  -- lcdText("]",w,h,"s",     WHITE,"b",5,"l",26)

  --lcdText("HHHHHHHHHHHHHHHHHHHHH",w,h,"s",     WHITE,"b",5,"l",1)






  --lcdText("RpM [H: 3200 p: 2617]",w,h,"s",WHITE,"b",3,"l",1)
  --lcdText("RpM [H: 3200 p: 2618]",w,h,"s",WHITE,"b",2,"l",1)
  --lcdText("RpM [H: 3200 p: 2619]",w,h,"s",WHITE,"b",1,"l",1)


  -- lcdText("TEST1",w,h,"l",WHITE,"t",1,"l",1)
  -- lcdText("TEST2",w,h,"l",WHITE,"t",2,"l",1)
  -- lcdText("TEST3",w,h,"l",WHITE,"t",3,"l",1)
  -- lcdText("HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH",w,h,"l",WHITE,"t",4,"l",1) -- 28
  -- 
  -- lcdText("H1",w,h,"l",WHITE,"t",5,"l",1) -- 28
  -- lcdText("H2",w,h,"l",WHITE,"t",5,"l",3) -- 28
  -- lcdText("H3",w,h,"l",WHITE,"t",5,"l",5) -- 28
-- 
  -- lcdText("H1",w,h,"l",WHITE,"t",5,"r",2) -- 28
  -- lcdText("H2",w,h,"l",WHITE,"t",5,"r",4) -- 28
  -- lcdText("H3",w,h,"l",WHITE,"t",5,"r",6) -- 28
-- 
  -- -- lcdText("H",w,h,"l",WHITE,"t",5,"r",1) -- 28
  -- -- lcdText("H",w,h,"l",WHITE,"t",5,"r",2) -- 28
  -- -- lcdText("H",w,h,"l",WHITE,"t",5,"r",3) -- 28
-- 
-- 
  -- --lcdText("TEST5",w,h,"l",WHITE,"t",5,"l",1)
  -- lcdText("TEST6",w,h,"l",WHITE,"t",6,"l",1)
  -- lcdText("TEST7",w,h,"l",WHITE,"t",7,"l",1)
  -- lcdText("TEST8",w,h,"l",WHITE,"t",8,"l",1)


  
-- text = "RPM [H: 3200 L: 2600]"
-- 
-- lcd.drawText(x            , line1 , text, FONT_8 + COLOR_THEME_PRIMARY2 )
-- lcd.drawText(x            , line1 + 18 , text, FONT_8 + COLOR_THEME_PRIMARY2 )
-- lcd.drawText(x            , line2 , text, FONT_6 + COLOR_THEME_PRIMARY2 )
-- lcd.drawText(x            , line3 , text, FONT_6 + COLOR_THEME_PRIMARY2 )
-- lcd.drawText(x            , line4 , text, FONT_6 + COLOR_THEME_PRIMARY2 )

-- lcd.drawText(x            , line5 , text, FONT_6 + COLOR_THEME_PRIMARY2 )
-- lcd.drawText(x            , line6 , text, FONT_6 + COLOR_THEME_PRIMARY2 )
-- lcd.drawText(x            , line7 , text, FONT_6 + COLOR_THEME_PRIMARY2 )
-- lcd.drawText(x            , line8 , text, FONT_6 + COLOR_THEME_PRIMARY2 )

-- lcd.drawText(col1            , line1 , text, FONT_6 + COLOR_THEME_PRIMARY2 )
-- --lcd.drawText(col2            , line1 , text, FONT_6 + COLOR_THEME_PRIMARY2 )
-- lcd.drawText(col3            , line1 , text, FONT_6 + COLOR_THEME_PRIMARY2 )
-- --lcd.drawText(col4            , line1 , text, FONT_6 + COLOR_THEME_PRIMARY2 )
-- 
-- lcd.drawText(col5            , line1 , text, FONT_6 + COLOR_THEME_PRIMARY2 )
-- --lcd.drawText(col6            , line1 , text, FONT_6 + COLOR_THEME_PRIMARY2 )
-- lcd.drawText(col7            , line1 , text, FONT_6 + COLOR_THEME_PRIMARY2 )
-- --lcd.drawText(col8            , line1 , text, FONT_6 + COLOR_THEME_PRIMARY2 )



-- lcd.drawText(x            , y , "TEST", FONT_16 + COLOR_THEME_PRIMARY2 )
-- lcd.drawText(x + dhw      , y , "TEST", FONT_16 + COLOR_THEME_PRIMARY2 )
-- lcd.drawText(x + hw       , y , "TEST", FONT_16 + COLOR_THEME_PRIMARY2 )
-- lcd.drawText(x + hw + dhw , y , "TEST", FONT_16 + COLOR_THEME_PRIMARY2 )
-- 
-- lcd.drawText(x, y + hh, "TEST", FONT_16 + COLOR_THEME_PRIMARY2 )
-- lcd.drawText(x + hw, y + hh , "TEST", FONT_16 + COLOR_THEME_PRIMARY2 )




  -- ray = 0
  -- lcd.drawFilledRectangle(0, ray, rhw, rhw, COLOR_THEME_PRIMARY1)
  -- ray = ray + rhw
  -- lcd.drawFilledRectangle(0, ray, rhw, rhw, COLOR_THEME_PRIMARY2)
  -- ray = ray + rhw
  -- lcd.drawFilledRectangle(0, ray, rhw, rhw, COLOR_THEME_PRIMARY3)
  -- ray = ray + rhw
  -- lcd.drawFilledRectangle(0, ray, rhw, rhw, COLOR_THEME_SECONDARY1)
  -- ray = ray + rhw
  -- lcd.drawFilledRectangle(0, ray, rhw, rhw, COLOR_THEME_SECONDARY2)
  -- ray = ray + rhw
  -- lcd.drawFilledRectangle(0, ray, rhw, rhw, COLOR_THEME_SECONDARY3)
  -- ray = ray + rhw
  -- lcd.drawFilledRectangle(0, ray, rhw, rhw, COLOR_THEME_FOCUS)
  -- ray = ray + rhw
  -- lcd.drawFilledRectangle(0, ray, rhw, rhw, COLOR_THEME_EDIT)
  -- ray = ray + rhw
  -- lcd.drawFilledRectangle(0, ray, rhw, rhw, COLOR_THEME_ACTIVE)
  -- ray = ray + rhw
  -- lcd.drawFilledRectangle(0, ray, rhw, rhw, COLOR_THEME_WARNING)
  -- ray = ray + rhw
  -- lcd.drawFilledRectangle(0, ray, rhw, rhw, COLOR_THEME_DISABLED)

end

if not testing then

-- math.floor(value)

-- COLOR_THEME_FOCUS
-- 
-- COLOR_THEME_EDIT
-- 
-- COLOR_THEME_ACTIVE
-- 
-- COLOR_THEME_WARNING
-- 
-- COLOR_THEME_DISABLED



      --background
      lcd.drawFilledRectangle(0, 0, wgt.zone.w, wgt.zone.h, BGColor, 5)


  if batCheckPassed or not ShowPreFlightStatus then


  -- Draw the top-left 1/4 of the screen
  --drawCellVoltage(wgt, cellResult)



    -- Draw the bottom-left 1/4 of the screen

    -- Draw the top-right 1/4 of the screen
    --lcd.drawText(wgt.zone.x + 270, wgt.zone.y + -5, string.format("%.2fV", VoltsNow), DBLSIZE + Color)
    --lcd.drawText(wgt.zone.x + 10, wgt.zone.y + 30, "Main Battery", MIDSIZE + Color + SHADOWED)
    lcd.drawText(wgt.zone.x + 50, wgt.zone.y + 30, "Main Battery", MIDSIZE + COLOR_THEME_PRIMARY3 + SHADOWED)
    lcd.drawText(wgt.zone.x + 10, wgt.zone.y + 60, "C: Current / L: Lowest / H: Highest", SMLSIZE + COLOR_THEME_PRIMARY2 )
  
    amps = getValue( sensorCurrent["main"] ) -- todo
    --lcd.drawText(wgt.zone.x + 270, wgt.zone.y + 25, string.format("%.1fA", amps), DBLSIZE + Color)

    --maincur = getValue(VoltageSensor)
    --maincurmax = getValue(VoltageSensor.."+")
  
    lcd.drawText(wgt.zone.x + 10, wgt.zone.y + 80, string.format("C: %sV", currentVoltageValueCurrent["main"]), MIDSIZE + COLOR_THEME_SECONDARY1 + mainVoltBlink )
    --lcd.drawText(wgt.zone.x + 95, wgt.zone.y + 35, "/", MIDSIZE + Color)
    lcd.drawText(wgt.zone.x + 120, wgt.zone.y + 80, string.format("L: %sV", currentVoltageValueLow["main"]), MIDSIZE + COLOR_THEME_SECONDARY2)
    

    lcd.drawText(wgt.zone.x + 10, wgt.zone.y + 110, string.format("C: %sA", currentCurrentValueCurrent["main"]), MIDSIZE + COLOR_THEME_SECONDARY1 + mainCurrentBlink)
    --lcd.drawText(wgt.zone.x + 95, wgt.zone.y + 65, "/", MIDSIZE + Color)
    lcd.drawText(wgt.zone.x + 120, wgt.zone.y + 110, string.format("H: %sA", currentCurrentValueHigh["main"]), MIDSIZE + COLOR_THEME_SECONDARY2)

    drawBattery(40, 150, valueVoltsPercentRemaining["main"], wgt,typeBattery["main"] )




    -- lcd.drawText(wgt.zone.x + 10, wgt.zone.y + 230, sensorline1, SMLSIZE + BLACK + SHADOWED )
    -- lcd.drawText(wgt.zone.x + 10, wgt.zone.y + 245, sensorline2, SMLSIZE + BLACK + SHADOWED )

    lcd.drawText(wgt.zone.x + 10, wgt.zone.y + 230, sensorline1, SMLSIZE + BLACK )
    lcd.drawText(wgt.zone.x + 10, wgt.zone.y + 245, sensorline2, SMLSIZE + BLACK )


  lcd.drawText(wgt.zone.x + 240, wgt.zone.y + 30, "Receiver Battery", MIDSIZE + COLOR_THEME_PRIMARY1 + SHADOWED)
  lcd.drawText(wgt.zone.x + 240, wgt.zone.y + 60, "C: Current / L: Lowest / H: Highest", SMLSIZE + COLOR_THEME_PRIMARY2 )

  --lcd.drawText(wgt.zone.x + 240, wgt.zone.y + 40, string.format("%.2fV / %.2fV", RxVoltsNow, RxVoltsMax), MIDSIZE + Color)

  lcd.drawText(wgt.zone.x + 240, wgt.zone.y + 80, string.format("C: %sV", currentVoltageValueCurrent["receiver"]), MIDSIZE + COLOR_THEME_SECONDARY1 + rxVoltBlink)
  --lcd.drawText(wgt.zone.x + 95, wgt.zone.y + 35, "/", MIDSIZE + Color)
  lcd.drawText(wgt.zone.x + 350, wgt.zone.y + 80, string.format("L: %sV", currentVoltageValueLow["receiver"]), MIDSIZE + COLOR_THEME_SECONDARY2)

  lcd.drawText(wgt.zone.x + 240, wgt.zone.y + 110, string.format("C: %sA",  currentCurrentValueCurrent["receiver"]), MIDSIZE + COLOR_THEME_SECONDARY1 + rxCurrentBlink)
  --lcd.drawText(wgt.zone.x + 95, wgt.zone.y + 65, "/", MIDSIZE + Color)
  lcd.drawText(wgt.zone.x + 350, wgt.zone.y + 110, string.format("H: %sA", currentCurrentValueHigh["receiver"]), MIDSIZE + COLOR_THEME_SECONDARY2)

  drawBattery(270, 150, valueVoltsPercentRemaining["receiver"], wgt,typeBattery["receiver"] )


  -- lcd.drawText(wgt.zone.x + 10, wgt.zone.y + 170, sensorline1, SMLSIZE + Color )
  -- lcd.drawText(wgt.zone.x + 10, wgt.zone.y + 185, sensorline2, SMLSIZE + Color )


else



  local valueColor = WHITE

  lcd.drawText(wgt.zone.x + 200, wgt.zone.y + -5, modelName, MIDSIZE + COLOR_THEME_PRIMARY1)
  lcd.drawBitmap(bmpSizedModelImage, 200, 20, 50 )


  local xlineStart = 10

  local ylineStart = 25
  local ylineinc = 20


  lcd.drawText(wgt.zone.x + xlineStart, wgt.zone.y + -5, "Main Battery", MIDSIZE + COLOR_THEME_PRIMARY1)

  xline = xlineStart
  yline = ylineStart
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, "Battery Type",  COLOR_THEME_PRIMARY3 + BOLD )
  xline = xline + 100
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, ":",  COLOR_THEME_PRIMARY2 + BOLD )
  xline = xline + 20
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, typeBattery["main"],  valueColor + BOLD )

  xline = xlineStart
  yline = yline + ylineinc
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, "Cell Count",  COLOR_THEME_PRIMARY3 + BOLD )
  xline = xline + 100
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, ":",  COLOR_THEME_PRIMARY2 + BOLD )
  xline = xline + 20
  -- lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, countCell["main"],  GREEN + BOLD )
  --lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, countCell["main"],  GREEN + BOLD )
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, string.format("%s (%s)", countCell["main"], CellsDetectedCurrent["main"]), valueColor + BOLD)

  xline = xlineStart
  yline = yline + ylineinc
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, "Voltage",  COLOR_THEME_PRIMARY3 + BOLD )
  xline = xline + 100
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, ":",  COLOR_THEME_PRIMARY2 + BOLD )
  xline = xline + 20
  -- lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, countCell["main"],  GREEN + BOLD )
  --lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, countCell["main"],  GREEN + BOLD )
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, currentVoltageValueCurrent["main"], valueColor + BOLD)
  
  xline = xlineStart
  yline = yline + ylineinc
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, "Percentage",  COLOR_THEME_PRIMARY3 + BOLD )
  xline = xline + 100
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, ":",  COLOR_THEME_PRIMARY2 + BOLD )
  xline = xline + 20
  -- lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, countCell["main"],  GREEN + BOLD )
  --lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, countCell["main"],  GREEN + BOLD )
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, valueVoltsPercentRemaining["main"], valueColor + BOLD)




  yline = yline + ylineinc + 0
  lcd.drawText(wgt.zone.x + xlineStart, wgt.zone.y + yline, "Receiver Battery", MIDSIZE + COLOR_THEME_PRIMARY1)

  yline = yline + ylineinc + 10
  xline = xlineStart
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, "Battery Type",  COLOR_THEME_PRIMARY3 + BOLD )
  xline = xline + 100
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, ":",  COLOR_THEME_PRIMARY2 + BOLD )
  xline = xline + 20
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, typeBattery["receiver"],  valueColor + BOLD )

  xline = xlineStart
  yline = yline + ylineinc
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, "Cell Count",  COLOR_THEME_PRIMARY3 + BOLD )
  xline = xline + 100
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, ":",  COLOR_THEME_PRIMARY2 + BOLD )
  xline = xline + 20
  --lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, countCell["receiver"],  GREEN + BOLD )
  --lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, countCell["receiver"],  GREEN + BOLD )
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, string.format("%s (%s)", countCell["receiver"], CellsDetectedCurrent["receiver"]), valueColor + BOLD)

  xline = xlineStart
  yline = yline + ylineinc
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, "Voltage",  COLOR_THEME_PRIMARY3 + BOLD )
  xline = xline + 100
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, ":",  COLOR_THEME_PRIMARY2 + BOLD )
  xline = xline + 20
  --lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, countCell["receiver"],  GREEN + BOLD )
  --lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, countCell["receiver"],  GREEN + BOLD )
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, currentVoltageValueCurrent["receiver"], valueColor + BOLD)

  xline = xlineStart
  yline = yline + ylineinc
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, "Percentage",  COLOR_THEME_PRIMARY3 + BOLD )
  xline = xline + 100
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, ":",  COLOR_THEME_PRIMARY2 + BOLD )
  xline = xline + 20
  --lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, countCell["receiver"],  GREEN + BOLD )
  --lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, countCell["receiver"],  GREEN + BOLD )
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, valueVoltsPercentRemaining["receiver"], valueColor + BOLD)



  -- preFlightStatusBat



  xline = 10
  yline = yline  + 20
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, "Telemetry Status", MIDSIZE + COLOR_THEME_PRIMARY1)
  xline = xline + 190
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, ":",  MIDSIZE + COLOR_THEME_PRIMARY2  )

if string.find(preFlightStatusTele, "NOT") then
  statusBlink = BLINK
  statusColor = RED
--elseif string.find(inputString, "keyword2") then
--  result = "value2"
else
  statusBlink = 0
 statusColor = GREEN
end


  xline = xline + 15
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, preFlightStatusTele, MIDSIZE + statusColor + statusBlink )




  xline = 10
  yline = yline  + 25
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, "Battery Status", MIDSIZE + COLOR_THEME_PRIMARY1)
  xline = xline + 190
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, ":",  MIDSIZE + COLOR_THEME_PRIMARY2  )

if string.find(preFlightStatusBat, "Check") then
  statusBlink = BLINK
  statusColor = RED
--elseif string.find(inputString, "keyword2") then
--  result = "value2"

else
  statusBlink = 0
  statusColor = GREEN

end


  xline = xline + 15
  lcd.drawText(wgt.zone.x + xline, wgt.zone.y + yline, preFlightStatusBat, MIDSIZE + statusColor + statusBlink )




end


end
  -- if type(MaxWatts) == "string" then
  --   sMaxWatts = MaxWatts
  -- elseif type(MaxWatts) == "number" then
  --   sMaxWatts = string.format("%.0f", MaxWatts)
  -- end
  -- lcd.drawText(wgt.zone.x + 230, wgt.zone.y + 55, string.format("%.0fW / %sW", watts, sMaxWatts), MIDSIZE + Color)

  -- Draw the bottom-right of the screen
  --lcd.drawText(wgt.zone.x + 190, wgt.zone.y + 85, string.format("%sW", MaxWatts), XXLSIZE + Color)

  -- VOLTS -- lcd.drawText(wgt.zone.x + 185, wgt.zone.y + 85, string.format("%.2fV", VoltsNow), XXLSIZE + Color)

  --lcd.drawText(wgt.zone.x + 5, wgt.zone.y + fontSize, "BATTERY LEFT", SHADOWED)
  --lcd.setColor(CUSTOM_COLOR, getPercentColor(BatRemPer))
  --lcd.drawText(wgt.zone.x + 5, wgt.zone.y + fontSize + 25, round(BatRemPer).."%" , DBLSIZE + SHADOWED + BlinkWhenZero)
  --lcd.drawText(wgt.zone.x + 5, wgt.zone.y + fontSize + 55, math.floor(BatRemainmAh).."mAh" , DBLSIZE + SHADOWED + BlinkWhenZero)
  --
  --lcd.setColor(CUSTOM_COLOR, wgt.options.Color)
  --lcd.drawRectangle((wgt.zone.x - 1) , (wgt.zone.y + (wgt.zone.h - 31)), (wgt.zone.w + 2), 32, 0)
  --lcd.setColor(CUSTOM_COLOR, getPercentColor(BatRemPer))
  --lcd.drawGauge(wgt.zone.x , (wgt.zone.y + (wgt.zone.h - 30)), wgt.zone.w, 30, BatRemPer, 100, BlinkWhenZero)
end


-- ####################################################################
local function run_func(wgt)	-- Called periodically when screen is visible
  bg_func()
  if     wgt.zone.w  > 380 and wgt.zone.h > 165 then refreshZoneXLarge(wgt)
  elseif wgt.zone.w  > 180 and wgt.zone.h > 145 then refreshZoneLarge(wgt)
  elseif wgt.zone.w  > 170 and wgt.zone.h >  65 then refreshZoneMedium(wgt)
  elseif wgt.zone.w  > 150 and wgt.zone.h >  28 then refreshZoneSmall(wgt)
  elseif wgt.zone.w  >  65 and wgt.zone.h >  35 then refreshZoneTiny(wgt)
  end
end

-- ####################################################################
function create(zone, options)
  init_func()
  local Context = { zone=zone, options=options }
  return Context
end

-- ####################################################################
-- function update(Context, options)
--   mAhSensor = options.mAh
--   VoltageSensor = options.Voltage
--   RxBatVoltSensor = options.RxBat_Volt
--   CurrentSensor = options.Current
--   Color = options.Color
--   Context.options = options
--   Context.back = nil
--   Battery_Cap = options.Battery_Cap
-- end

function update(Context, options)
  Color = options.Color -- left for historical reasons ... remove Color Variable -- todo 
  BGColor = Color
  Context.options = options
  Context.back = nil
  Battery_Cap = options.Battery_Cap
end

--####################################################################
function background(Context)
  bg_func()
end

-- ####################################################################
function refresh(Context)
  run_func(Context)
end

-- local options = {
--   { "mAh", SOURCE, mAh }, -- Defines source Battery Current Sensor
--   { "Voltage", SOURCE, CEL1 }, -- Defines source Battery Voltage Sensor
--   { "RxBat_Volt", SOURCE, CEL1 }, -- Defines source Battery Voltage Sensor
--   { "Current", SOURCE, Curr },
--   { "Color", COLOR, GREY },
--   { "Battery_Cap", VALUE, 4000, 500, 10000  }
-- }

local options = {
  { "Color", COLOR, GREY },
  { "Battery_Cap", VALUE, 4000, 500, 10000  }
}

return { name="TxBatTele", options=options, create=create, update=update, refresh=refresh, background=background }
