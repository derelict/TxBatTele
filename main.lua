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
  {"sf","disarm","armed"},
  {"sh","safeon"},
  {"se","fm-nrm","fm-1","fm-2"}
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


local defaultAdlSensors = {
  --- first bottom line
  { sensorName = "RPM+" , displayName = "RPM+", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, value = 1, unit = "" },
  { sensorName = "RPM-" , displayName = "RPM-", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = RED   , suffixColor = BLUE, value = 2, unit = "" },
  { sensorName = "RxBt+" , displayName = "BEC+", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, value = 3, unit = "V" },
  { sensorName = "RxBt-" , displayName = "BEC-", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = RED   , suffixColor = BLUE, value = 4, unit = "V" },
  --- second line from the bottom
  { sensorName = "RSSI+", displayName = "FLS ", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = RED   , suffixColor = BLUE, value = 5, unit = "" },
  { sensorName = "RSSI+", displayName = "FDE ", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = RED   , suffixColor = BLUE, value = 6, unit = "" },
  { sensorName = "Fuel+", displayName = "HLD ", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = RED   , suffixColor = BLUE, value = 7, unit = "" },
  { sensorName = "Fuel-", displayName = "TRS ", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = RED   , suffixColor = BLUE, value = 8, unit = "" },
  -- third line from the bottom (will not be shown on smaller widget sizes)
  { sensorName = "Tmp1+" , displayName = "TF+ ", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = RED   , suffixColor = BLUE, value = 9,  unit = "°C" },
  { sensorName = "Tmp1-" , displayName = "TF- ", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN   , suffixColor = BLUE, value = 10, unit = "°C" },
  { sensorName = "Tmp2+" , displayName = "ET+ ", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = RED   , suffixColor = BLUE, value = 11, unit = "°C" },
  { sensorName = "Tmp2-" , displayName = "ET- ", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN   , suffixColor = BLUE, value = 12, unit = "°C" }
}

local sensg580 = {
  --- first bottom line
  { sensorName = "Erpm+" , displayName = "RPM+", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, value = 1, unit = "" },
  { sensorName = "Erpm-" , displayName = "RPM-", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = RED   , suffixColor = BLUE, value = 2, unit = "" },
  { sensorName = "VBEC+" , displayName = "BEC+", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, value = 3, unit = "V" },
  { sensorName = "VBEC-" , displayName = "BEC-", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = RED   , suffixColor = BLUE, value = 4, unit = "V" },
  --- second line from the bottom
  { sensorName = "FLss+", displayName = "FLS", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = RED   , suffixColor = BLUE, value = 5, unit = "" },
  { sensorName = "FdeA+", displayName = "FDE", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = RED   , suffixColor = BLUE, value = 6, unit = "" },
  { sensorName = "Hold+", displayName = "HLD", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = RED   , suffixColor = BLUE, value = 7, unit = "" },
  { sensorName = "TRSS-", displayName = "TRS", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = RED   , suffixColor = BLUE, value = 8, unit = "" },
  -- third line from the bottom (will not be shown on smaller widget sizes)
  { sensorName = "TFET+" , displayName = "TF+", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = RED   , suffixColor = BLUE, value = 9,  unit = "°C" },
  { sensorName = "TFET-" , displayName = "TF-", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN   , suffixColor = BLUE, value = 10, unit = "°C" },
  { sensorName = "RB1T+" , displayName = "ET+", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = RED   , suffixColor = BLUE, value = 11, unit = "°C" },
  { sensorName = "RB1T-" , displayName = "ET-", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN   , suffixColor = BLUE, value = 12, unit = "°C" }
}

