-- License https://www.gnu.org/licenses/gpl-3.0.en.html
-- OpenTX Lua script
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

-- Configurations
--  For help using telemetry scripts
--    http://rcdiy.ca/telemetry-scripts-getting-started/
local Title = "Flight Telemetry and Battery Monitor"

-- Sensors
-- 	Use Voltage and or mAh consumed calculated sensor based on VFAS, FrSky FAS-40
-- 	Use sensor names from OpenTX TELEMETRY screen
--  If you need help setting up a consumption sensor visit
--		http://rcdiy.ca/calculated-sensor-consumption/

-- https://ttsmaker.com/
-- https://online-audio-converter.com/de/

-- Change as desired

local contexts = {"main", "receiver"}

local verbosity = 3 --todo verbosity levels

-- local currentContext = contexts[currentContextIndex]
-- 
-- -- Use the current context variables
-- print("Voltage Sensor (" .. currentContext .. "): " .. table.concat(modelDetails.VoltageSensor[currentContext], ", "))
-- print("Current Sensor (" .. currentContext .. "): " .. table.concat(modelDetails.CurrentSensor[currentContext], ", "))
-- print("Capacity (" .. currentContext .. "): " .. table.concat(modelDetails.capacities[currentContext], ", "))
-- 
-- -- Perform other operations based on current context
-- -- ...
-- 
-- -- Cycle to the next context
-- currentContextIndex = (currentContextIndex % #contexts) + 1

local statusTele = false

idstatusTele = getSwitchIndex("TELE")


local SwitchAnnounceTable = {
  {"sf","armed","disarm"},
  {"sh","safeon"},
  {"se","fm-nrm","fm-1","fm-2"}
}

local line1statsensors = {
  {"RPM","rpm"},
  {"RSSI","RSSI"},
  {"TMP1","TMP1"},
  {"TMP2","TMP2"}
}

local line2statsensors = {
  {"CUR","Curr"},
  {"Fuel","Fuel"}
}


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


local modelTable = {
  {
      modelNameMatch         = "DEFAULT",
      modelName              = "DEFAULT",
      modelImage             = "goblin.png",
      modelWav               = "sg630",
      rxReferenceVoltage     = 8.2,
      VoltageSensor          = { main = "Cels",    receiver = "RxBt" },
      CurrentSensor          = { main = "Curr",    receiver = "Curr" },
      MahSensor              = { main = "",        receiver = "" },
      BattType               = { main = "lipo",    receiver = "buffer" },
      CellCount              = { main = 12,        receiver = 2 },
      capacities             = { main = { 500, 1000, 1500, 2000, 2500, 3000 }, receiver = { 500, 1000, 1500, 2000, 2500, 3000 } },
      switchAnnounces        = SwitchAnnounceTable,
      line1statsensors       = line1statsensors,
      line2statsensors       = line2statsensors,
      BattPackSelectorSwitch = BattPackSelectorSwitch
  },
  {
      modelNameMatch         = "heli",
      modelName              = "SAB Goblin 630",
      modelImage             = "goblin.png",
      modelWav               = "sg630",
      rxReferenceVoltage     = 8.2,
      resetSwitch            = "TELE",
      VoltageSensor          = { main = "Cels",    receiver = "RxBt" },
      CurrentSensor          = { main = "Curr",    receiver = "Curr" },
      MahSensor              = { main = "",        receiver = "" },
      BattType               = { main = "lipo",    receiver = "buffer" },
      CellCount              = { main = 8,         receiver = 2 },
      capacities             = { main = { 500, 1000, 1500, 2000, 2500, 3000 }, receiver = { 500, 1000, 1500, 2000, 2500, 3000 } },
      switchAnnounces        = SwitchAnnounceTable,
      line1statsensors       = line1statsensors,
      line2statsensors       = line2statsensors,
      BattPackSelectorSwitch = BattPackSelectorSwitch
  }
}



local priorizeSwitchAnnouncements = true


local FirstModelInit = true
local ModelImageBM = Bitmap.open("/IMAGES/280.png")
--local ModelName = model.getInfo().name


local ShowPostFlightSummary = true --todo
local ShowPreFlightStatus = true -- todo
local ActiveFlightIndicator = "choose switch" -- todo ... use arm switch or maybe there is a good tele sensor for this



-- Main Battery
--local VoltageSensor = "VFAS" -- optional set to "" to ignore
local VoltageSensor = "Cels" -- optional set to "" to ignore
local CurrentSensor = "Curr"
local mAhSensor = "" -- optional set to "" to ignore

-- Receiver Battery
local RxBatVoltSensor = "RxBt"
local RxBatCurrSensor = "Curr"

local Battery_Cap = 3500 --todo


-- local RxBtVoltageWarningDelay = 10 --todo-done add delay to percentage alerts -

-- Receiver Battery
local rxbatwarn = false
local PlayRxBatFirstWarning = true
local PlayRxBatWarning = true

local statusTable = {}



-- to support future functions like taking screenshot and logging on/off
local ver, radio, maj, minor, rev, osname = getVersion()
print("version: "..ver)
if radio then print ("version radio: "..radio) end
if maj then print ("version maj: "..maj) end
if minor then print ("version minor: "..minor) end
if rev then print ("version rev: "..rev) end
if osname then print ("version osname: "..osname) end




-- local TelemetryStatusSwitch = "TELE"
-- local TelemetryStatusSwitch_ID  = getSwitchIndex(TelemetryStatusSwitch)
-- 
-- 
-- local resetSwitch = TelemetryStatusSwitch
-- local resetSwitch = "SD" .. CHAR_DOWN
-- local resetSwitch_ID  = getSwitchIndex(resetSwitch)

--local resetSwitch_ID  = getFieldInfo(resetSwitch).id

-- local tele_switch_ID  = getSwitchIndex("TELE")

local AutomaticResetOnResetSwitchToggle = 4 -- 5 seconds for TELE Trigger .... maybe 1 second for switch trigger

local AutomaticResetOnResetPrevState = nil

local AutomaticResetStateChangeCount = 0

local AutomaticResetOnNextChange = true


-- don't go equal or below 3 seconds for intervals .... otherwise announcements will have no time to play
--                      Announce Remaining / Annouce Warning (repeat/sing) / Announce Critical (repeat/single) / Trigger Delay in S
--batAnnounce["main"] =      { 4, 30 , 5 , 0 , 2.5 , 5 , 2.5 }
--batAnnounce["receiver"] = { 10, 50 , 5 , 0 , 2.5 , 5 , 2.5 }
local batAnnounce = {}

batAnnounce["main"] =      { 4, 30 , 5 , 0 , 2.5 , 0 , 2.5 }
batAnnounce["receiver"] = { 4, 50 , 5 , 0 , 2.5 , 0 , 2.5 }

-- -1 = off / 0 = single/on change
-- Step 2.5 is the lowest

local TriggerTimers = {}

-- todo read from live sensor and do the calc later ( volt - volt below) --> only for buffer !!!
-- local RxBtVoltage = 8.0

-- local RxBtVoltageDropWarning = 0.5
-- local RxBtVoltageWarning = RxBtVoltage - RxBtVoltageDropWarning

-- Used to calculate batt full percentage (linear curve)
-- local LipoBatLowVolt = 3.27
-- local LipoBatHighVolt = 4.2


local rxbatType = "buffer"
local mainbattype = "lipo"

-- if rxbatType == "buffer" then
--   RxBattWarnThresld = 97
--   RxBattCritThresld = 95
--   -- todo-done see below ... this devided by two is lame
--   RxBatLowVolt = 6 / 2
--   RxBatHighVolt = RxBtVoltage / 2
-- else
--   RxBattWarnThresld = 20
--   RxBattCritThresld = 15
--   RxBatLowVolt = LipoBatLowVolt
--   RxBatHighVolt = LipoBatHighVolt
-- end

local bufferLowVol = 6 --normally the value where the buffer shuts down completely
local bufferHighVol = 8.2 --normally the value your BEC is set to -- todo add to model definition above

-- do not change ... we are basing our calculations based on theoretical cells values
local bufferLowPerCellValue = bufferLowVol / 2
local bufferHighPerCellValue = bufferHighVol / 2

local batTypeLowHighValues = {}
local batTypeWarnCritThresh = {}

batTypeLowHighValues["lipo"] = {3.27, 4.2}
batTypeLowHighValues["buffer"] = {bufferLowPerCellValue, bufferHighPerCellValue}

batTypeWarnCritThresh["lipo"] = {20, 15}
batTypeWarnCritThresh["buffer"] = {97, 95}

-- todo getPercentColor uses this ... maybe adapt for critical
local BattWarnThresld = 20
local BattCritThresld = 15

--local BattAnnounceSteps = 10
--local BattAnnounceStepsWarn = 2.5
-- todo-done maybe add critical too

local MainBatNotFullThresh = 97
local RxBatNotFullThresh = 98

local BatNotFullThresh = {}
BatNotFullThresh["lipo"] = 97
BatNotFullThresh["buffer"] = 98


--local CellsDetected = false


-- local SwitchAnnounceTable = {
--   {"SF" .. CHAR_UP, "armed"},
--   {"SF" .. CHAR_DOWN, "disarm"},
--   {"SE" .. CHAR_UP, "fm-nrm"},
--   {"SE-" , "fm-1"},
--   {"SE" .. CHAR_DOWN, "fm-2"}
-- }




-- local announcementConfig = {
--   telemetry = {
--     normal = {
--       mode = "disable", -- "disable", "change", or an interval in seconds
--       gracePeriod = 1 -- Grace period in seconds for "change" mode
--     },
--     warning = {
--       threshold = false, -- Threshold for warning level
--       mode = "change" -- "disable", "change", or an interval in seconds
--     },
--     critical = {
--       threshold = "undef", -- Threshold for critical level
--       mode = "disable", -- "disable", "change", or an interval in seconds
--     }
--   },
-- 
--   BatteryMissingCell = {
--     normal = {
--       mode = "disable", -- "disable", "change", or an interval in seconds
--       gracePeriod = 1 -- Grace period in seconds for "change" mode
--     },
--     warning = {
--       threshold = -1, -- Threshold for warning level
--       mode = 10 -- "disable", "change", or an interval in seconds
--     },
--     critical = {
--       threshold = -2, -- Threshold for critical level
--       mode = 10 -- "disable", "change", or an interval in seconds
--     }
--   },
-- 
--   CellDelta = {
--     normal = {
--       mode = "disable", -- "disable", "change", or an interval in seconds
--       gracePeriod = 3 -- Grace period in seconds for "change" mode
--     },
--     warning = {
--       threshold = "undef", -- Threshold for warning level
--       mode = 10 -- "disable", "change", or an interval in seconds
--     },
--     critical = {
--       threshold = true, -- Threshold for critical level
--       mode = 10 -- "disable", "change", or an interval in seconds
--     }
--   },  
-- 
-- 
--   BatteryNotFull = {
--     main = {
--       normal = {
--         mode = "disable", -- "disable", "change", or an interval in seconds
--         gracePeriod = 0 -- Grace period in seconds for "change" mode
--       },
--       warning = {
--         --threshold = 98, -- Threshold for warning level
--         threshold = "useBatTypeDefault", -- Threshold for warning level --- for defaults see below
--         mode = "change" -- "disable", "change", or an interval in seconds
--       },
--       critical = {
--         --threshold = 96, -- Threshold for critical level
--         threshold = "useBatTypeDefault", -- Threshold for critical level
--         mode = "change" -- "disable", "change", or an interval in seconds
--       }
--     },
--     receiver = {
--       normal = {
--         mode = "disable", -- "disable", "change", or an interval in seconds
--         gracePeriod = 1 -- Grace period in seconds for "change" mode
--       },
--       warning = {
--         --threshold = 99, -- Threshold for warning level
--         threshold = "useBatTypeDefault", -- Threshold for warning level
--         mode = "change" -- "disable", "change", or an interval in seconds
--       },
--       critical = {
--         --threshold = 98, -- Threshold for critical level
--         threshold = "useBatTypeDefault", -- Threshold for critical level
--         mode = "change" -- "disable", "change", or an interval in seconds
--       }
--     }
--   },
-- 
-- 
--   Battery = {
--     main = {
--       normal = {
--         mode = 20, -- "disable", "change", or an interval in seconds
--         gracePeriod = 4 -- Grace period in seconds for "change" mode
--       },
--       warning = {
--         --threshold = 20, -- Threshold for warning level
--         threshold = "useBatTypeDefault", -- Threshold for warning level
--         mode = "change" -- "disable", "change", or an interval in seconds
--       },
--       critical = {
--         --threshold = 15, -- Threshold for critical level
--         threshold = "useBatTypeDefault", -- Threshold for critical level
--         mode = "change" -- "disable", "change", or an interval in seconds
--       }
--     },
--     receiver = {
--       normal = {
--         mode = 30, -- "disable", "change", or an interval in seconds
--         gracePeriod = 2 -- Grace period in seconds for "change" mode
--       },
--       warning = {
--         --threshold = 97, -- Threshold for warning level
--         threshold = "useBatTypeDefault", -- Threshold for warning level
--         mode = "change" -- "disable", "change", or an interval in seconds
--       },
--       critical = {
--         --threshold = 95, -- Threshold for critical level
--         threshold = "useBatTypeDefault", -- Threshold for critical level
--         mode = "change" -- "disable", "change", or an interval in seconds
--       }
--     }
--   }  
-- 
-- 
-- 
-- 
-- 
-- 
--   -- Add other items with their respective configurations
-- }

local announcementConfig = {
  -- Telemetry configuration
  telemetry = {
      normal   = { mode = "disable",           gracePeriod = 1 }, -- Mode to disable telemetry in normal state
      warning  = { mode = "change",            threshold = false }, -- Mode to change telemetry in warning state
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
  },

  -- Battery Not Full configuration
  BatteryNotFull = {
      main = {
          normal   = { mode = "disable",       gracePeriod = 0 }, -- Mode to disable when battery not full (main)
          warning  = { mode = "change",        threshold = "useBatTypeDefault" }, -- Mode to change when nearing warning level (main)
          critical = { mode = "change",        threshold = "useBatTypeDefault" }  -- Mode to change when nearing critical level (main)
      },
      receiver = {
          normal   = { mode = "disable",       gracePeriod = 1 }, -- Mode to disable when battery not full (receiver)
          warning  = { mode = "change",        threshold = "useBatTypeDefault" }, -- Mode to change when nearing warning level (receiver)
          critical = { mode = "change",        threshold = "useBatTypeDefault" }  -- Mode to change when nearing critical level (receiver)
      }
  },

  -- Battery configuration
  Battery = {
      main = {
          normal   = { mode = 20,              gracePeriod = 4 }, -- Mode with an interval of 20 seconds when battery level is normal (main)
          warning  = { mode = "change",        threshold = "useBatTypeDefault" }, -- Mode to change when nearing warning level (main)
          critical = { mode = "change",        threshold = "useBatTypeDefault" }  -- Mode to change when nearing critical level (main)
      },
      receiver = {
          normal   = { mode = 30,              gracePeriod = 2 }, -- Mode with an interval of 30 seconds when battery level is normal (receiver)
          warning  = { mode = "change",        threshold = "useBatTypeDefault" }, -- Mode to change when nearing warning level (receiver)
          critical = { mode = "change",        threshold = "useBatTypeDefault" }  -- Mode to change when nearing critical level (receiver)
      }
  }

  -- Add other items with their respective configurations
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

local statusTable = {}





local BatteryTypeDefaults = {
  lipo = {
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
      criticalThreshold        = 15,     -- Critical threshold in percentage
      warningThreshold         = 20,     -- Warning threshold in percentage
      notFullCriticalThreshold = 96,     -- Not full critical threshold in percentage
      notFullWarningThreshold  = 98,     -- Not full warning threshold in percentage
      highVoltage              = 4.20,   -- High voltage
      lowVoltage               = 3.27,   -- Low voltage
      cellDeltaVoltage         = 0.07    -- Cell delta voltage
  },

  buffer = {
      dischargeCurve           = nil,    -- This will be dynamically calculated based on voltage range
      criticalThreshold        = 96,     -- Critical threshold in percentage
      warningThreshold         = 97,     -- Warning threshold in percentage
      notFullCriticalThreshold = 98,     -- Not full critical threshold in percentage
      notFullWarningThreshold  = 99,     -- Not full warning threshold in percentage
      highVoltage              = nil,    -- High voltage -- will be set to rxReferenceVoltage from the model once it's loaded ... you can override it here ... but it's better to "calculate"/set it to the rxReferenceVoltage -- todo
      lowVoltage               = 6,      -- Low voltage -- where your buffer pack shuts off completely ... all hope is lost after this ;-) .. please note... in the case of buffer packs ... we will device this value by 2 in order to get a theoretical 2s per cell value for the alerts and percentage left -- todo
      cellDeltaVoltage         = nil     -- Cell delta voltage -- irrelevant for buffer or bec
  },

  beconly = {
      dischargeCurve           = nil,    -- This will be dynamically calculated based on voltage range
      criticalThreshold        = 96,     -- Critical threshold in percentage
      warningThreshold         = 97,     -- Warning threshold in percentage
      notFullCriticalThreshold = 98,     -- Not full critical threshold in percentage
      notFullWarningThreshold  = 99,     -- Not full warning threshold in percentage
      highVoltage              = nil,    -- High voltage -- will be set to rxReferenceVoltage from the model once it's loaded ... you can override it here ... but it's better to "calculate"/set it to the rxReferenceVoltage -- todo
      lowVoltage               = 5,      -- Low voltage -- there is not such a thing as "lowvoltage" if only using a bec ... if you loose your bec you will recognize it before we can announce anything ... so lets set this to anything below what is "normal" ... like 5
      cellDeltaVoltage         = nil     -- Cell delta voltage -- irrelevant for buffer or bec
    },
  }









-- local announcementPhrases = {
-- 
--   telemetry = {
--     { type = }
--   }
-- 
-- 
-- }

--local RxBtVoltageWarning = (RxBtVoltage / 100) * (100-RxBtVoltagePercentageWarning)


-- Reserve Capacity
-- 	Remaining % Displayed = Calculated Remaining % - Reserve %
-- Change as desired
-- todo
local CapacityReservePercent = 0 -- set to zero to disable

-- Switch used to reset the voltage checking features.
--  typically set to the same switch used to reset timers
local SwReset = "sh" --todo intersting ?

--   Value used when checking to see if the cell is full for the check_for_full_battery check
--local CellFullVoltage = 4.0
local CellFullVoltage = 4.2

local CellFullVoltageTolerance = 0.2

--   Value used to when comparing cell voltages to each other.
--    if any cell gets >= VoltageDelta volts of the other cells
--    then play the Inconsistent Cell Warning message
local VoltageDelta = .3

-- Announcements
local soundDirPath = "/WIDGETS/TxBatTele/sounds/" -- where you put the sound files
local AnnouncePercentRemaining = true -- true to turn on, false for off
local SillyStuff = false  -- Play some silly/fun sounds

-- Do not change the next line
local GV = {[1] = 0, [2] = 1, [3] = 2,[4] = 3,[5] = 4,[6] = 5, [7] = 6, [8] = 7, [9] = 8}


local BatNotFullWarn = {}
BatNotFullWarn["main"]   = nil
BatNotFullWarn["receiver"]   = nil

-- OpenTX Global Variables (GV)
--	These are global to the model and not between models.
--
--	Each flight mode (FM) has its own set of GVs. Using this script you could
--		be flying in FM 0 but access variables from FM 8. This is useful when
--		when running out of GVs available to use.
--		Most users can leave the flight mode setting at the default value.
--
--	If you have configured mAhSensor = "" then ignore GVBatCap
-- 	GVBatCap - Battery capacity provided as mAh/100,
--									2800 mAh would be 28, 800 mAh would be 8
--
-- Change as desired
-- Use GV[6] for GV6, GV[7] for GV7 and so on

local GVCellCount = GV[6] -- Read the number of cells
local GVBatCap = GV[7] 	-- Read Battery Capacity, 8 for 800mAh, 22 for 2200mAh
-- The corresponding must be set under the FLIGHT MODES
-- screen on the Tx.
-- If the GV is 0 or not set on the Tx then
-- % remaining is calculated based on battery voltage
-- which may not be as accurate.
local GVFlightMode = 0 -- Use a different flight mode if running out of GVs

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
local DEBUG = false

local CanCallInitFuncAgain = false		-- updated in bg_func

-- Calculations
local UseVoltsNotmAh	-- updated in init_func
local BatCapFullmAh		-- updated in init_func
local BatCapmAh				-- updated in init_func
local BatUsedmAh = 0			-- updated in bg_func
local BatRemainmAh 		-- updated in init_func, bg_func
local BatRemPer 			-- updated in init_func, bg_func
local VoltsPercentRem -- updated in init_func, bg_func
local rxVoltsPercentRem -- updated in init_func, bg_func
--local VoltsNow 	= 0			-- updated in bg_func
--local RxVoltsNow 	= 0			-- updated in bg_func
local CellCount 			-- updated in init_func, bg_func
--local VoltsMax 				-- updated in bg_func
local VoltageHistory = {}   -- updated in bg_func



local VoltsNow = 0
local VoltsMax = 0
local VoltsLow = 0

local RxVoltsNow = 0
local RxVoltsMax = 0
local RxVoltsLow = 0

local MainAmpsNow  = 0
local MainAmpsLow  = 0
local MainAmpsHigh = 0

local RxAmpsNow  = 0
local RxAmpsLow  = 0
local RxAmpsHigh = 0



-- Voltage Checking flags
local CheckBatNotFull = true
local StartTime = getTime()
local PlayFirstInconsistentCellWarning = true
local PlayInconsistentCellWarning = false
local PlayFirstMissingCellWarning = true
local PlayMissingCellWarning = true
local InconsistentCellVoltageDetected = false
local ResetDebounced = true
local MaxWatts = "-----"
local MaxAmps = "-----"

-- Announcements
local BatRemPerFileName = 0		-- updated in PlayPercentRemaining
local BatRemPerPlayed = 0			-- updated in PlayPercentRemaining
local AtZeroPlayedCount				-- updated in init_func, PlayPercentRemaining
local PlayAtZero = 1
--local RxOperational = false
--local BatteryFound = false

local CurrentBatLevelPerc = {}			-- updated in PlayPercentRemaining

--BatRemPerPlayed["main"] = 0
--BatRemPerPlayed["receiver"] = 0

-- Display
local x, y, fontSize, yColumn2
local xAlign = 0

local BlinkWhenZero = 0 -- updated in run_func
local Color = BLACK

-- Based on results from http://rcdiy.ca/taranis-q-x7-battery-run-time/
-- https://blog.ampow.com/lipo-voltage-chart/

-- local VoltToPercentTable = {
--   {3.27, 0},{3.61, 5},
--   {3.69, 10},{3.71, 15},{3.73, 20},{3.75, 25},
--   {3.77, 30},{3.79, 35},{3.80, 40},{3.82, 45},
--   {3.84, 50},{3.85, 55},{3.87, 60},{3.91, 65},
--   {3.95, 70},{3.98, 75},{4.02, 80},{4.08, 85},
--   {4.11, 90},{4.15, 95},{4.20, 100}
-- }

--local VoltToPercentTable = {
--  {4.20, 100},{4.15, 95},{4.11, 90},{4.08, 85},
--  {4.02, 80},{3.98, 75},{3.95, 70},{3.91, 65},
--  {3.87, 60},{3.85, 55},{3.84, 50},{3.82, 45},
--  {3.80, 40},{3.79, 35},{3.77, 30},{3.75, 25},
--  {3.73, 20},{3.71, 15},{3.69, 10},{3.61, 5},
--  {3.27, 0}
--}

local BatteryTypeDischargeCurves = {}

-- todo .. maybe improve to make steps less (0.1) but still take the curve into account
BatteryTypeDischargeCurves["lipo"] = {
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
}


if rxbatType == "buffer" then

  local numberOfPoints = 41 -- this results in steps of 2.5 to match the steps of the lipo definition above
  local bufferbatcurve = {}

  local low = batTypeLowHighValues["buffer"][1]
  local high = batTypeLowHighValues["buffer"][2]

  local step = (high - low) / (numberOfPoints - 1)

  for i = 0, numberOfPoints - 1 do
      local voltage = high - (i * step)
      local percent = (i / (numberOfPoints - 1)) * 100
      print("buffertable voltage: ", voltage)

      table.insert(bufferbatcurve, {voltage, 100 - percent})
  end

  BatteryTypeDischargeCurves["buffer"] = bufferbatcurve

end





local SoundsTable = {[5] = "Bat5L.wav",[10] = "Bat10L.wav",[20] = "Bat20L.wav"
  ,[30] = "Bat30L.wav",[40] = "Bat40L.wav",[50] = "Bat50L.wav"
  ,[60] = "Bat60L.wav",[70] = "Bat70L.wav",[80] = "Bat80L.wav"
  ,[90] = "Bat90L.wav"}


-- -- Example usage
-- local currentModelName = "ModelB123" -- This would be dynamically obtained in a real script
-- local sensor1, sensor2, cellCount = getModelDetails(currentModelName)
-- 
-- -- Print the variables (for debugging)
-- print("Sensor1: " .. sensor1)
-- print("Sensor2: " .. sensor2)
-- print("Cell Count: " .. cellCount)


-- ########################## TESTING ##########################

local soundQueue = {}
local currentState = "idle"
local waitUntil = 0

-- Function to add sound files to the queue
local function queueSound(file, duration, priority)

  priority = priority or false
  local position = priority and 1 or #soundQueue + 1

  print("PQ: insert: ", file)
  table.insert(soundQueue, position, {type = "file", value = soundDirPath..file, duration = duration})
end

local function queueSysSound(file, duration, priority)

  priority = priority or false
  local position = priority and 1 or #soundQueue + 1

  print(string.format("PQ: insert: %s pos: %s", file, position))
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


      print(string.format("PQ: Playing: %s Waiting: %s ... ", item.value, item.duration ))
      
      waitUntil = now + item.duration * 100  -- Convert duration from seconds to centiseconds
      currentState = "waiting"


  elseif currentState == "waiting" then
      
    if now >= waitUntil then
          -- table.remove(soundQueue, 1)  -- Remove the processed item from the queue
          currentState = "idle"
          print("PQ: Idle" )

    end

  end

  return 0  -- Keep the script running
end



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





local function updateAnnouncementConfig(config, batteryDefaults, mainBatType, receiverBatType)

  local function updateBatteryThresholds(section, batType, batTypeDefaults)
      for _, level in pairs({"normal", "warning", "critical"}) do
          if section[level] and section[level].threshold == "useBatTypeDefault" then
              if level == "warning" then
                  section[level].threshold = batTypeDefaults[batType].warningThreshold
              elseif level == "critical" then
                  section[level].threshold = batTypeDefaults[batType].criticalThreshold
              end
          end
      end
  end

  local function updateBatteryNotFullThresholds(section, batType, batTypeDefaults)
      for _, level in pairs({"normal", "warning", "critical"}) do
          if section[level] and section[level].threshold == "useBatTypeDefault" then
              if level == "warning" then
                  section[level].threshold = batTypeDefaults[batType].notFullWarningThreshold
              elseif level == "critical" then
                  section[level].threshold = batTypeDefaults[batType].notFullCriticalThreshold
              end
          end
      end
  end

  -- Update Battery section
  if config.Battery then
      if config.Battery.main then
          updateBatteryThresholds(config.Battery.main, mainBatType, batteryDefaults)
      end
      if config.Battery.receiver then
          updateBatteryThresholds(config.Battery.receiver, receiverBatType, batteryDefaults)
      end
  end

  -- Update BatteryNotFull section
  if config.BatteryNotFull then
      if config.BatteryNotFull.main then
          updateBatteryNotFullThresholds(config.BatteryNotFull.main, mainBatType, batteryDefaults)
      end
      if config.BatteryNotFull.receiver then
          updateBatteryNotFullThresholds(config.BatteryNotFull.receiver, receiverBatType, batteryDefaults)
      end
  end
end






-- Simplified wildcard matching function
local function matchModelName(mname, pattern)

  lmname = string.lower(mname)
  lpattern = string.lower(pattern)

  print("TEST modelName:", mname, "type:", type(mname))
  print("TEST pattern:", pattern, "type:", type(pattern))

 
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

      print(string.format("getcellvoltage: cell: %s volts: %s", i, cellSum))


      -- update the historical voltage table
      if (VoltageHistory[i] and VoltageHistory[i] > v) or VoltageHistory[i] == nil then
        VoltageHistory[i] = v
      end

    end
  else 
    cellSum = cellResult
  end

  print(string.format("getcellvoltage: cellsum: %s", cellSum))

  -- if prevVolt < 1 or cellSum > 1 then
     return cellSum
  -- else
  --   return prevVolt
  -- end

  --return cellSum
end

-- ####################################################################
local function getMaxWatts(sensor)
  if sensor ~= "" then
    amps = getValue( sensor )
    if type(amps) == "number" then
      if type(MaxAmps) == "string" or (type(MaxAmps) == "number" and amps > MaxAmps) then
        MaxAmps = amps
      end
      --watts = amps * voltsNow
      --if type(MaxWatts) == "string" or watts > MaxWatts then
      --  MaxWatts = watts
      --end
    end
  end
end

local function getAmp(sensor)
  if sensor ~= "" then
    amps = getValue( sensor )
    if type(amps) == "number" then
      --if type(MaxAmps) == "string" or (type(MaxAmps) == "number" and amps > MaxAmps) then
      --  MaxAmps = amps
      --end
      --watts = amps * voltsNow
      --if type(MaxWatts) == "string" or watts > MaxWatts then
      --  MaxWatts = watts
      --end
      --return amps

      -- print(string.format("AMPS: P: %s C: %s", prevAmp, amps))

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
-- local function findPercentRem( cellVoltage )
-- 
--   print("Cell Voltage")
--   print(cellVoltage)
-- 
--   if cellVoltage > 4.2 then
--     return 100
--   elseif	cellVoltage < 3.27 then
--     return 0
--   else
--     -- method of finding percent in my array provided by on4mh (Mike)
--     for i, v in ipairs( VoltToPercentTable ) do
--       print(v[ 1 ])
--       if cellVoltage >= v[ 1 ] then
--         return v[ 2 ]
--       end
--     end
--   end
-- end

local function findPercentRem( cellVoltage, battype )

  print("findPercentRem Cell Voltage: ", cellVoltage)
  print("findPercentRem BatType: ", battype)

  local low = batTypeLowHighValues[battype][1]
  local high = batTypeLowHighValues[battype][2]

  local discharcurve = BatteryTypeDischargeCurves[battype]

  if cellVoltage > high then
    return 100
  elseif	cellVoltage < low then
    return 0
  else
    -- method of finding percent in my array provided by on4mh (Mike)
    for i, v in ipairs( discharcurve ) do
      print(string.format("findPercentRem Check Voltage: %s battype %s", v[ 1 ],battype))
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

  print(string.format("TIMER DEBUG: delta: %s time: %s name: %s", deltaseconds, time , name))

  if deltaseconds > time then
    --if noreset ~= nil then
    TriggerTimers[name] = 0 --reset timer
    --end
    return true
  else
    return false
  end

end




-- if not BatFull[device] then
--   --playFile(soundDirPath.."BNFull.wav")
-- 
--   queueSound("warning",0)
-- 
--   print("BATT NOT FULL WARN")
-- 
--   if battype == "m" then
--     queueSound("main",0)
--   else
--     queueSound("receiver",0)
--   end
-- 
--   queueSound("battery",0)
--   queueSound("notfull",0)
-- 
--   
--   --playBatNotFullWarning = false
-- 
-- end



local function PlayPercentRemaining(myperc, mydevice, myseverity)

  local ts = 3
-- todo add haptic feedback option

  queueSound(mydevice ,0)
  queueSound("battery",0)

  if BatNotFullWarn[mydevice] then
    myseverity = "warning"
  end


  if myseverity ~= "normal" then
    queueSound(myseverity, 0)
    ts = ts + 1
  end

  if BatNotFullWarn[mydevice] then
    ts = ts + 1
  queueSound("battery",0)
  queueSound("notfull",0)
  end

  queueNumber(myperc, 13, 0 , ts )

  BatNotFullWarn[mydevice] = false -- we have done our duty ... now leave it for good -- will be reset on reset

end

-- ####################################################################
local function CheckPercentRemaining(perc, battype, device)
  -- Announces percent remaining using the accompanying sound files.
  -- Announcements ever 10% change when percent remaining is above 10 else
  --	every 5%

  local batAnnouceInterval      = batAnnounce[device][2]
  local batWarnAnnounceInterval = batAnnounce[device][4]
  local batCritAnnounceInterval = batAnnounce[device][6]

    -- Intervalls =  -1 = off / 0 = single/on change

  print(string.format("Check Perc Remain: perc: %s battype: %s device: %s", perc, battype, device))  

  if batAnnouceInterval == -1 and batWarnAnnounceInterval == -1 and batCritAnnounceInterval == -1 then
    return -- all intervals set to disable ... so no need to announce anything
  end


    -- prevent "flapping" here
    local batTriggerDelay         = batAnnounce[device][1]

    if CurrentBatLevelPerc[device] ~= perc and not Timer(device.."delay", batTriggerDelay) and CurrentBatLevelPerc[device] ~= nil then
      print(string.format("PPR DEBUG: delay at perc: %s ... state: %s device: %s", perc, currentState, device ))
       -- Timer(device) -- start timer -- timer already started by the if statement above
      return
    end
  
    TriggerTimers[device.."delay"] = 0 --reset timer
    -- delay passed

  local myModVal

  local warn = batTypeWarnCritThresh[battype][1]
  local crit = batTypeWarnCritThresh[battype][2]

  local batNormSteps            = batAnnounce[device][3]
  local batWarnSteps            = batAnnounce[device][5]
  local batCritSteps            = batAnnounce[device][7]

  local currentState, currentInterval

  if perc <= crit then
    myModVal = perc % batCritSteps
    currentState = "critical"
    currentInterval = batCritAnnounceInterval
  elseif perc <= warn then
    myModVal = perc % batWarnSteps
    currentState = "warning"
    currentInterval = batWarnAnnounceInterval
  else
    myModVal = perc % batNormSteps
    currentState = "normal"
    currentInterval = batAnnouceInterval
  end

  if CurrentBatLevelPerc[device] == nil then
    CurrentBatLevelPerc[device] = perc
    PlayPercentRemaining(perc, device, currentState)
    return
  end

  if CurrentBatLevelPerc[device] == perc and currentInterval == 0  then
    CurrentBatLevelPerc[device] = perc
    return -- no change ... and on change requested .... so no announce
  end

  CurrentBatLevelPerc[device] = perc

  if currentInterval < 0 then -- we are not interested to announce at this stage
    return
  end

  if currentInterval > 0  then -- we have to make sure we only announce once the interval has passed
    --CurrentBatLevelPerc[device] = 999 -- special value to make above if statement pass but not trigger the delay timer
      if not Timer(device,currentInterval) then
        print(string.format("PPR DEBUG: WAITING Announce: %s Device: %s", currentInterval, device ))
        return --we have to wait until the announcement interval has been reached
      end
        PlayPercentRemaining(perc, device, currentState)
      return
  end

  if myModVal ~= 0 then -- we are not interested to play at this level in terms of steps
    print(string.format("PPR DEBUG: NO PLAY at: %s MODVAL: %s ", perc, myModVal))
    return
  end

  PlayPercentRemaining(perc, device, currentState)

end

-- ####################################################################
local function HasSecondsElapsed(numSeconds)
  -- return true every numSeconds
  if StartTime == nil then
    StartTime = getTime()
  end
  currTime = getTime()
  deltaTime = currTime - StartTime
  deltaSeconds = deltaTime/100 -- convert to seconds
  deltaTimeMod = deltaSeconds % numSeconds -- return the modulus
  --print(string.format("deltaTime: %f deltaSeconds: %f deltaTimeMod: %f", deltaTime, deltaSeconds, deltaTimeMod))
  if math.abs( deltaTimeMod - 0 ) < 1 then
    return true
  else
    return false
  end
end


-- ####################################################################
-- ####################################################################
-- ####################################################################

local function checkChangedInterval(currentStatus, item, context)
  -- Get the configuration for the item or use announcementConfigDefault
  --local config = announcementConfig[item] or announcementConfigDefault

  -- Determine if the item has context-specific configurations
  local config = announcementConfig[item]
  if config then
    if context and config[context] then
      -- Use the context-specific configuration if available
      config = config[context]
    end
  else
    -- Use the default configuration if item-specific configuration is not found
    config = announcementConfigDefault
  end
  
  
  context = context or "global"

  local itemNameWithContext = context .. item

  -- Initialize statusTable entry for the item if it doesn't exist
  if not statusTable[itemNameWithContext] then
    statusTable[itemNameWithContext] = { lastStatus = nil, lastAnnounceTime = 0, changeStartTime = 0, context = context }
  end

  local itemStatus = statusTable[itemNameWithContext]
  local currentTime = getTime() / 100  -- Get current time in seconds

  print("STCHDET: TEST Status:", currentStatus, "match:", config.warning.threshold, "Context:", context)
  
  -- Determine severity and mode
  local severity, mode = "normal", config.normal.mode
  if type(currentStatus) == "number" then
    if currentStatus <= config.critical.threshold then
      severity, mode = "critical", config.critical.mode
    elseif currentStatus <= config.warning.threshold then
      severity, mode = "warning", config.warning.mode
    end
  elseif type(currentStatus) == "boolean" then
    if currentStatus == config.warning.threshold then
      severity, mode = "warning", config.warning.mode
    elseif currentStatus == config.critical.threshold then
      severity, mode = "critical", config.critical.mode
    end
  end

  print("STCHDET: Item:", item, "Current Status:", currentStatus, "Severity Level:", severity, "Mode:", mode, "Context:", context)

  if mode == "disable" then
    -- Do nothing if announcements are disabled
    print("STCHDET: Announcements are disabled for item:", item, "Context:", context)
    return
  end

  local announceNow = false

  if mode == "change" then
    if itemStatus.lastStatus ~= currentStatus then
      if itemStatus.changeStartTime == 0 then
        -- Start the grace period
        itemStatus.changeStartTime = currentTime
        print("STCHDET: Change detected for item:", item, "Starting grace period at time:", currentTime, "Context:", context)
      else
        local elapsedGracePeriod = currentTime - itemStatus.changeStartTime
        print(string.format("STCHDET: Elapsed grace period for item %s: %.2f seconds", item, elapsedGracePeriod), "Context:", context)
        if elapsedGracePeriod >= config.normal.gracePeriod then
          -- Announce if grace period has passed (config.normal.gracePeriod is in seconds)
          announceNow = true
          print("STCHDET: Grace period passed for item:", item, "Announcing change", "Context:", context)
          itemStatus.lastStatus = currentStatus
        end
      end
    else
      -- Reset grace period if status reverts to previous within grace period
      if itemStatus.changeStartTime ~= 0 then
        print("STCHDET: Status reverted to previous within grace period for item:", item, "Resetting grace period", "Context:", context)
        itemStatus.changeStartTime = 0
      end
    end
  elseif type(mode) == "number" then
    -- Interval mode
    interval = mode
    if (currentTime - itemStatus.lastAnnounceTime) >= interval then
      announceNow = true
      print("STCHDET: Interval passed for item:", item, "Announcing at interval", "Context:", context)
    end
  end

  -- Collect announcements
  if announceNow then
    print("STCHDET: Adding announcement for item:", item, "Current status:", currentStatus, "Severity level:", severity, "Context:", context)
    table.insert(announcements, { item = item, status = currentStatus, severity = severity, context = context })
    itemStatus.lastAnnounceTime = currentTime
  end
end

local function doAnnouncements(context)
  -- checkChangedInterval(85, "telemetry", context) -- Numerical status example
  -- checkChangedInterval("online", "telemetry", context) -- Boolean status example
  -- checkChangedInterval(45, "unknownItem", context) -- Example with an item not in the config

  announcements = {}  -- Clear announcements table at the start of each call


  checkChangedInterval(statusTele, "telemetry")
  checkChangedInterval(cellMissing[context], "BatteryMissingCell", context)
  checkChangedInterval(valueVoltsPercentRemaining[context], "BatteryNotFull", context)
  checkChangedInterval(cellInconsistent[context], "CellDelta", context)
  checkChangedInterval(valueVoltsPercentRemaining[context], "Battery", context)


  

    -- Process collected announcements
    if next(announcements) ~= nil then
      print("STCHDET: Found announcements to be done.")

      local contextAnnounceDone = false

      for _, announcement in ipairs(announcements) do
        print(string.format("STCHDET: Announcing item: %s, Severity: %s, Current value: %s", announcement.item, announcement.severity, announcement.status))
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

          local reverseValue = math.abs(cellMissing[context])

          --queueSound(context,0)
          --queueSound("battery",0)
          queueSound(announcement.severity,0)
          queueSound("missing",0)
          queueNumber(reverseValue, 0, 0 , 0 )
          queueSound("of",0)
          queueNumber(countCell[context], 0, 0 , 0 )
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
          queueNumber(valueVoltsPercentRemaining[context], 13, 0 , 0 )

        else

          --queueSound(context,0)
          --queueSound("battery",0)
          queueNumber(valueVoltsPercentRemaining[context], 13, 0 , 0 )

        end
      end
      
      

      --waiting for,wtf.wav
      --Telemetry,tele.wav





      end
    else
      print("STCHDET: No announcements to be done.")
    end

    
end

-- -- Example usage
-- doAnnouncements("example_context")





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


-- -- ####################################################################
-- local function check_for_full_battery(voltageSensorValue)
--   -- check condition 1: at reset that all voltages > CellFullVoltage volts
-- 
--   --numberofcells = math.ceil(voltageSensorValue / CellFullVoltage)
--   --print("Number of Cells")
--   --print(numberofcells)
-- 
--   print("CHECK BAT FULL")
--   print(BatUsedmAh)
--   print(CheckBatNotFull)
-- 
--   if BatUsedmAh == 0 then -- BatUsedmAh is only 0 at reset
--     --print(string.format("CheckBatNotFull: %s type: %s", CheckBatNotFull, type(voltageSensorValue)))
--     if CheckBatNotFull then  -- global variable to gate this so this check is only done once after reset
--       playBatNotFullWarning = false
-- 
--       if (type(voltageSensorValue) == "table") then -- check to see if this is the dedicated voltage sensor
--         print("flvss cell detection")
--         for i, v in ipairs(voltageSensorValue) do
--           if v < CellFullVoltage then
--             --print(string.format("flvss i: %d v: %f", i,v))
--             playBatNotFullWarning = true
--             break
--           end
--         end
--         CheckBatNotFull = false  -- since we have done the check, set to false so it is not ran again
--       
--       elseif VoltageSensor == "VFAS" and type(voltageSensorValue) == "number" then --this is for the vfas sensor
-- 
--         -- numberofcells = voltageSensorValue / CellFullVoltage
--         -- print("Number of Cells")
--         -- print(numberofcells)
--       
--         print(string.format("vfas: %f", voltageSensorValue))
--         --(string.format("vfas value: %d", voltageSensorValue))
--         if voltageSensorValue < (CellFullVoltage - .001) then
--           --print("vfas cell not full detected")
--           playBatNotFullWarning = true
--         end
--         CheckBatNotFull = false  -- since we have done the check, set to false so it is not ran again
--       end
--       
--       if playBatNotFullWarning then
--         playFile(soundDirPath.."BNFull.wav")
--         playBatNotFullWarning = false
--       
--       end
--     
--     end -- CheckBatNotfull
--   end -- BatUsedmAh
-- end

-- ####################################################################
--local function check_for_full_battery(voltageSensorValue, thresh, expectedcells, BatLowVolt, BatHighVolt)
  local function check_for_full_battery(context)

    if batteryNotFull[context] == nil then -- only perform check once when status has not been determined yet ... otherwise do not waste time

-- check_for_full_battery(currentSensorVoltageValue[context], BatNotFullThresh[typeBattery[context]], countCell[context], batTypeLowHighValues[typeBattery[context]][1], batTypeLowHighValues[typeBattery[context]][2])
-- batteryNotFull

    -- check condition 1: at reset that all voltages > CellFullVoltage volts

  --numberofcells = math.ceil(voltageSensorValue / CellFullVoltage)
  --print("Number of Cells")
  --print(numberofcells)

  local lowBat = false


  if BatUsedmAh == 0 then -- BatUsedmAh is only 0 at reset -- todo
    --print(string.format("CheckBatNotFull: %s type: %s", CheckBatNotFull, type(voltageSensorValue)))
    --if CheckBatNotFull then  -- global variable to gate this so this check is only done once after reset
      --playBatNotFullWarning = false

      print("CHECK BAT FULL", type(currentSensorVoltageValue[context]))
      print(BatUsedmAh)
      print(CheckBatNotFull)
    

      if (type(currentSensorVoltageValue[context]) == "table") then -- check to see if this is the dedicated voltage sensor
        print("flvss cell detection")
        for i, v in ipairs(currentSensorVoltageValue[context]) do

          --perc = findPercentRem( v )


          perc = ((v - batTypeLowHighValues[typeBattery[context]][1]) / (batTypeLowHighValues[typeBattery[context]][2] - batTypeLowHighValues[typeBattery[context]][1])) * 100

          print("FLVSS PERCENTAGE: ", perc)

          if perc < BatNotFullThresh[typeBattery[context]] then
            --print(string.format("flvss i: %d v: %f", i,v))
            --playBatNotFullWarning = true
            lowBat = true

            --break
          end
        end
        --CheckBatNotFull = false  -- since we have done the check, set to false so it is not ran again
      
      --elseif VoltageSensor == "VFAS" and type(voltageSensorValue) == "number" then --this is for the vfas sensor
      elseif type(currentSensorVoltageValue[context]) == "number" then --this is for the vfas sensor

        -- numberofcells = voltageSensorValue / CellFullVoltage
        -- print("Number of Cells")
        -- print(numberofcells)
        celvolt = currentSensorVoltageValue[context] / countCell[context]

        print("VFAS CELL VOLT CALC: ", celvolt)
        print("VFAS CELL VOLT : ", currentSensorVoltageValue[context])
        print("VFAS Expected Cells: ",countCell[context])

        print("VFAS BAT LOW VOLT: ", batTypeLowHighValues[typeBattery[context]][1])
        print("VFAS BAT HIGH VOLT: ", batTypeLowHighValues[typeBattery[context]][2])

        perc = ((celvolt - batTypeLowHighValues[typeBattery[context]][1]) / (batTypeLowHighValues[typeBattery[context]][2] - batTypeLowHighValues[typeBattery[context]][1])) * 100

        print("VFAS PERCENTAGE: ", perc)

      
        print(string.format("vfas: %f", currentSensorVoltageValue[context]))
        --(string.format("vfas value: %d", voltageSensorValue))
        if perc < BatNotFullThresh[typeBattery[context]] then
          --print("vfas cell not full detected")
          --playBatNotFullWarning = true
          lowBat = true
        end
        --CheckBatNotFull = false  -- since we have done the check, set to false so it is not ran again
      end
      
      --if playBatNotFullWarning then
      --  --playFile(soundDirPath.."BNFull.wav")
--
      --  queueSound("warning",0)
--
      --  print("BATT NOT FULL WARN")
--
      --  if battype == "m" then
      --    queueSound("main",0)
      --  else
      --    queueSound("receiver",0)
      --  end
--
      --  queueSound("battery",0)
      --  queueSound("notfull",0)
--
      --  
      --  --playBatNotFullWarning = false
      --
      --end
    
    --end -- CheckBatNotfull

    batteryNotFull[context] = lowBat

  end -- BatUsedmAh

end

end


-- ####################################################################
local function check_cell_delta_voltage(context)
  -- Check to see if all cells are within VoltageDelta volts of each other
  --  default is .3 volts, can be changed above

  --   check_cell_delta_voltage(currentSensorVoltageValue[context])
-- cellInconsistent[context]

  if (type(currentSensorVoltageValue[context]) == "table") then -- check to see if this is the dedicated voltage sensor

    cellInconsistent[context] = false

    for i, v1 in ipairs(currentSensorVoltageValue[context]) do
      for j,v2 in ipairs(currentSensorVoltageValue[context]) do
        -- print(string.format("i: %d v: %f j: %d v: %f", i, v1, j,v2))
        if i~=j and (math.abs(v1 - v2) > VoltageDelta) then
          --print(string.format("i: %d v: %f j: %d v: %f", i, v1, j,v2))
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
          cellInconsistent[context] = true
        end
      end
    end
  end
end

-- ####################################################################
local function check_for_missing_cells(context)
    -- check_for_missing_cells(currentSensorVoltageValue[context], countCell[context])
    -- local function check_for_missing_cells(voltageSensorValue, expectedCells )


  -- If the number of cells detected by the voltage sensor does not match the value in GV6 then play the warning message
  -- This is only for the dedicated voltage sensor
  --print(string.format("CellCount: %d currentSensorVoltageValue[context]:", CellCount))
  if countCell[context] > 0 then

    local missingCellDetected = false

    if (type(currentSensorVoltageValue[context]) == "table") then
      --tableSize = 0 -- Initialize the counter for the cell table size
      --for i, v in ipairs(currentSensorVoltageValue[context]) do
      --  tableSize = tableSize + 1
      --end
      --if tableSize ~= CellCount then
      CellsDetectedCurrent[context] = #currentSensorVoltageValue[context]
      if #currentSensorVoltageValue[context] ~= countCell[context] then
        --print(string.format("CellCount: %d tableSize: %d", CellCount, tableSize))
        
        missingCellDetected = true
      end
    --elseif VoltageSensor == "VFAS" and type(currentSensorVoltageValue[context]) == "number" then --this is for the vfas sensor
    elseif type(currentSensorVoltageValue[context]) == "number" then --this is for the vfas sensor
      CellsDetectedCurrent[context] = math.ceil( currentSensorVoltageValue[context] / ( CellFullVoltage + 0.3) )
      --CellsDetectedCurrent[context] = math.floor( currentSensorVoltageValue[context] / 3.2 )
      --if (countCell[context] * 3.2) > (currentSensorVoltageValue[context]) then
        if CellsDetectedCurrent[context] ~= countCell[context]  then
          --print(string.format("vfas missing cell: %d", currentSensorVoltageValue[context]))
        
        missingCellDetected = true
      end
    end

    --if missingCellDetected then
    --  --print("tableSize =~= CellCount: missing cell detected")
    --  timeElapsed = HasSecondsElapsed(10)
    --  if PlayFirstMissingCellWarning or (PlayMissingCellWarning and timeElapsed) then -- Play immediately and then every 10 seconds
    --    --playFile(soundDirPath.."mcw.wav")
    --    queueSound("mcw",2)
--
    --    --print("play missing cell wav")
    --    PlayMissingCellWarning = false
    --    PlayFirstMissingCellWarning = false
    --  end
    --  if not timeElapsed then  -- debounce so the sound is only played once in 10 seconds
    --    PlayMissingCellWarning = true
    --  end
    --end

    -- cellMissing[context] = missingCellDetected
    cellMissing[context] =  CellsDetectedCurrent[context]  - countCell[context]

    if not cellMissing[context] then
      CellsDetected[context] = true
    end


  end

end


-- ####################################################################
local function voltage_sensor_tests(context)
  -- 1. at reset check to see that the cell voltage is > 4.1 for all cellSum
  -- 2. check to see that all cells are within VoltageDelta volts of each other
  -- 3. if number of cells are set in GV6, check to see that all are showing voltage



  --print("check_initial_battery_voltage")
  -- disabled --if VoltageSensor ~= "" then
    --print("getting VoltageSensor data")
    -- disabled --cellResult = getValue( VoltageSensor )

    -- check condition 1: at reset that all voltages > 4.0 volts
    --check_for_full_battery(cellResult, MainBatNotFullThresh, CellCount, LipoBatLowVolt, LipoBatHighVolt, "m")
    if BatNotFullWarn[context] == nil then
      BatNotFullWarn[context] = check_for_full_battery(currentSensorVoltageValue[context], BatNotFullThresh[typeBattery[context]], countCell[context], batTypeLowHighValues[typeBattery[context]][1], batTypeLowHighValues[typeBattery[context]][2])
    end

    -- check condition 2: delta voltage
      check_cell_delta_voltage(currentSensorVoltageValue[context])

    -- check condition 3: all cells present
      check_for_missing_cells(currentSensorVoltageValue[context], countCell[context])
  -- disabled --end

  -- disabled -- if RxBatVoltSensor ~= "" then
  -- disabled --   --print("getting VoltageSensor data")
  -- disabled --   cellResult = getValue( RxBatVoltSensor )
-- disabled -- 
  -- disabled --   -- check condition 1: at reset that all voltages > 4.0 volts
  -- disabled --   --check_for_full_battery(cellResult, RxBatNotFullThresh, RXCellCount, RxBatLowVolt, RxBatHighVolt, "r" )
  -- disabled --   if BatNotFullWarn["receiver"] == nil then
  -- disabled --     BatNotFullWarn["receiver"] = check_for_full_battery(cellResult, RxBatNotFullThresh, RXCellCount, batTypeLowHighValues[rxbatType][1], batTypeLowHighValues[rxbatType][2], "r" )
  -- disabled --   end
  -- disabled --   -- check condition 2: delta voltage
  -- disabled --     check_cell_delta_voltage(cellResult)
-- disabled -- 
  -- disabled --   -- check condition 3: all cells present
  -- disabled --     check_for_missing_cells(cellResult, RXCellCount)
  -- disabled -- end

  CheckBatNotFull = false  -- since we have done the check, set to false so it is not ran again
  playBatNotFullWarning = false

end


local function printHumanReadableTable(tbl, indent)
  indent = indent or 0
  local function indentStr(level)
      return string.rep("  ", level)
  end

  for key, value in pairs(tbl) do
      local keyStr = tostring(key)
      local valueStr = tostring(value)

      if type(value) == "table" then
          print(indentStr(indent) .. "TBLDBG: " .. keyStr .. " = {")
          printHumanReadableTable(value, indent + 1)
          print(indentStr(indent) .. "TBLDBG: }")
      else
          print(indentStr(indent) .. "TBLDBG: " .. keyStr .. " = " .. valueStr)
      end
  end
end




-- ####################################################################
local function init_func()



  local currentModelName = model.getInfo().name

  print ("TEST MODEL:" , currentModelName)

  modelDetails = getModelDetails(currentModelName)

  rxReferenceVoltage = modelDetails.rxReferenceVoltage
-- Call the resolve function to update thresholds based on BattType
--resolveDynamicValues()

-- printHumanReadableTable(announcementConfig)
typeBattery = {}

typeBattery["main"]           = modelDetails.BattType.main
typeBattery["receiver"]       = modelDetails.BattType.receiver

if typeBattery["receiver"] == "buffer" then --todo the user may name this differently ... like buffer1, buffer2 for different buffer packs ... add a category to BatteryTypeDefaults for buffer and not rely on the name itself

  local low = BatteryTypeDefaults.buffer.lowVoltage / 2
  local high = rxReferenceVoltage / 2

    BatteryTypeDefaults.buffer.dischargeCurve = calculateLinearDischargeCurve(low, high)

end

if typeBattery["receiver"] == "beconly" then --todo the user may name this differently ... like beconly1, beconly2 for different beconly configs ... add a category to BatteryTypeDefaults for buffer and not rely on the name itself

  local low = BatteryTypeDefaults.beconly.lowVoltage / 2
  local high = rxReferenceVoltage / 2

    BatteryTypeDefaults.beconly.dischargeCurve = calculateLinearDischargeCurve(low, high)

end

 

-- Call the function to update the config
updateAnnouncementConfig(announcementConfig, BatteryTypeDefaults, typeBattery["main"], typeBattery["receiver"])



  contexts = {}
  currentContextIndex = 1
--- -- Add entries to the table
--- table.insert(contexts, "main")
--- table.insert(contexts, "receiver")
--- table.insert(contexts, "backup")

  sensorVoltage = {}
  sensorCurrent = {}
  sensorMah = {}
  countCell = {}

  tableBatCapacity = {}

  switchIndexes = {}
  previousSwitchState = {}

  currentSensorVoltageValue = {}
  currentSensorCurrentValue = {}
  currentSensorMahValue = {}

  currentVoltageValueCurrent = {}
  currentCurrentValueCurrent = {}

  currentVoltageValueLatest = {}
  currentCurrentValueLatest = {}

  currentVoltageValueHigh = {}
  currentCurrentValueHigh = {}

  currentVoltageValueLow = {}
  currentCurrentValueLow = {}

  valueVoltsPercentRemaining = {}

  currentMahValue = {}

  CellsDetected = {}

  -- todo --- build variables using context switching

  CellsDetectedCurrent = {}
  CellsDetectedCurrent["main"]      = 0
  CellsDetectedCurrent["receiver"]  = 0

  detectedBattery = {}
  detectedBatteryValid = {}

  numberOfBatteries = 0
  --previousSwitchState = {}

  modelName = modelDetails.modelName
  modelImage = modelDetails.modelImage
  modelWav = modelDetails.modelWav

  queueSound(modelWav,2)

  print("MODEL NAME: ", modelName)
  print("MODEL IMAGE: ",modelImage)
 
  sensorVoltage["main"]         = modelDetails.VoltageSensor.main
  sensorVoltage["receiver"]     = modelDetails.VoltageSensor.receiver

  sensorCurrent["main"]         = modelDetails.CurrentSensor.main
  sensorCurrent["receiver"]     = modelDetails.CurrentSensor.receiver

  sensorMah["main"]             = modelDetails.MahSensor.main
  sensorMah["receiver"]         = modelDetails.MahSensor.receiver



  countCell["main"]             = tonumber(modelDetails.CellCount.main)
  countCell["receiver"]         = tonumber(modelDetails.CellCount.receiver)

  tableBatCapacity["main"]      = modelDetails.capacities["main"]
  tableBatCapacity["receiver"]  = modelDetails.capacities["receiver"]

  currentVoltageValueCurrent["main"] = 0 -- current value even when tele lost
  currentVoltageValueLatest["main"] = 0  -- last value while tele was present
  currentVoltageValueHigh["main"] = 0
  currentVoltageValueLow["main"] = 0

  currentVoltageValueCurrent["receiver"] = 0 -- current value even when tele lost
  currentVoltageValueLatest["receiver"] = 0  -- last value while tele was present
  currentVoltageValueHigh["receiver"] = 0
  currentVoltageValueLow["receiver"] = 0

  currentCurrentValueCurrent["main"] = 0
  currentCurrentValueLatest["main"] = 0
  currentCurrentValueHigh["main"] = 0
  currentCurrentValueLow["main"] = 0

  currentCurrentValueCurrent["receiver"] = 0
  currentCurrentValueLatest["receiver"] = 0
  currentCurrentValueHigh["receiver"] = 0
  currentCurrentValueLow["receiver"] = 0

  valueVoltsPercentRemaining["main"] = 0
  valueVoltsPercentRemaining["receiver"] = 0

  preFlightStatusTele = "unknown"
  preFlightStatusBat = "unknown"

  cellMissing = {}
  cellMissing["main"] = 0
  cellMissing["receiver"] = 0

  cellInconsistent = {}
  cellInconsistent["main"] = false
  cellInconsistent["receiver"] = false

  batteryNotFull = {}
  batteryNotFull["main"] = nil -- nil means not determined yet / on init
  batteryNotFull["receiver"] = nil -- nil means not determined yet / on init



  switchReset                   = modelDetails.resetSwitch
  --statusTele                    = modelDetails.telemetryStatus


  idswitchReset                 = getSwitchIndex(switchReset)
  --idstatusTele                  = getSwitchIndex(statusTele)

  tableSwitchAnnounces          = modelDetails.switchAnnounces
  tableLine1StatSensors         = modelDetails.line1statsensors
  tableLine2StatSensors         = modelDetails.line2statsensors
  tableBattPackSelectorSwitch   = modelDetails.BattPackSelectorSwitch

  -- todo ... is this really needed ?
  detectedBattery["main"] = false
  detectedBattery["receiver"] = false

  detectedBatteryValid["main"] = false
  detectedBatteryValid["receiver"] = false

  batCheckPassed = false


--todo remove/change  
  VoltsNow = 0
  VoltsMax = 0
  VoltsLow = 0
  RxVoltsNow = 0
  RxVoltsMax = 0
  RxVoltsLow = 0
  MainAmpsNow  = 0
  MainAmpsLow  = 0
  MainAmpsHigh = 0
  RxAmpsNow  = 0
  RxAmpsLow  = 0
  RxAmpsHigh = 0



  numOfBatPassedCellCheck = 0

  -- todo: maybe consider/adapt to use cases with only current and/or mah sensors
  if sensorVoltage["main"] ~= nil then
    table.insert(contexts, "main")
    CellsDetected["main"] = false
    --numberOfBatteries = numberOfBatteries + 1
  else
    CellsDetected["main"] = true -- needed to pass sanity check / statuspage
  end

  if sensorVoltage["receiver"] ~= nil then
    table.insert(contexts, "receiver")
    CellsDetected["receiver"] = false
    --numberOfBatteries = numberOfBatteries + 1
  else
    CellsDetected["receiver"] = true -- needed to pass sanity check / statuspage
  end


  for _, switchInfo in ipairs(tableSwitchAnnounces) do
    local switch = switchInfo[1]
    local switchIndex = getFieldInfo(switch).id
    print("ANN SW IDX: ", switch)
    switchIndexes[switch] = switchIndex
  end

  bmpModelImage = Bitmap.open("/IMAGES/" .. modelImage)

  bmpSizedModelImage = Bitmap.resize(bmpModelImage, 400, 300)


-- modelWav
  

  
  -- Called once when model is loaded
  BatCapFullmAh = model.getGlobalVariable(GVBatCap, GVFlightMode) * 100
  -- BatCapmAh = BatCapFullmAh
  BatCapmAh = BatCapFullmAh * (100-CapacityReservePercent)/100
  BatRemainmAh = BatCapmAh
  --CellCount = model.getGlobalVariable(GVCellCount, GVFlightMode)


  BatNotFullWarn = {}
  BatNotFullWarn["main"]   = nil
  BatNotFullWarn["receiver"]   = nil



  CellCount = 0
  RXCellCount = 0

  VoltsPercentRem = 0
  rxVoltsPercentRem = 0

  BatRemPer = 0
  RxBatRemPer = 0
  AtZeroPlayedCount = 0
  if (mAhSensor == "") or (BatCapmAh == 0) then
    UseVoltsNotmAh = true
  else
    UseVoltsNotmAh = false
  end
end

-- -- ####################################################################
-- local function reset_if_needed()
--   -- test if the reset switch is toggled, if so then reset all internal flags
--   if SwReset ~= "" then -- Update switch position
-- 
--     --local SwA = "sg"
--     --local SwB = "sh"
-- 
--     --local swValue = getValue(SwReset) -- a value of -1024, 0 or 1024
-- 
--     --print(getValue(SwA))
--     --print(getValue(SwReset))
-- 
--     if ResetDebounced and HasSecondsElapsed(2) and -1024 ~= getValue(SwReset) then -- reset switch
--       print("reset switch toggled")
--       CheckBatNotFull = true
--       StartTime = nil
--       PlayInconsistentCellWarning = true
--       PlayFirstMissingCellWarning = true
--       PlayMissingCellWarning = true
--       PlayFirstInconsistentCellWarning = true
--       InconsistentCellVoltageDetected = false
-- 
--       PlayRxBatFirstWarning = true
--       PlayRxBatWarning = false
-- 
--       VoltageHistory = {}
--       ResetDebounced = false
--       VoltsNow = 0
--       MaxWatts = "-----"
--       MaxAmps = "-----"
--       --print("reset event")
--     end
--     if not HasSecondsElapsed(2) then
--       --print("debounced")
--       ResetDebounced = true
--     end
--   end
-- end

-- ####################################################################
local function reset_if_needed()
  -- test if the reset switch is toggled, if so then reset all internal flags
  -- if not ResetSwitchState  then -- Update switch position
  -- if ResetSwitchState == nil or AutomaticResetOnResetPrevState ~= ResetSwitchState then -- Update switch position
    --if AutomaticResetOnResetPrevState ~= ResetSwitchState then -- Update switch position

    ResetSwitchState = getSwitchValue(idswitchReset)

    --print("RESET: Switch state :", ResetSwitchState)

    if ResetSwitchState and not AutomaticResetOnNextChange then
      TriggerTimers["resetdelay"] = 0
      return -- no need to do anything when telemetry is on and no reset is needed
    end

    if not ResetSwitchState  and not AutomaticResetOnNextChange then -- no telemetry for longer then delay
  
      if Timer("resetdelay", AutomaticResetOnResetSwitchToggle) then
    --AutomaticResetOnResetPrevState = ResetSwitchState

    --TriggerTimers["resetdelay"] = getTime()

    --print(string.format("RESET: State change Triggered ... Trigger State: %s at Count: %s",ResetSwitchState, AutomaticResetStateChangeCount))

    print("RESET: no telemetry for longer than 4 seconds... will reset at next telemetry on")

    AutomaticResetOnNextChange = true
      end

    end

    --if AutomaticResetOnNextChange then
    --  -- Perform the reset actions
    --  AutomaticResetStateChangeCount = AutomaticResetStateChangeCount + 1
    --  print("RESET: RESETTING")
--
    --  -- Add your reset actions here
    --  -- Example: Reset flags, counters, etc.
    --  AutomaticResetOnNextChange = false
    --  return
    --end


    --if AutomaticResetStateChangeCount > 2 and not Timer("resetdelay", AutomaticResetOnResetSwitchToggle) then
    --  print(string.format("RESET: delay at count: %s ", AutomaticResetStateChangeCount ))
    ----    -- Timer(device) -- start timer -- timer already started by the if statement above
    --return
    --end
    -- # if not Timer("resetdelay", AutomaticResetOnResetSwitchToggle) then
    -- #   print("RESET: NOT reseting yet ... within delay")
    -- #   --AutomaticResetOnResetPrevState = ResetSwitchState
    -- #   --TriggerTimers["resetdelay"] = getTime()
    -- #   return
    -- # end

 --          -- If we have reached here and the timer has expired before, we mark to reset on next change
 --          if not Timer("resetdelay", AutomaticResetOnResetSwitchToggle) then
 --            --AutomaticResetOnNextChange = true
 --            print("RESET: NOT reseting yet ... within delay")
 --            TriggerTimers["resetdelay"] = getTime()
 --            return
 --        end

 --                -- Start or restart the timer on state change
 --      --TriggerTimers["resetdelay"] = getTime()
 --      --print("RESET: Timer started or reset")

 --  --AutomaticResetStateChangeCount = AutomaticResetStateChangeCount + 1

 --  print("RESET: Delay passed, will reset on next change")
---
 --  AutomaticResetOnNextChange = true

 --end

  if ResetSwitchState  and AutomaticResetOnNextChange then
    --return

    -- AutomaticResetOnResetPrevState = ResetSwitchState

    print("RESET: RESETTING")

    TriggerTimers["resetdelay"] = 0

    -- if AutomaticResetStateChangeCount < 10 then
    --   return
    -- end

    -- if CurrentBatLevelPerc[device] ~= perc and not Timer(device.."delay", batTriggerDelay) and CurrentBatLevelPerc[device] ~= nil then
    --   print(string.format("PPR DEBUG: delay at perc: %s ... state: %s device: %s", perc, currentState, device ))
    --    -- Timer(device) -- start timer -- timer already started by the if statement above
    --   return
    -- end
  
  --  test = model.getCustomFunction(FUNC_SCREENSHOT)
  --  print("TEST:", test)
--
  --  for key, value in pairs(test) do
  --    print(string.format("TEST KEY: %s VALUE: %s",key, value))
  --end

    --local SwA = "sg"
    --local SwB = "sh"

    --local swValue = getValue(SwReset) -- a value of -1024, 0 or 1024


 

    --print(getValue(SwA))
    --print(getValue(SwReset))

    --if ResetDebounced and HasSecondsElapsed(2) and -1024 ~= getValue(SwReset) then -- reset switch
      --print("RESET")
      CheckBatNotFull = true
      StartTime = nil
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


      VoltsNow = 0
      VoltsMax = 0
      VoltsLow = 0

      RxVoltsNow = 0
      RxVoltsMax = 0
      RxVoltsLow = 0

      MainAmpsNow  = 0
      MainAmpsLow  = 0
      MainAmpsHigh = 0

      RxAmpsNow  = 0
      RxAmpsLow  = 0
      RxAmpsHigh = 0

      FirstModelInit = true -- todo maybe there is a better place to put this ... maybe init ?

      
      --print("reset event")
    --end
    --if not HasSecondsElapsed(2) then
      --print("debounced")
    --  ResetDebounced = true
    --end
  end
end


-- ####################################################################
local function checkForTelemetry()
  statusTele = getSwitchValue(idstatusTele)

  if not statusTele then
    currentVoltageValueCurrent["main"]     = "--.--"
    currentCurrentValueCurrent["main"]     = "--.--"

    currentVoltageValueCurrent["receiver"] = "--.--"
    currentCurrentValueCurrent["receiver"] = "--.--"
    preFlightStatusTele = "NOT OK. Waiting"
  else
    preFlightStatusTele = "OK"
  end

end

-- ####################################################################
local function updateSensorValues(context)


  currentSensorVoltageValue[context] = getValue(sensorVoltage[context])
  currentSensorCurrentValue[context] = getValue(sensorCurrent[context])
  currentSensorMahValue[context]     = getValue(sensorMah[context])


  -- currentVoltageValueLatest[context] = getCellVoltage(currentSensorVoltageValue[context])
  -- currentCurrentValueLatest[context] = getAmp(sensorCurrent[context]) --todo .. function calls getValue again

  currentVoltageValueCurrent[context] = math.floor(getCellVoltage(currentSensorVoltageValue[context])  * 100) / 100   -- this will hold the current value ... even if no telemetry --> = 0
  currentCurrentValueCurrent[context] = math.floor(getAmp(sensorCurrent[context])   * 100) / 100 --todo .. function calls getValue again -- this will hold the current value ... even if no telemetry --> = 0

  -- local truncatedNumber = math.floor(number * 100) / 100

  -- string.format("%.2f", number)

  print(string.format("Updated Sensor Values: Context: %s Sensor Voltage: %s ( get Cell: %s ) Sensor Current: %s Sensor mah: %s Volt: %s Current: %s mAh: %s", context, sensorVoltage[context], volts , sensorCurrent[context], sensorMah[context], currentSensorVoltageValue[context], currentSensorCurrentValue[context], currentSensorMahValue[context]))

  -- disabled --           if VoltsNow < 1 or volts > 1 then
  -- disabled --             VoltsNow = volts
  -- disabled --           end

  if currentVoltageValueLatest[context] == 0  or currentVoltageValueCurrent[context] ~= 0 then
    currentVoltageValueLatest[context] = currentVoltageValueCurrent[context]
  end

  if currentVoltageValueHigh[context] == 0 or ( currentVoltageValueCurrent[context] > currentVoltageValueHigh[context] and currentVoltageValueCurrent[context] ~= 0.00 ) then
    currentVoltageValueHigh[context] = currentVoltageValueCurrent[context]
  end

  if currentVoltageValueLow[context] == 0 or ( currentVoltageValueCurrent[context] < currentVoltageValueLow[context] and currentVoltageValueCurrent[context] ~= 0.00 ) then
    currentVoltageValueLow[context] = currentVoltageValueCurrent[context]
    print(string.format("Updated Sensor Values Low: Context: %s Sensor Voltage: %s ( get Cell: %s ) Sensor Current: %s Sensor mah: %s Volt: %s Current: %s mAh: %s", context, sensorVoltage[context], currentVoltageValueCurrent[context] , sensorCurrent[context], sensorMah[context], currentSensorVoltageValue[context], currentSensorCurrentValue[context], currentSensorMahValue[context]))
-- Updated Sensor Values Low: Context: main Sensor Voltage: Cels ( get Cell: nil ) Sensor Current: Curr Sensor mah:  Volt: 0 Current: 0 mAh: 0
  end




  if currentCurrentValueLatest[context] == 0 or currentCurrentValueCurrent[context] ~= 0 then
  currentCurrentValueLatest[context] = currentCurrentValueCurrent[context]
  end

  if currentCurrentValueHigh[context] == 0 or ( currentCurrentValueCurrent[context] > currentCurrentValueHigh[context] and currentCurrentValueCurrent[context] ~= 0.00 )   then
    currentCurrentValueHigh[context] = currentCurrentValueCurrent[context]
  end

  if currentCurrentValueLow[context] == 0 or ( currentCurrentValueCurrent[context] < currentCurrentValueLow[context]  and currentCurrentValueCurrent[context] ~= 0.00 )  then
    currentCurrentValueLow[context] = currentCurrentValueCurrent[context]
  end


  

  --if not cellMissing[context] then
    valueVoltsPercentRemaining[context]  = findPercentRem( currentVoltageValueLatest[context]/countCell[context],  typeBattery[context])
    print(string.format("SUPD: Got Percent: %s for Context: %s", valueVoltsPercentRemaining[context], context))
  --end


  -- if VoltsNow < 1 or volts > 1 then
  --   VoltsNow = volts
  -- end

end

-- ####################################################################
-- local function updateTelemetryStatus()
-- 
--  statusTele = getSwitchValue(idstatusTele)
-- 
--  print("TELEMETRY STATUS: ", statusTele)
-- 
-- end

-- ####################################################################
local function checkTelemetryAndBatteryCells(context)

  print("DBG: ", CellsDetected[context])


  if not CellsDetected[context] and ResetSwitchState then


    -- RX Battery
    --volsenval = getValue( RxBatVoltSensor )

    if (type(currentSensorVoltageValue[context]) == "table") then
      numberofcells = #currentSensorVoltageValue[context]
    else
      numberofcells = math.ceil( currentSensorVoltageValue[context] / CellFullVoltage )
    end
  

    -- print("checkTelemetryAndBatteryCells Voltage")
    -- print(currentSensorVoltageValue[context])
-- 
    -- print("checkTelemetryAndBatteryCells Number of Cells")
    -- print(numberofcells)



    -- -- battery
    -- volsenval = getValue( VoltageSensor )
    -- print("TABLE pre:", volsenval)
-- 
    -- if (type(volsenval) == "table") then
    --   numberofcells = #volsenval
    -- else
    --   numberofcells = math.ceil( volsenval / CellFullVoltage )
    -- end
-- 
    -- print("Voltage")
    -- print(volsenval)
-- 
    -- print("Number of Cells")
    -- print(numberofcells)

    --CellCount = numberofcells
--
    --RXCellCount = numberofRXcells

    -- mainvolts = getCellVoltage(VoltageSensor)
    -- rxvolts = getCellVoltage(RxBatVoltSensor)

    print(string.format("CTAB: Cell Count: %s expected: %s sensor value: %s cellcounttype: %s expected type: %s",numberofcells, countCell[context],currentSensorVoltageValue[context],type(numberofcells),type(countCell[context])))

    if numberofcells > 0 and numberofcells == countCell[context] then 

      --Timer("initdone") --todo place this at a better place ... maybe tele reset or init_func

      -- CurrentBatLevelPerc = {}			-- updated in PlayPercentRemaining

      -- todo add timers here to wait for init announcements to finish maybe for loop until timer has ended
      CellsDetected[context] = true
      -- playFile(soundDirPath.."main.wav")
      -- playFile(soundDirPath.."battery.wav")
      -- playNumber(numberofcells, 0, 0 ,5 )
      -- playFile(soundDirPath.."cellbatdetect.wav")
      -- playNumber(mainvolts, 1, 0 ,5 )

      -- screenshot(1)

      t = 7
      queueSound(context, 0)
      queueSound("battery", 0)
      queueNumber(numberofcells, 0, 0, 0)
      queueSound("cellbatdetect", 0)
      queueNumber(currentVoltageValueLatest[context], 1, 0, t)

      detectedBattery[context] = true
      detectedBatteryValid[context] = true

      --queueSound("receiver", 0)
      --queueSound("battery", 0)
      --queueNumber(numberofRXcells, 0, 0, 0)
      --queueSound("cellbatdetect", 0)
      --queueNumber(rxvolts, 1, 0, t)


      --wait(5)

      -- todo ...  ... Batt not full truncated if below enabled ???
      -- todo ...  ... batt levels not played immediately after cell detect

      -- playFile(soundDirPath.."receiver.wav")
      -- playFile(soundDirPath.."battery.wav")
      -- playNumber(numberofRXcells, 0, 0 ,5 )
      -- playFile(soundDirPath.."cellbatdetect.wav")
      -- playNumber(rxvolts, 1, 0 ,5 )

      --wait(5)
     elseif numberofcells > 0 and numberofcells ~= countCell[context] then
       -- todo repeat warning
       t = 5 
       queueSound("critical", 0)
       queueSound(context, 0)
       queueSound("battery", 0)
       queueSound("icw", t )
 
       print(string.format("ICW: Cell Count: %s expected: %s",numberofcells, countCell[context]))
 
       detectedBattery[context] = true
 
 
       --queueNumber(numberofcells, 0, 0, 0)
       --queueSound("cellbatdetect", 0)
       --queueNumber(currentVoltageValueLatest[context], 1, 0, t)
 
    end

  end

end

-- ####################################################################
local function switchAnnounce()

-- switch state announce
for _, switchInfo in ipairs(tableSwitchAnnounces) do
  --local switch, action = switchInfo[1], switchInfo[2]
  local switch = switchInfo[1]

  print(string.format("SWITCH: %s", switch))

  --local swidx = getSwitchIndex(switch)
  local swidx = switchIndexes[switch]

  print(string.format("SWITCH IDX: %s", swidx))

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


  print(string.format("SWITCH OPTIONS COUNT: %s", optionscount))

-- SWITCH: sf STATE: 1024 pre State: -1024 downval: 2 midval: 0 upval: 3


  if previousSwitchState[switch] ~= state or previousSwitchState[switch] == nil then

    --if previousSwitchState[switch] ~=  nil then
    --  print(string.format("SWITCH: %s STATE: %s pre State: %s downval: %s midval: %s upval: %s",  switch, state, previousSwitchState[switch],switchInfo[downval],switchInfo[midval],switchInfo[upval] ) )
  --
    --  end

    if state < 0 and downval ~= 0 then
      queueSysSound(switchInfo[downval], 0, priorizeSwitchAnnouncements)
      print(string.format("SWITCH: %s STATE: %s pre State: %s downval: %s midval: %s upval: %s Play: %s",  switch, state, previousSwitchState[switch],switchInfo[downval],switchInfo[midval],switchInfo[upval],switchInfo[downval] ) )
    elseif state > 0 and upval ~= 0 then
      queueSysSound(switchInfo[upval], 0, priorizeSwitchAnnouncements)
      print(string.format("SWITCH: %s STATE: %s pre State: %s downval: %s midval: %s upval: %s Play: %s",  switch, state, previousSwitchState[switch],switchInfo[downval],switchInfo[midval],switchInfo[upval],switchInfo[upval] ) )

    elseif midval ~= 0 then
      queueSysSound(switchInfo[midval], 0, priorizeSwitchAnnouncements)
      print(string.format("SWITCH: %s STATE: %s pre State: %s downval: %s midval: %s upval: %s Play: %s",  switch, state, previousSwitchState[switch],switchInfo[downval],switchInfo[midval],switchInfo[upval],switchInfo[midval] ) )

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
  --print("Updated Sensor Values TEST: ", sdf)
  
  local currentContext = contexts[currentContextIndex]

  print("Current Context:", currentContext)

  --if HasSecondsElapsed(1) then
  --  return
  --end

  --local idBup = getSwitchIndex("SA" .. CHAR_UP)
  --local idBdown = getSwitchIndex("SA" .. CHAR_DOWN)
  --local idBmid = getSwitchIndex("SA-")
  --
  --local swBup = getSwitchValue(idBup)
  --local swBdown = getSwitchValue(idBdown)
  --local swBmid = getSwitchValue(idBmid)
--
  --local swval = getValue("sa")


  -- test = table.concat(modelDetails.VoltageSensor["main"])
  -- 
  -- print("TEST2:", test)



-- testid = getSwitchIndex("6POS1")
-- 
-- testval = getSwitchValue(testid)
-- 
-- test3 = getValue("6pos")
-- 
-- print("TEST1:", testid)
-- print("TEST2:", testval)
-- print("TEST3:", test3)

-- updateTelemetryStatus()
processQueue()

checkForTelemetry()

switchAnnounce()




-- print("TELE VALUE: ", getSwitchValue(idswitchReset))
-- 
-- ResetSwitchState = getSwitchValue(idswitchReset)
-- resetSwitch_ID

-- reset if needed
  reset_if_needed() -- test if the reset switch is toggled, if so then reset all internal flags
  
 -- tele_ON = getSwitchValue(resetSwitch_ID)

 -- for the current context


 if statusTele then -- if we have no telemetry .... don't waste time doing anything that requires telemetry

  updateSensorValues(currentContext)


  -- make sure we have cells/voltage availablwe


  -- checkTelemetryAndBatteryCells(currentContext)

  -- queueSound("main", 5)
  -- queueNumber(12, 0, 0, 5)

  --print("RXBAT")
  --print(getValue("RxBt"))

  -- Check in battery capacity was changed
  -- disabled -- if BatCapFullmAh ~= model.getGlobalVariable(GVBatCap, GVFlightMode) * 100 then
  -- disabled --   init_func()
  -- disabled -- end

  -- mahSensor
  -- disabled -- if mAhSensor ~= "" then
  -- disabled --   BatUsedmAh = getValue(mAhSensor)
  -- disabled --   if (BatUsedmAh == 0) and CanCallInitFuncAgain then
  -- disabled --     -- BatUsedmAh == 0 when Telemetry has been reset or model loaded
  -- disabled --     -- BatUsedmAh == 0 when no battery used which could be a long time
  -- disabled --     --	so don't keep calling the init_func unnecessarily.
  -- disabled --     init_func()
  -- disabled --     CanCallInitFuncAgain = false
  -- disabled --   elseif BatUsedmAh > 0 then
  -- disabled --     -- Call init function again when Telemetry has been reset
  -- disabled --     CanCallInitFuncAgain = true
  -- disabled --   end
  -- disabled --   BatRemainmAh = BatCapmAh - BatUsedmAh
  -- disabled -- end -- mAhSensor ~= ""



  -- get voltages and bat percentages

  -- disabled --         if VoltageSensor ~= "" then
  -- disabled --           --volts = getCellVoltage(VoltageSensor)
  -- disabled --           volts = getCellVoltage(currentSensorVoltageValue[currentContext])
  -- disabled --           --if VoltsNow < 1 or volts > 1 then
  -- disabled --           --  VoltsNow = volts
  -- disabled --           --end
  -- disabled --           --VoltsNow = getCellVoltage(VoltageSensor)
  -- disabled --           
  -- disabled --           --VoltsMax = getCellVoltage(VoltageSensor.."+", VoltsMax)
  -- disabled --           --VoltsLow = getCellVoltage(VoltageSensor.."-", VoltsLow)
-- disabled --         
  -- disabled --           print("DBG vol sen: ", currentSensorVoltageValue[currentContext] )
  -- disabled --           print("DBG: ", volts )
-- disabled --         
  -- disabled --           if VoltsNow < 1 or volts > 1 then
  -- disabled --             VoltsNow = volts
  -- disabled --           end
-- disabled --         
  -- disabled --           if VoltsMax < 1 or volts > VoltsMax then
  -- disabled --             VoltsMax = volts
  -- disabled --           end
-- disabled --         
  -- disabled --           if VoltsLow < 1 or volts < VoltsLow then
  -- disabled --             VoltsLow = volts
  -- disabled --           end
-- disabled --         
-- disabled --         
  -- disabled --           getMaxWatts(CurrentSensor)
-- disabled --         
  -- disabled --           amps  = getAmp(CurrentSensor)
  -- disabled --           --MainAmpsLow  = getAmp(CurrentSensor.."-", MainAmpsLow)
  -- disabled --           --MainAmpsHigh = getAmp(CurrentSensor.."+", MainAmpsHigh)
-- disabled --         
-- disabled --         
  -- disabled --           if MainAmpsNow < 1 or amps > 0.00001 then
  -- disabled --             MainAmpsNow = amps
  -- disabled --           end
-- disabled --         
  -- disabled --           if MainAmpsHigh < 1 or amps > MainAmpsHigh then
  -- disabled --             MainAmpsHigh = amps
  -- disabled --           end
-- disabled --         
  -- disabled --           if MainAmpsLow < 1 or amps < MainAmpsLow then
  -- disabled --             MainAmpsLow = amps
  -- disabled --           end
-- disabled --         
-- disabled --         
  -- disabled --           --CellCount = math.ceil(VoltsMax / 4.25)
  -- disabled --           if CellCount > 0 then
  -- disabled --             VoltsPercentRem  = findPercentRem( VoltsNow/CellCount,  mainbattype)
  -- disabled --             print("GOT BAT PERC")
  -- disabled --             print(VoltsPercentRem)
  -- disabled --           end
  -- disabled --         end
-- disabled --         
-- disabled --         
  -- disabled --         if RxBatVoltSensor ~= "" then
  -- disabled --           --volts = getCellVoltage(RxBatVoltSensor)
  -- disabled --           volts = getCellVoltage(currentSensorVoltageValue[currentContext])
-- disabled --         
  -- disabled --           --if RxVoltsNow < 1 or volts > 1 then
  -- disabled --           --  RxVoltsNow = volts
  -- disabled --           --end
  -- disabled --           --VoltsNow = getCellVoltage(VoltageSensor)
  -- disabled --           -- RxVoltsMax = getCellVoltage(RxBatVoltSensor.."+", RxVoltsMax)
  -- disabled --           -- RxVoltsLow = getCellVoltage(RxBatVoltSensor.."-", RxVoltsLow)
-- disabled --         
-- disabled --         
  -- disabled --           if RxVoltsNow < 1 or volts > 1 then
  -- disabled --             RxVoltsNow = volts
  -- disabled --           end
-- disabled --         
  -- disabled --           if RxVoltsMax < 1 or volts > RxVoltsMax then
  -- disabled --             RxVoltsMax = volts
  -- disabled --           end
-- disabled --         
  -- disabled --           if RxVoltsLow < 1 or volts < RxVoltsLow then
  -- disabled --             RxVoltsLow = volts
  -- disabled --           end
-- disabled --         
-- disabled --         
  -- disabled --           
  -- disabled --           -- TODO make this cleaner
  -- disabled --           getMaxWatts(RxBatCurrSensor)
-- disabled --         
  -- disabled --           amps  = getAmp(RxBatCurrSensor)
  -- disabled --           --xAmpsLow  = getAmp(RxBatCurrSensor.."-", RxAmpsLow)
  -- disabled --           --xAmpsHigh = getAmp(RxBatCurrSensor.."+", RxAmpsHigh)
-- disabled --         
-- disabled --         
  -- disabled --           if RxAmpsNow < 1 or amps > 0.00001 then
  -- disabled --             RxAmpsNow = amps
  -- disabled --           end
-- disabled --         
  -- disabled --           if RxAmpsHigh < 1 or amps > RxAmpsHigh then
  -- disabled --             RxAmpsHigh = amps
  -- disabled --           end
-- disabled --         
  -- disabled --           if RxAmpsLow < 1 or amps < RxAmpsLow then
  -- disabled --             RxAmpsLow = amps
  -- disabled --           end
-- disabled --         
-- disabled --         
-- disabled --         
  -- disabled --           --CellCount = math.ceil(VoltsMax / 4.25)
  -- disabled --           if RXCellCount > 0 then
  -- disabled --             rxVoltsPercentRem  = findPercentRem( RxVoltsNow/RXCellCount, rxbatType )
  -- disabled --             print("GOT RX BAT PERC:", rxVoltsPercentRem)
  -- disabled --           end
  -- disabled --         end




  -- if not ResetSwitchState or not CellsDetected[currentContext] then
  --   return
  -- end

  --check_rxbat()

  -- Update battery remaining percent
 -- disabled --  if UseVoltsNotmAh then
 -- disabled --    BatRemPer = VoltsPercentRem - CapacityReservePercent
 -- disabled --    --elseif BatCapFullmAh > 0 then
 -- disabled --  elseif BatCapmAh > 0 then
 -- disabled --    -- BatRemPer = math.floor( (BatRemainmAh / BatCapFullmAh) * 100 ) - CapacityReservePercent
 -- disabled --    BatRemPer = math.floor( (BatRemainmAh / BatCapFullmAh) * 100 )
 -- disabled --  end


  -- disabled -- -- Update RX battery remaining percent
  -- disabled -- if UseVoltsNotmAh then
  -- disabled --   RxBatRemPer = rxVoltsPercentRem - CapacityReservePercent
  -- disabled --   --elseif BatCapFullmAh > 0 then
  -- disabled -- elseif BatCapmAh > 0 then
  -- disabled --   -- BatRemPer = math.floor( (BatRemainmAh / BatCapFullmAh) * 100 ) - CapacityReservePercent
  -- disabled --   RxBatRemPer = math.floor( (BatRemainmAh / BatCapFullmAh) * 100 )
  -- disabled -- end

  -- voltage_sensor_tests(currentContext)

  -- check_for_missing_cells(currentSensorVoltageValue[currentContext], countCell[currentContext])
  check_for_missing_cells(currentContext)

  if cellMissing[currentContext] == 0 then -- if cell number is fine we have got voltage and can do the rest of the checks

  -- check_for_full_battery(currentSensorVoltageValue[currentContext], BatNotFullThresh[typeBattery[currentContext]], countCell[currentContext], batTypeLowHighValues[typeBattery[currentContext]][1], batTypeLowHighValues[typeBattery[currentContext]][2])
  check_for_full_battery(currentContext)

  check_cell_delta_voltage(currentContext)

  end


  --if AnnouncePercentRemaining and Timer("initdone", initTime) then -- don't announce anything until init is done
-- disabled --   if AnnouncePercentRemaining and valueVoltsPercentRemaining[currentContext] ~= 0 then -- don't announce anything until init is done
-- disabled --   -- CheckPercentRemaining(BatRemPer, mainbattype, "main")
-- disabled --   -- CheckPercentRemaining(RxBatRemPer, rxbatType, "receiver")
-- disabled -- 
-- disabled --   CheckPercentRemaining(valueVoltsPercentRemaining[currentContext], typeBattery[currentContext], currentContext)
-- disabled -- 
-- disabled --   -- valueVoltsPercentRemaining[context]
-- disabled --   
-- disabled -- 
-- disabled -- end

  -- disabled -- if WriteGVBatRemmAh == true then
  -- disabled --   model.setGlobalVariable(GVBatRemmAh, GVFlightMode, math.floor(BatRemainmAh/100))
  -- disabled -- end
-- disabled -- 
  -- disabled -- if WriteGVBatRemPer == true then
  -- disabled --   model.setGlobalVariable(GVBatRemPer, GVFlightMode, BatRemPer)
  -- disabled -- end
  --print(string.format("\nBatRemainmAh: %d", BatRemainmAh))
  --print(string.format("BatRemPer: %d", BatRemPer))
  --print(string.format("CellCount: %d", CellCount))
  --print(string.format("VoltsMax: %d", VoltsMax))
  --print(string.format("BatUsedmAh: %d", BatUsedmAh))

  if CellsDetected["main"] and CellsDetected["receiver"] then -- sanity checks passed ... we can move to normal operation and switch the status widget
   batCheckPassed = true
   preFlightStatusBat = "OK"
  else
    preFlightStatusBat = "Check Battery"
  end


end -- end of if telemetry

doAnnouncements(currentContext)


      -- Update the index to cycle through the contexts using the modulo operator
      currentContextIndex = (currentContextIndex % #contexts) + 1

end

-- ####################################################################
local function getPercentColor(cpercent, battype)
  -- This function returns green at 100%, red bellow 30% and graduate in between

  local warn = batTypeWarnCritThresh[battype][1] 

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
local function drawBattery(xOrigin, yOrigin, percentage, wgt, battype)
    local myBatt = { ["x"] = xOrigin,
                     ["y"] = yOrigin,
                     ["w"] = 120,
                     ["h"] = 40,
                     ["segments_w"] = 15,
                     ["color"] = WHITE,
                     ["cath_w"] = 6,
                     ["cath_h"] = 22 }

  lcd.setColor(CUSTOM_COLOR, wgt.options.Color)

  if percentage > 0 then -- Don't blink
    BlinkWhenZero = 0
  else
    BlinkWhenZero = BLINK
  end

  -- fill batt
  lcd.setColor(CUSTOM_COLOR, getPercentColor(percentage, battype))
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
  lcd.drawText(wgt.zone.x + myBatt.x + 20, wgt.zone.y + myBatt.y + 5, string.format("%d%%", percentage), LEFT + MIDSIZE + CUSTOM_COLOR)

    -- draw values
  lcd.drawText(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y + 40,
          string.format("%d mAh", BatRemainmAh), MIDSIZE + Color + BlinkWhenZero)
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
  drawBattery(0,0, BatRemPer, wgt)

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

-- ####################################################################
local function refreshZoneLarge(wgt)
  --- Size is 192x152 1/2
  lcd.setColor(CUSTOM_COLOR, wgt.options.Color)
  
  fontSize = 10
  
    if BatRemPer > 0 then -- Don't blink
    BlinkWhenZero = 0
  else
    BlinkWhenZero = BLINK
  end
  lcd.drawText(wgt.zone.x + 5, wgt.zone.y + fontSize, "BATTERY LEFT", SHADOWED)
  lcd.setColor(CUSTOM_COLOR, getPercentColor(BatRemPer))
  lcd.drawText(wgt.zone.x + 5, wgt.zone.y + fontSize + 25, round(BatRemPer).."%" , DBLSIZE + SHADOWED + BlinkWhenZero)
  lcd.drawText(wgt.zone.x + 5, wgt.zone.y + fontSize + 55, math.floor(BatRemainmAh).."mAh" , DBLSIZE + SHADOWED + BlinkWhenZero)

  lcd.setColor(CUSTOM_COLOR, wgt.options.Color)
  lcd.drawRectangle((wgt.zone.x - 1) , (wgt.zone.y + (wgt.zone.h - 31)), (wgt.zone.w + 2), 32, 0)
  lcd.setColor(CUSTOM_COLOR, getPercentColor(BatRemPer))
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

  if type(currentVoltageValueCurrent["main"]) ~= "number" or currentVoltageValueCurrent["main"] == 0 then -- Blink
    mainVoltBlink = BLINK
  else
    mainVoltBlink = 0
  end

  if type(currentCurrentValueCurrent["main"]) ~= "number" or currentCurrentValueCurrent["main"] == 0 then -- Blink
    mainCurrentBlink = BLINK
  else
    mainCurrentBlink = 0
  end


  if type(currentVoltageValueCurrent["receiver"]) ~= "number" or currentVoltageValueCurrent["receiver"] == 0 then -- Blink
    rxVoltBlink = BLINK
  else
    rxVoltBlink = 0
  end

  if type(currentCurrentValueCurrent["receiver"]) ~= "number" or currentCurrentValueCurrent["receiver"] == 0 then -- Blink
    rxCurrentBlink = BLINK
  else
    rxCurrentBlink = 0
  end



  if batCheckPassed or not ShowPreFlightStatus then


  -- Draw the top-left 1/4 of the screen
  --drawCellVoltage(wgt, cellResult)



    -- Draw the bottom-left 1/4 of the screen
    drawBattery(40, 100, valueVoltsPercentRemaining["main"], wgt,typeBattery["main"] )

    -- Draw the top-right 1/4 of the screen
    --lcd.drawText(wgt.zone.x + 270, wgt.zone.y + -5, string.format("%.2fV", VoltsNow), DBLSIZE + Color)
    lcd.drawText(wgt.zone.x + 10, wgt.zone.y + -5, "Main Battery", MIDSIZE + Color + SHADOWED)
    lcd.drawText(wgt.zone.x + 10, wgt.zone.y + 23, "C: Current / L: Lowest / H: Highest", SMLSIZE + Color )
  
    amps = getValue( CurrentSensor )
    --lcd.drawText(wgt.zone.x + 270, wgt.zone.y + 25, string.format("%.1fA", amps), DBLSIZE + Color)

    --maincur = getValue(VoltageSensor)
    --maincurmax = getValue(VoltageSensor.."+")
  
    lcd.drawText(wgt.zone.x + 10, wgt.zone.y + 40, string.format("C: %sV", currentVoltageValueCurrent["main"]), MIDSIZE + COLOR_THEME_SECONDARY1 + mainVoltBlink )
    --lcd.drawText(wgt.zone.x + 95, wgt.zone.y + 35, "/", MIDSIZE + Color)
    lcd.drawText(wgt.zone.x + 120, wgt.zone.y + 40, string.format("L: %sV", currentVoltageValueLow["main"]), MIDSIZE + Color)
    

    lcd.drawText(wgt.zone.x + 10, wgt.zone.y + 70, string.format("C: %sA", currentCurrentValueCurrent["main"]), MIDSIZE + COLOR_THEME_SECONDARY1 + mainCurrentBlink)
    --lcd.drawText(wgt.zone.x + 95, wgt.zone.y + 65, "/", MIDSIZE + Color)
    lcd.drawText(wgt.zone.x + 120, wgt.zone.y + 70, string.format("H: %sA", currentCurrentValueHigh["main"]), MIDSIZE + Color)






    lcd.drawText(wgt.zone.x + 10, wgt.zone.y + 170, "RPM [L: 1000 H: 2000] RSSI [L: 11 H: 32]", SMLSIZE + Color )





    --watts = math.floor(amps * VoltsNow)



  --rxcur = getValue(RxBatVoltSensor)
  --rxcurmax = getValue(RxBatVoltSensor.."+")


  lcd.drawText(wgt.zone.x + 240, wgt.zone.y + -5, "Receiver Battery", MIDSIZE + Color + SHADOWED)
  lcd.drawText(wgt.zone.x + 240, wgt.zone.y + 23, "C: Current / L: Lowest / H: Highest", SMLSIZE + Color )

  --lcd.drawText(wgt.zone.x + 240, wgt.zone.y + 40, string.format("%.2fV / %.2fV", RxVoltsNow, RxVoltsMax), MIDSIZE + Color)

  lcd.drawText(wgt.zone.x + 240, wgt.zone.y + 40, string.format("C: %sV", currentVoltageValueCurrent["receiver"]), MIDSIZE + COLOR_THEME_SECONDARY1 + rxVoltBlink)
  --lcd.drawText(wgt.zone.x + 95, wgt.zone.y + 35, "/", MIDSIZE + Color)
  lcd.drawText(wgt.zone.x + 350, wgt.zone.y + 40, string.format("L: %sV", currentVoltageValueLow["receiver"]), MIDSIZE + Color)

  lcd.drawText(wgt.zone.x + 240, wgt.zone.y + 70, string.format("C: %sA",  currentCurrentValueCurrent["receiver"]), MIDSIZE + COLOR_THEME_SECONDARY1 + rxCurrentBlink)
  --lcd.drawText(wgt.zone.x + 95, wgt.zone.y + 65, "/", MIDSIZE + Color)
  lcd.drawText(wgt.zone.x + 350, wgt.zone.y + 70, string.format("H: %sA", currentCurrentValueHigh["receiver"]), MIDSIZE + Color)



  drawBattery(270, 100, valueVoltsPercentRemaining["receiver"], wgt,typeBattery["receiver"] )

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
  Color = options.Color
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