local sensSimulator = {
  --- first bottom line
  { sensorName = "RPM+" , displayName = "RPM+", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, value = 1, unit = "" },
  { sensorName = "RPM-" , displayName = "RPM-", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = RED   , suffixColor = BLUE, value = 2, unit = "" },
  { sensorName = "RxBt+" , displayName = "RXB+", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, value = 3, unit = "V" },
  { sensorName = "RxBt-" , displayName = "RXB-", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = RED   , suffixColor = BLUE, value = 4, unit = "V" },
  --- second line from the bottom
  { sensorName = "RSSI+", displayName = "RSI+", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN   , suffixColor = BLUE, value = 5, unit = "" },
  { sensorName = "RSSI-", displayName = "RSI-", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = RED   , suffixColor = BLUE, value = 6, unit = "" },
  { sensorName = "Fuel+", displayName = "FUE+", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN   , suffixColor = BLUE, value = 7, unit = "" },
  { sensorName = "Fuel-", displayName = "FUE-", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = RED   , suffixColor = BLUE, value = 8, unit = "" },
  -- third line from the bottom (will not be shown on smaller widget sizes)
  { sensorName = "Tmp1+" , displayName = "TP1+", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = RED   , suffixColor = BLUE, value = 9,  unit = "°C" },
  { sensorName = "Tmp1-" , displayName = "TP1-", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN   , suffixColor = BLUE, value = 10, unit = "°C" },
  { sensorName = "Tmp2+" , displayName = "TP2+", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = RED   , suffixColor = BLUE, value = 11, unit = "°C" },
  { sensorName = "Tmp2-" , displayName = "TP2-", prefix = "[", suffix = "]", displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN   , suffixColor = BLUE, value = 12, unit = "°C" }
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
    modelNameMatch         = "580t",
    modelName              = "SAB RAW 580",
    modelImage             = "580.png",
    modelWav               = "sr580",
    rxReferenceVoltage     = 7.85,
    resetSwitch            = "TELE",
    VoltageSensor          = {
      main =      { sensorName = "RB1V"  },
      receiver =  { sensorName = "RB2V"  }
      },
    CurrentSensor          = {
      main =      { sensorName = "RB1A"  },
      receiver =  { sensorName = ""  }
      },
    MahSensor              = {
      main =      { sensorName = "RB1C"  },
      receiver =  { sensorName = ""  }
      },
    AdlSensors             = sensg580,
    battery                = { main = Batteries.lipo ,    receiver = Batteries.buffer },
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
      AdlSensors             = sensSimulator,
      battery               = { main = Batteries.lipo ,    receiver = Batteries.buffer },
      CellCount              = { main = 8,         receiver = 2 },
      capacities             = { main = { 500, 1000, 1500, 2000, 2500, 3000 }, receiver = { 500, 1000, 1500, 2000, 2500, 3000 } },
      switchAnnounces        = SwitchAnnounceTable,
      BattPackSelectorSwitch = BattPackSelectorSwitch
  }
}

local findPercentRempreviousValues = {}

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


-- local function format_number(number)
--   -- Check if the number has decimals
--   if math.floor(number) == number then
--       return tostring(number)  -- Return the number as-is if it's an integer
--   else
--       return string.format("%.2f", number)  -- Format to two decimal places if it's a float
--   end
-- end

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

-- local function findPercentRem( cellVoltage, context )
-- 
--   debugPrint("findPercentRem Cell Voltage: ", cellVoltage)
--   debugPrint("findPercentRem context: ", context)
-- 
-- 
--   if cellVoltage > thisModel.battery[context].highVoltage then
--     return 100
--   elseif	cellVoltage < thisModel.battery[context].lowVoltage then
--     return 0
--   else
--     -- method of finding percent in my array provided by on4mh (Mike)
--     for i, v in ipairs( thisModel.battery[context].dischargeCurve ) do
--       debugPrint(string.format("findPercentRem Check Voltage: %s ", v[ 1 ]))
--       if cellVoltage >= v[ 1 ] then
--         return v[ 2 ]
--       end
--     end
--   end
-- end

-- -- Store previous values and timestamps for each context
-- local previousValues = {}
-- local changeTimestamps = {}

local function findPercentRem(cellVoltage, context)
  debugPrint("findPercentRem Cell Voltage: ", cellVoltage)
  debugPrint("findPercentRem context: ", context)

  if cellVoltage > thisModel.battery[context].highVoltage then
    return 100
  elseif cellVoltage < thisModel.battery[context].lowVoltage then
    return 0
  else
    -- Method of finding percent in array provided by on4mh (Mike)
    for i, v in ipairs(thisModel.battery[context].dischargeCurve) do
      debugPrint(string.format("findPercentRem Check Voltage: %s Context %s", v[1], context))
      if cellVoltage >= v[1] then
        local newPercent = v[2]

        -- Initialize previous values if not present
        if not findPercentRempreviousValues[context] then
          findPercentRempreviousValues[context] = newPercent
          return newPercent
        end

        local previousPercent = findPercentRempreviousValues[context]
        local gracePeriod = thisModel.battery[context].graceperiod

        debugPrint(string.format("findPercentRem CHG Previous Percent: %s", previousPercent))
        debugPrint(string.format("findPercentRem CHG Grace Period: %s", gracePeriod))

        -- Check if new value is different from the previous one
        if newPercent ~= previousPercent then
          -- Use Timer function to check grace period
          if Timer(context, gracePeriod) then
            findPercentRempreviousValues[context] = newPercent
            return newPercent
          else
            return previousPercent
          end
        else
          -- Reset the timer if the value hasn't changed
          --Timer(context, nil)
          TriggerTimers[context] = 0
          return previousPercent
        end
      end
    end
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
  --graceP = config.graceperiod
  graceP = 0 -- done in findpercremaining now


end


if item == "BatteryNotFull" then

  --config = BatteryDefinition[typeBattery[context]]
  config = thisModel.battery[context]

  critTH = config.notFullCriticalThreshold
  warnTH = config.notFullWarningThreshold
  critMD = config.announceNotFullCriticalMode
  warnMD = config.announceNotFullWarningMode
  normMD = "disable"
  --graceP = config.graceperiod
  graceP = 0 -- done in findpercremaining now


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
  if not preFlightChecksPassed then checkChangedInterval(thisModel.VoltageSensor[context].PercRem, "BatteryNotFull", context) end
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
    --local CfullVolt = thisModel.battery[context].highVoltage

--debugPrint("MC VOL:" .. CfullVolt)

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
      --thisModel.VoltageSensor[context].CellsDetectedCurrent = math.ceil( thisModel.VoltageSensor[context].value / ( CfullVolt + 0.3) ) --todo 0.3 ??

      thisModel.VoltageSensor[context].CellsDetectedCurrent = math.floor(thisModel.VoltageSensor[context].value / thisModel.battery[context].lowVoltage )

      --thisModel.VoltageSensor[context].CellsDetectedCurrent = math.floor( thisModel.VoltageSensor[context].value / 3.2 )
      --if (thisModel.CellCount[context] * 3.2) > (thisModel.VoltageSensor[context].value) then
        if thisModel.VoltageSensor[context].CellsDetectedCurrent ~= thisModel.CellCount[context]  then
          --debugPrint(string.format("vfas missing cell: %d", thisModel.VoltageSensor[context].value))
        
        missingCellDetected = true
      end
    end



    -- cellMissing[context] = missingCellDetected
    thisModel.VoltageSensor[context].cellMissing =  thisModel.VoltageSensor[context].CellsDetectedCurrent  - thisModel.CellCount[context]

    -- if thisModel.VoltageSensor[context].cellMissing == 0 then
    --   thisModel.VoltageSensor[context].CellsDetected = true
    -- end


  end

end

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


 --for _, adlSensor in ipairs(thisModel.AdlSensors) do
 --   for _, sensor in ipairs(adlSensor.sensors) do
 --     initializeSensorId(sensor)
 --   end
 -- end

 for sensorKey, sensor in pairs(thisModel.AdlSensors) do
  initializeSensorId(sensor)
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
    --thisModel.VoltageSensor.main.CellsDetected = false
    --numberOfBatteries = numberOfBatteries + 1
  --else
  --  thisModel.VoltageSensor.main.CellsDetected = true
  end

  if thisModel.VoltageSensor.receiver.sensorId ~= nil then
    table.insert(contexts, "receiver")
    --thisModel.VoltageSensor.receiver.CellsDetected = false
    --numberOfBatteries = numberOfBatteries + 1
  --else
  --  thisModel.VoltageSensor.receiver.CellsDetected = true
  end

else
  debugPrint("INVS: Invalid Sensors: " .. invalidSensorList)

  pfStatus.text = "Invalid Sensors: " .. invalidSensorList
  pfStatus.color = YELLOW

end

end

end



local function checkAllBatStatuspreFlight()

  if not preFlightChecksPassed  and allSensorsValid then
    
  for _, context in ipairs(contexts) do
      if thisModel.VoltageSensor[context].cellMissing ~= 0  then
          pfStatus.text = context .. " Battery check Cell count"
          pfStatus.color = RED          
          return false
      --else
      --  pfStatus.text = "Battery Cells OK"
      --  pfStatus.color = GREEN
      end
      if thisModel.VoltageSensor[context].PercRem < thisModel.battery[context].notFullWarningThreshold then
        pfStatus.text = context .. " Battery not Full"
        pfStatus.color = RED
        return false
    end
  end
  
  preFlightChecksPassed = true

  return true

end

end



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
  thisModel.VoltageSensor.main.LatestVolt = 0
  thisModel.VoltageSensor.main.LowestVolt = 0
  thisModel.VoltageSensor.main.HighestVolt = 0

  thisModel.CurrentSensor.main.CurAmp = 0
  thisModel.CurrentSensor.main.LatestAmp = 0
  thisModel.CurrentSensor.main.LowestAmp = 0
  thisModel.CurrentSensor.main.HighestAmp = 0

  thisModel.VoltageSensor.receiver.CurVolt = 0
  thisModel.VoltageSensor.receiver.LatestVolt = 0
  thisModel.VoltageSensor.receiver.LowestVolt = 0
  thisModel.VoltageSensor.receiver.HighestVolt = 0

  thisModel.CurrentSensor.receiver.CurAmp = 0
  thisModel.CurrentSensor.receiver.LatestAmp = 0
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

  thisModel.VoltageSensor.main.cellMissing = 1
  thisModel.VoltageSensor.receiver.cellMissing = 1

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

  preFlightChecksPassed = false

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

--  for _, adlSensor in ipairs(thisModel.AdlSensors) do
--   for _, sensor in ipairs(adlSensor.sensors) do
--     updateSensorValue(sensor)
--   end
-- end

 for sensorKey, sensor in pairs(thisModel.AdlSensors) do
  updateSensorValue(sensor)
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

  checkAllBatStatuspreFlight()

  -- if thisModel.VoltageSensor.receiver.CellsDetected and thisModel.VoltageSensor.main.CellsDetected then -- sanity checks passed ... we can move to normal operation and switch the status widget
  --  batCheckPassed = true
  --  pfStatus.text = "OK"
  --  pfStatus.color = GREEN
  --  else
  --   pfStatus.text = "Check Battery Cells"
  --   pfStatus.color = YELLOW
  --   batCheckPassed = false
  -- end


end -- end of if telemetry

doAnnouncements(currentContext)

if statusTele and allSensorsValid then
      -- Update the index to cycle through the contexts using the modulo operator
      currentContextIndex = (currentContextIndex % #contexts) + 1
end


end

-- ####################################################################
-- local function getPercentColor(cpercent, battery)
--   -- This function returns green at 100%, red bellow 30% and graduate in between
-- 
--   --local warn = batTypeWarnCritThresh[battype][1] 
--   local warn = battery.warningThreshold
-- 
-- 
-- 
--   if cpercent < warn then
--     return lcd.RGB(0xff, 0, 0)
--   else
--     g = math.floor(0xdf * cpercent / 100)
--     r = 0xdf - g
--     return lcd.RGB(r, g, 0)
--   end
-- end

local function getPercentColor(cpercent, battery)
  -- This function returns:
  -- - Red if below the critical threshold
  -- - Graduated color between red and yellow if below the warning threshold
  -- - Green if above the warning threshold
  
  local warn = battery.warningThreshold
  local crit = battery.criticalThreshold

  if cpercent < crit then
    return lcd.RGB(0xff, 0, 0)  -- Red
  elseif cpercent < warn then
    local r = 0xff
    local g = math.floor(0xff * (cpercent - crit) / (warn - crit))
    return lcd.RGB(r, g, 0)  -- Graduated color between red and yellow
  else
    local g = math.floor(0xdf * (cpercent - warn) / (100 - warn))
    local r = 0xdf - g
    return lcd.RGB(r, g, 0)  -- Graduated color between yellow and green
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
if  thisModel.MahSensor[context].value ~= nil then
lcd.drawText(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y + myBatt.h,
string.format("%d mAh used", thisModel.MahSensor[context].value), myBatt.font + txtCol + BlinkWhenZero) -- todo -- original line --below just for display testing
--"3456 mAh (8000)", myBatt.font + txtCol + BlinkWhenZero)
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



  if preFlightChecksPassed or not ShowPreFlightStatus then




local headerSpacing = 0
local topSpacing = 0



local fontSizes = {
  l  = { FONT = MIDSIZE, fontpxl = 24, lineSpacing = 4, colSpacing = 17 },
  m  = { FONT = 0,       fontpxl = 16, lineSpacing = 3, colSpacing = 16 },
  s  = { FONT = SMLSIZE, fontpxl = 12, lineSpacing = 2, colSpacing = 9 }
}

if wgt.zone.h > 168 then
  headerSpacing = 16
end


if wgt.zone.h >= 272 then
  fontSizes = {
    l  = { FONT = DBLSIZE, fontpxl = 32, lineSpacing = 4, colSpacing = 18 },
    m  = { FONT = MIDSIZE, fontpxl = 24, lineSpacing = 3, colSpacing = 22 },
    s  = { FONT = 0,       fontpxl = 16, lineSpacing = 2, colSpacing = 11 }
  }
  headerSpacing = 10
  topSpacing = 5

end




local y = 0
local x = 0

local function drawText(text, x, y, fontsize, color)
  debugPrint("SCRN:" .. text)
  local offsetX = x + 2
  local fontData = fontSizes[fontsize]
  lcd.drawText(offsetX, y, text, fontData.FONT + color)
  --y = y + headerSpacing
  y = y + fontSizes[fontsize].fontpxl + fontSizes[fontsize].lineSpacing
  return y
end

local function drawSensorLine(label1, label1col, value1, value1col, label2, label2col, value2, value2col, y)
  local offsetX = x + 2
  drawText(label1, offsetX, y, "m", label1col)
  drawText(value1, offsetX + fontSizes["m"].colSpacing * 2, y, "m", value1col)
  offsetX = offsetX + fontSizes["m"].colSpacing * 6
  drawText(label2, offsetX, y, "m", label2col)
  drawText(value2, offsetX + fontSizes["m"].colSpacing * 2, y, "m", value2col)
  y = y + fontSizes["m"].fontpxl + fontSizes["m"].lineSpacing
  return y
end


local sensorsPerLine = 4  -- Define the number of sensors per line

local function drawBottomSensorLine(sensors, y)
    local offsetX = x + 1
    local totalSensors = 0  -- Initialize total sensors count

    -- Iterate over mysensors table using pairs
    for _, sensor in pairs(sensors) do
        totalSensors = totalSensors + 1  -- Increment total sensors count

        if wgt.zone.h <= 168 and totalSensors > 8 then 
          break 
        end


        -- Calculate position based on totalSensors and sensorsPerLine
        local currentLine = math.floor((totalSensors - 1) / sensorsPerLine)
        local colIndex = (totalSensors - 1) % sensorsPerLine
        local sensorWidth = wgt.zone.w / sensorsPerLine
        local lineOffsetX = offsetX + colIndex * sensorWidth

        -- Starting X position for elements
        local elementX = lineOffsetX

        -- Print debug info
        print("SNLN - Processing sensor:", sensor.displayName)

        -- Draw displayName with its color and update position
        drawText(sensor.displayName, elementX, y - currentLine * (fontSizes["s"].fontpxl + fontSizes["s"].lineSpacing), "s", sensor.displayNameColor)
        elementX = elementX + #sensor.displayName * fontSizes["s"].colSpacing

        -- Draw prefix with its color and update position
        drawText(sensor.prefix, elementX, y - currentLine * (fontSizes["s"].fontpxl + fontSizes["s"].lineSpacing), "s", sensor.prefixColor)
        elementX = elementX + #sensor.prefix * fontSizes["s"].colSpacing

        -- Draw value with its color and update position
        --local valueStr = tostring(sensor.value)
        --valueStr = valueStr  .. sensor.unit

        local formattedValue = sensor.value
        if type(sensor.value) == "number" then
            if math.floor(sensor.value) ~= sensor.value then
                formattedValue = string.format("%.2f", sensor.value)
            else
                formattedValue = tostring(sensor.value)
            end
        end


        drawText(formattedValue .. sensor.unit, elementX, y - currentLine * (fontSizes["s"].fontpxl + fontSizes["s"].lineSpacing), "s", sensor.valueColor)
        --elementX = elementX + #valueStr * fontSizes["s"].colSpacing
      
      --   if string.find(valueStr, "%.") then
      --     elementX = elementX - (fontSizes["s"].colSpacing + 0)
      -- end
      
        -- -- Draw suffix with its color and update position
        -- drawText(sensor.suffix, elementX, y - currentLine * (fontSizes["s"].fontpxl + fontSizes["s"].lineSpacing), "s", sensor.suffixColor)

        -- Draw suffix with its color at the end of the quarter
        local suffixX = lineOffsetX + sensorWidth - (#sensor.suffix ) * fontSizes["s"].colSpacing
        drawText(sensor.suffix, suffixX, y - currentLine * (fontSizes["s"].fontpxl + fontSizes["s"].lineSpacing), "s", sensor.suffixColor)



        -- Adjust y position for new line if necessary
        if colIndex == sensorsPerLine - 1 and totalSensors < #sensors then
            y = y - fontSizes["s"].lineSpacing
        end
    end

    print("SNLN - Total Sensors:", totalSensors)  -- Print total sensors processed
    return y
end









-- Main Section
y = drawText("Main", x, y + topSpacing, "l", COLOR_THEME_SECONDARY2)
--y = y + fontSizes["l"].fontpxl + fontSizes["l"].lineSpacing

y = drawSensorLine("C:", COLOR_THEME_FOCUS, thisModel.VoltageSensor.main.CurVolt .. "V", GREEN, "L:", COLOR_THEME_FOCUS, thisModel.VoltageSensor.main.LowestVolt .. "V", RED, y)
y = drawSensorLine("C:", COLOR_THEME_FOCUS, thisModel.CurrentSensor.main.CurAmp .. "A", GREEN, "H:", COLOR_THEME_FOCUS,thisModel.CurrentSensor.main.HighestAmp .. "A", RED, y)

-- Receiver Section
y = y + headerSpacing

y = drawText("Receiver", x, y, "l", COLOR_THEME_SECONDARY2)
--y = y + fontSizes["l"].fontpxl + fontSizes["l"].lineSpacing

y = drawSensorLine("C:", COLOR_THEME_FOCUS, thisModel.VoltageSensor.receiver.CurVolt .. "V", GREEN, "L:", COLOR_THEME_FOCUS,thisModel.VoltageSensor.receiver.LowestVolt .. "V", RED, y)
y = drawSensorLine("C:", COLOR_THEME_FOCUS, thisModel.CurrentSensor.receiver.CurAmp .. "A", GREEN, "H:", COLOR_THEME_FOCUS,thisModel.CurrentSensor.receiver.HighestAmp .. "A", RED, y)

-- Bottom Section
--drawBottomSensorLine(thisModel.AdlSensors, wgt.zone.h - fontSizes["s"].fontpxl - fontSizes["s"].lineSpacing - 5)


drawBottomSensorLine(thisModel.AdlSensors, wgt.zone.h - fontSizes["s"].fontpxl - fontSizes["s"].lineSpacing - 5)





if wgt.zone.h >= 272 then

-- local function drawNewBattery(xOrigin, yOrigin, percentage, wgt, battery, batCol, txtCol, size)

drawNewBattery(280, 20 + headerSpacing,  "main"     , wgt , COLOR_THEME_PRIMARY2, COLOR_THEME_ACTIVE, "x" )
drawNewBattery(280, 125 + headerSpacing , "receiver" , wgt , COLOR_THEME_PRIMARY2, COLOR_THEME_ACTIVE,"x")

else

  drawNewBattery(230, 15 + headerSpacing, "main"     , wgt  , COLOR_THEME_PRIMARY2, COLOR_THEME_ACTIVE,"l" )
drawNewBattery(230, 80 + headerSpacing,   "receiver" , wgt  , COLOR_THEME_PRIMARY2, COLOR_THEME_ACTIVE, "l")
--
end




  
  else

    

  local topSpacing = 0
  local headerSpacing = 0
  local firstHeader = true

  local fontSizes = {
      l = { FONT = MIDSIZE, fontpxl = 24, lineSpacing = 4, colSpacing = 17 },
      m = { FONT = 0,       fontpxl = 16, lineSpacing = 3, colSpacing = 16 },
      s = { FONT = SMLSIZE, fontpxl = 12, lineSpacing = 2, colSpacing = 8 }
  }

  if wgt.zone.h >= 272 then
    fontSizes = {
      l = { FONT = DBLSIZE, fontpxl = 32, lineSpacing = 4, colSpacing = 18 },
      m = { FONT = MIDSIZE, fontpxl = 24, lineSpacing = 3, colSpacing = 22 },
      s = { FONT = 0,       fontpxl = 16, lineSpacing = 2, colSpacing = 10 },
    }
    headerSpacing = 5
    topSpacing = 5
  end

  local y = 0
  local x = 0

  local function drawText(text, x, y, fontsize, color)
    debugPrint("SCRN:" .. text)
    local offsetX = x + 2
    local fontData = fontSizes[fontsize]
    lcd.drawText(offsetX, y, text, fontData.FONT + color)
    --y = y + headerSpacing
    y = y + fontSizes[fontsize].fontpxl + fontSizes[fontsize].lineSpacing
    return y
  end

  local function drawKeyValLine(key, value, keycol, valcol, y)
    local offsetX = x + 2
    drawText(key, offsetX, y, "s", keycol)
    drawText(":", offsetX + fontSizes["s"].colSpacing * 10, y, "s", WHITE)
    drawText(value, offsetX + fontSizes["s"].colSpacing * 11, y, "s", valcol)
    y = y + fontSizes["s"].fontpxl + fontSizes["s"].lineSpacing
    return y
  end

  -- Main Battery Section
 y = drawText("Main Battery", x, topSpacing , "m", COLOR_THEME_SECONDARY2)

 drawText(thisModel.modelName, wgt.zone.w / 2, topSpacing, "l", COLOR_THEME_SECONDARY2)
  lcd.drawBitmap(thisModel.bmpSizedModelImage, wgt.zone.w / 2, topSpacing + fontSizes["l"].fontpxl + fontSizes["l"].lineSpacing, 50)
  --y = y + 70

  y = drawKeyValLine("Battery Type", thisModel.battery.main.displayName, COLOR_THEME_FOCUS, GREEN, y)
  y = drawKeyValLine("Cell Count", string.format("%s (%s)", thisModel.CellCount.main, thisModel.VoltageSensor.main.CellsDetectedCurrent), COLOR_THEME_FOCUS, GREEN, y)
  y = drawKeyValLine("Voltage", thisModel.VoltageSensor.main.CurVolt, COLOR_THEME_FOCUS, GREEN, y)
  y = drawKeyValLine("Percentage", thisModel.VoltageSensor.main.PercRem, COLOR_THEME_FOCUS, getPercentColor(thisModel.VoltageSensor.main.PercRem, thisModel.battery["main"]), y)

  -- Receiver Battery Section
  y = y + headerSpacing
  y = drawText("Receiver Battery", x, y, "m", COLOR_THEME_SECONDARY2)

  y = drawKeyValLine("Battery Type", thisModel.battery.receiver.displayName, COLOR_THEME_FOCUS, GREEN, y)
  y = drawKeyValLine("Cell Count", string.format("%s (%s)", thisModel.CellCount.receiver, thisModel.VoltageSensor.receiver.CellsDetectedCurrent), COLOR_THEME_FOCUS, GREEN, y)
  y = drawKeyValLine("Voltage", thisModel.VoltageSensor.receiver.CurVolt, COLOR_THEME_FOCUS, GREEN, y)
  y = drawKeyValLine("Percentage", thisModel.VoltageSensor.receiver.PercRem, COLOR_THEME_FOCUS, getPercentColor(thisModel.VoltageSensor.receiver.PercRem, thisModel.battery["receiver"]), y)

  -- Status Section
  y = y + headerSpacing
  y = drawText("Status:", x, y, "m", COLOR_THEME_SECONDARY2)
  drawText(pfStatus.text, x, y, "s", pfStatus.color)






end

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
