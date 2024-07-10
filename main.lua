-- License https://www.gnu.org/licenses/gpl-3.0.en.html
-- OpenTX/EdgeTX Lua script
-- TELEMETRY

-- File Locations On The Transmitter's SD Card
--  This script file  /SCRIPTS/WIDGETS/
--  Sound files       /SCRIPTS/WIDGETS/TxBatTele/sounds/

-- Works On EdgeTX Companion Version: 2.10
-- Works With Sensor: FrSky FAS40S, FCS-150A, FAS100, FLVS Voltage Sensors
--
-- Author: Derelict
-- Date: 2024 June 27

-------------------------------------------------------------------------------------------------------------------------------------------------
local Title = "Flight Telemetry and Battery Monitor"
-------------------------------------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------------------------------
-- CONFIGURATION(S)
---------------------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------
-- Switch State Voice Announcements (Settings/Variable) will/can be placed into a model definition later down below
----------------------------------------------------------------------------------------------------------------------

-- - first parameter is the switch name, what follows can be up to 3 voice announcements
-- - they have to be present on the sd card (default edgetx NOT in the widget folder)
-- - tested with 3-position switches currently
-- - if only one value is specified, the most "far" position of the switch will trigger the voice
-- - if two values are specified on a 3-position switch ... the announcements will be triggerd "up" and "down" but not middle
-- - just test it out ;-)

local SwitchAnnounceTable = {
  {"sf","disarm","armed"},
  {"sh","safeon"},
  {"se","fm-nrm","fm-1","fm-2"}
}

----------------------------------------------------------------------------------------------------------------------
-- Bottom Sensors
----------------------------------------------------------------------------------------------------------------------

-- - You can define as "much" of Sensors as you like ... but please be aware ... if the screen bottom has been reached they will be ommited
-- - You can optionaly specify a condition to be evaluated to change the color ... for instance if a temperature has been to high change color to RED
-- - The less sensors you specify the more space you have per line (they will be distributed accross three lines maximum currently)
-- - these are only variable definitions and will be placed "into" the model down below ... you can choose any name for the variable for different scenarios and/or models and/or sensors per model
-- - do not change defaultAdlSensors ... because it is choosen as the default for the default model below ... unless ... of course ... you know what you are doing ;-)
-- - sensorname is the radio sensor name ... displayname can freely be choosen (but depending on number of sensors is more or less limited to 4 Chars maximum)

local defaultAdlSensors = {
  --- first line
  { sensorName = "RPM+"  , displayName = "RPM+" , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = ""   , cond = ""       , condColor = RED },
  { sensorName = "RPM-"  , displayName = "RPM-" , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = ""   , cond = "< 1200" , condColor = RED },
  { sensorName = "RxBt+" , displayName = "BEC+" , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = "V"  , cond = ">9"     , condColor = RED },
  { sensorName = "RxBt-" , displayName = "BEC-" , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = "V"  , cond = "<6"     , condColor = RED },
  --- second line   
  { sensorName = "RSSI+" , displayName = "RSI+" , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = ""   , cond = ""       , condColor = RED },
  { sensorName = "RSSI-" , displayName = "RSI-" , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = ""   , cond = ""       , condColor = RED },
  { sensorName = "Fuel+" , displayName = "HLD " , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = ""   , cond = ""       , condColor = RED },
  { sensorName = "Fuel-" , displayName = "TRS " , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = ""   , cond = ""       , condColor = RED },
  --- third line
  { sensorName = "Tmp1+" , displayName = "TF+ " , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = "°C" , cond = ">50"    , condColor = RED },
  { sensorName = "Tmp1-" , displayName = "TF- " , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = "°C" , cond = ">50"    , condColor = RED },
  { sensorName = "Tmp2+" , displayName = "ET+ " , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = "°C" , cond = ">50"    , condColor = RED },
  { sensorName = "Tmp2-" , displayName = "ET- " , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = "°C" , cond = ">50"    , condColor = RED }
}

local sensg580 = { -- this is a real definition to my own model -- can be deleted together with the model below
  --- first line
  { sensorName = "Erpm+" , displayName = "RPM+" , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = ""   , cond = ""       , condColor = RED },
  { sensorName = "Erpm-" , displayName = "RPM-" , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = ""   , cond = "< 1500" , condColor = RED },
  { sensorName = "VBEC+" , displayName = "BEC+" , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = "V"  , cond = ">10"    , condColor = RED },
  { sensorName = "VBEC-" , displayName = "BEC-" , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = "V"  , cond = "<7"     , condColor = RED },
  --- second line
  { sensorName = "FLss+" , displayName = "FLS " , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = ""   , cond = ">1"     , condColor = RED },
  { sensorName = "FdeA+" , displayName = "FDE " , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = ""   , cond = ">1"     , condColor = RED },
  { sensorName = "Hold+" , displayName = "HLD " , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = ""   , cond = ">1"     , condColor = RED },
  { sensorName = "TRSS-" , displayName = "TRS " , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = ""   , cond = ""       , condColor = RED },
  --- third line
  { sensorName = "TFET+" , displayName = "TF+ " , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = "°C" , cond = ">45"    , condColor = RED },
  { sensorName = "TFET-" , displayName = "TF- " , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = "°C" , cond = ">45"    , condColor = RED },
  { sensorName = "RB1T+" , displayName = "ET+ " , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = "°C" , cond = ">45"    , condColor = RED },
  { sensorName = "RB1T-" , displayName = "ET- " , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = "°C" , cond = ">45"    , condColor = RED }
}

local sensSimulator = { -- this is what i use for testing and development -- can be deleted together with the model below
  --- first line
  { sensorName = "RPM+"  , displayName = "RPM+" , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = ""   , cond = ""       , condColor = RED },
  { sensorName = "RPM-"  , displayName = "RPM-" , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = ""   , cond = "< 1500" , condColor = RED },
  { sensorName = "VFAS+" , displayName = "BAT+" , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = "V"  , cond = ">40"    , condColor = RED },
  { sensorName = "VFAS-" , displayName = "BAT-" , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = "V"  , cond = "<7"     , condColor = RED },
  --- second line
  { sensorName = "Curr"  , displayName = "CURR" , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = "A"  , cond = ""       , condColor = RED },
  { sensorName = "RSSI+" , displayName = "RSI+" , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = ""   , cond = ""       , condColor = RED },
  { sensorName = "RSSI-" , displayName = "RSI-" , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = ""   , cond = ""       , condColor = RED },
  { sensorName = "RPM-"  , displayName = "RPM-" , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = ""   , cond = ""       , condColor = RED },
  --- third line
  { sensorName = "Tmp1+" , displayName = "TF+ " , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = "°C" , cond = ">45"    , condColor = RED },
  { sensorName = "Tmp1-" , displayName = "TF- " , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = "°C" , cond = ">45"    , condColor = RED },
  { sensorName = "Tmp2+" , displayName = "ET+ " , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = "°C" , cond = ">45"    , condColor = RED },
  { sensorName = "Tmp2-" , displayName = "ET- " , prefix = "[" , suffix = "]" , displayNameColor = COLOR_THEME_SECONDARY2, prefixColor = BLUE, valueColor = GREEN , suffixColor = BLUE, unit = "°C" , cond = ">45"    , condColor = RED }
}


----------------------------------------------------------------------------------------------------------------------
-- Battery / Powersource Definition
----------------------------------------------------------------------------------------------------------------------

-- - dischargeCurve              : Well ... discharge Curve in steps of 2.5 ... can be nil ... in that case a linear curve will be created during runtime (based on lowVoltage and highVoltage)
-- - graceperiod                 : time in seconds that has to pass until a change of value is "valid" ... this has been implemented to not get voice announcements for short fluctuations in values
-- - criticalThreshold           : Threshhold in Percent for the Battery/Powersource to be in a critical state (Percentage left measured by voltage currently)
-- - warningThreshold            : Threshhold in Percent for the Battery/Powersource to be in a warning state (Percentage left measured by voltage currently)
-- - notFullCriticalThreshold    : Threshhold in Percent for the Battery/Powersource to be in a critical state of not being full
-- - notFullWarningThreshold     : Threshhold in Percent for the Battery/Powersource to be in a warning state of not being full
-- - announceNotFullCriticalMode : ONLY USED FOR PREFLIGHT CHECK -- this can be an integer ( which then announces the Battery NOT FULL Critical Threshold (above) state on a fixed interval ) or change ( only announce ONCE on a CHANGE ) or disable ( DO NOT Care and announce at all )
-- - announceNotFullWarningMode  : ONLY USED FOR PREFLIGHT CHECK -- this can be an integer ( which then announces the Battery NOT FULL Warning Threshold (above) state on a fixed interval ) or change ( only announce ONCE on a CHANGE ) or disable ( DO NOT Care and announce at all )
-- - announceNormalMode          : For Battery/Power Percentage left states: this can be an integer ( which then announces the NORMAL state (not warning and not critical) on a fixed interval ) or change ( only announce ONCE on a CHANGE ) or disable ( DO NOT Care and announce at all )
-- - announceWarningMode         : For Battery/Power Percentage left states: this can be an integer ( which then announces the WARNING Threshold (above) on a fixed interval ) or change ( only announce ONCE on a CHANGE ) or disable ( DO NOT Care and announce at all )
-- - announceCriticalMode        : For Battery/Power Percentage left states: this can be an integer ( which then announces the CRITICAL Threshold (above) on a fixed interval ) or change ( only announce ONCE on a CHANGE ) or disable ( DO NOT Care and announce at all )
-- - cellDeltaVoltage            : Cell delta voltage "allowance" before getting alerted (see isNotABattery !!)
-- - highVoltage                 : Battery/Power Source maximum/normal high Voltage per Cell (see isNotABattery !!)

-- - lowVoltage                  : Battery/Power Source maximum low Voltage per Cell (see isNotABattery !!)
--     NOTE:
--     - there is not such a thing as "lowvoltage" if only using a bec ... if you loose your bec you will recognize it before we can announce anything ... so lets set this to anything below what is "normal" ... like 5

-- - isNotABattery               : true or false .. here you specify if the Battery/Powersource is a real battery ( that has Cells ) or not ... DO NOT CHANGE TO FALSE if there is a real Battery involved !!!
--     NOTE:
--     - A buffer is not a battery and values for high and low voltage represent real voltages and will be devided by 2 by the script to get a theoretical cell value -- todo improve change in the future

-- - Just see comments and examples below

  local powerSources = {

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


        typeName                    = "LiPo",
        name                        = "Battery", -- will be used as suffix to the source name (see below), has to be present as wav or voice announce wont work
        graceperiod                 = 4,      -- grace period for fluctuations 
        
        criticalThreshold           = 15,     -- Critical threshold in percentage
        warningThreshold            = 20,     -- Warning threshold in percentage

        notFullCriticalThreshold    = 96,     -- Not full critical threshold in percentage
        notFullWarningThreshold     = 98,     -- Not full warning threshold in percentage

        announceNotFullCriticalMode = 10, -- change, disable or integer intervall
        announceNotFullWarningMode  = 10, -- change, disable or integer intervall

        announceNormalMode          = 20, -- change, disable or integer intervall
        announceWarningMode         = "change", -- change, disable or integer intervall
        announceCriticalMode        = "change", -- change, disable or integer intervall
        
        notFullAlertModes = { 
          normal   = { mode = "disable"                                } ,  -- do NOT announce anything under normal conditions
          warning  = { mode = 10        , threshold = 98               } ,  -- announce on intervals, threshold for warning, steps = amount of change required for announcement
          critical = { mode = 10        , threshold = 96               } ,  -- announce on intervals, threshold for critical, steps = amount of change required for announcement
        },
                
        alertModes = {
          normal   = { mode = "change"                   , steps = 10  } ,  -- announce on changes, steps = amount of change required for announcement during normal condition
          warning  = { mode = "change"  , threshold = 20 , steps = 5   } ,  -- announce on changes, threshold for warning, steps = amount of change required for announcement
          critical = { mode = "change"  , threshold = 15 , steps = 2.5 } ,  -- announce on changes, threshold for critical, steps = amount of change required for announcement
        }, 

        highVoltage                 = 4.20,   -- High voltage
        lowVoltage                  = 3.27,   -- Low voltage
        cellDeltaVoltage            = 0.1,    -- Cell delta voltage
        isNotABattery               = false   -- DO NOT CHANGE for any Battery !!!
    },
  
    buffer = {  -- Buffer Pack (condensator)
        dischargeCurve              = nil,    -- This will be dynamically calculated based on voltage range
        typeName                    = "Buffer Pack",
        name                        = "Buffer", -- will be used as suffix to the source name (see below), has to be present as wav or voice announce wont work
        graceperiod                 = 4,      -- grace period for fluctuations 

        criticalThreshold           = 96,     -- Critical threshold in percentage
        warningThreshold            = 97,     -- Warning threshold in percentage

        notFullCriticalThreshold    = 98,     -- Not full critical threshold in percentage
        notFullWarningThreshold     = 99,     -- Not full warning threshold in percentage
        announceNotFullCriticalMode = 10, -- change, disable or integer intervall
        announceNotFullWarningMode  = 10, -- change, disable or integer intervall

        announceNormalMode          = "disable", -- change, disable or integer intervall
        announceWarningMode         = "change", -- change, disable or integer intervall
        announceCriticalMode        = "change", -- change, disable or integer intervall      highVoltage              = nil,    -- High voltage -- will be set to rxReferenceVoltage from the model once it's loaded ... you can override it here ... but it's better to "calculate"/set it to the rxReferenceVoltage -- todo
        
        notFullAlertModes = { 
          normal   = { mode = "disable"                                } ,  -- do NOT announce anything under normal conditions
          warning  = { mode = 10        , threshold = 99               } ,  -- announce on intervals, threshold for warning, steps = amount of change required for announcement
          critical = { mode = 10        , threshold = 98               } ,  -- announce on intervals, threshold for critical, steps = amount of change required for announcement
        },

        alertModes = {
          normal   = { mode = "disable"                                } ,  -- announce on changes, steps = amount of change required for announcement during normal condition
          warning  = { mode = "change"  , threshold = 97 , steps = 5   } ,  -- announce on changes, threshold for warning, steps = amount of change required for announcement
          critical = { mode = "change"  , threshold = 87 , steps = 2.5 } ,  -- announce on changes, threshold for critical, steps = amount of change required for announcement
        },
       
        highVoltage                 = nil,   -- if nil will use model rxReferenceVoltage
        lowVoltage                  = 6,      -- Low voltage -- where your buffer pack shuts off completely ... all hope is lost after this ;-) .. please note... in the case of buffer packs ... we will device this value by 2 in order to get a theoretical 2s per cell value for the alerts and percentage left -- todo
        cellDeltaVoltage            = nil,     -- Cell delta voltage -- irrelevant for buffer or bec
        isNotABattery               = true   -- buffer is not a battery and values for high and low voltage represent real voltages and will be devided by 2 by the script to get a theoretical cell value
      },
  
    beconly = {  -- BEC only Definition
        dischargeCurve              = nil,    -- This will be dynamically calculated based on voltage range
        typeName                    = "BEC only",
        name                        = "Power", -- will be used as suffix to the source name (see below), has to be present as wav or voice announce wont work
        graceperiod                 = 4,      -- grace period for fluctuations 
        criticalThreshold           = 96,     -- Critical threshold in percentage
        warningThreshold            = 97,     -- Warning threshold in percentage
        notFullCriticalThreshold    = 98,     -- Not full critical threshold in percentage
        notFullWarningThreshold     = 99,     -- Not full warning threshold in percentage
        announceNotFullCriticalMode = 10, -- change, disable or integer intervall
        announceNotFullWarningMode  = 10, -- change, disable or integer intervall

        announceNormalMode          = "disable", -- change, disable or integer intervall
        announceWarningMode         = "change", -- change, disable or integer intervall
        announceCriticalMode        = "change", -- change, disable or integer intervall      highVoltage              = nil,    -- High voltage -- will be set to rxReferenceVoltage from the model once it's loaded ... you can override it here ... but it's better to "calculate"/set it to the rxReferenceVoltage -- todo
        
        notFullAlertModes = { 
          normal   = { mode = "disable"                                } ,  -- do NOT announce anything under normal conditions
          warning  = { mode = 10        , threshold = 99               } ,  -- announce on intervals, threshold for warning, steps = amount of change required for announcement
          critical = { mode = 10        , threshold = 98               } ,  -- announce on intervals, threshold for critical, steps = amount of change required for announcement
        },

        alertModes = {
          normal   = { mode = "disable"                                } ,  -- announce on changes, steps = amount of change required for announcement during normal condition
          warning  = { mode = "change"  , threshold = 97 , steps = 5   } ,  -- announce on changes, threshold for warning, steps = amount of change required for announcement
          critical = { mode = "change"  , threshold = 87 , steps = 2.5 } ,  -- announce on changes, threshold for critical, steps = amount of change required for announcement
        },

        highVoltage                 = nil,   -- if nil will use model rxReferenceVoltage
        lowVoltage                  = 5,      -- Low voltage -- there is not such a thing as "lowvoltage" if only using a bec ... if you loose your bec you will recognize it before we can announce anything ... so lets set this to anything below what is "normal" ... like 5
        cellDeltaVoltage            = nil,     -- Cell delta voltage -- irrelevant for buffer or bec
        isNotABattery               = true   -- BEC is not a battery and values for high and low voltage represent real voltages and will be devided by 2 by the script to get a theoretical cell value
      },

    }

----------------------------------------------------------------------------------------------------------------------
-- Model Definitions ... where it all sticks together ;-)
----------------------------------------------------------------------------------------------------------------------

local modelTable = {
  {
      modelNameMatch         = "DEFAULT",
      modelName              = "DEFAULT",
      modelImage             = "goblin.png",
      modelWav               = "sg630",
      rxReferenceVoltage     = 8.2,
      resetSwitch            = "TELE",
      AdlSensors             = defaultAdlSensors,

      telemetrysettlement    = 5, -- how long to let telemetry and sensors to settle before taking values for real

      doScreenshot           = true, -- Take a Screenshot after a reset (see resetSwitch above)

      screenshotLS           = 0, -- Number has to be a Sticky LS (0=L01) LS has to be used for Special Function Screenshot. See github page on how to implement this.
      loggingLS              = 1, -- Number has to be a Sticky LS (0=L01) LS has to be used for Special Function SD Logs. See github page on how to implement this.
      resetTeleLS            = 2, -- Number has to be a Sticky LS (0=L01) LS has to be used for Reset - Telemetry. See github page on how to implement this.

      -- Switches have to be lowercase ... Sensors are Case Sensitive ... Condition for a 3 position switch -1024, 0 and 1024
      -- See Example(s) below. ActivityTrigger (normally your Arm Switch) will currently only be used to dismiss the preflight status screen
      activityTrigger = { source = "RPM", condition = ">50" },
      --loggingTrigger =  { source = "sd",  condition = "=0" },
      loggingTrigger =  { source = "RPM",  condition = ">50" },
      flightDetection = { source = "RPM",  condition = ">1000" },

      flightCountGV          = 1, -- Global Variable (Number as displayed, like GV1) to store the value, make sure it is not used for something else. Set to nil to disable. Please Note: only a flight time longer as one (1) minute will make this count !
      flighttimeHoursGV      = 2, -- Global Variable (Number as displayed, like GV2) to store the value, make sure it is not used for something else. Set to nil to disable. Please Note: only a flight time longer as one (1) minute will make this count !
      flighttimeMinutesGV    = 3, -- Global Variable (Number as displayed, like GV3) to store the value, make sure it is not used for something else. Set to nil to disable. Please Note: only a flight time longer as one (1) minute will make this count !

      gvFm                   = 0, -- flightmode for storing Global Variables above, change as needed if GV's are occupied above

      activeFlightDetTime    = 5, -- todo ... choose a better name for this ... as it is currently only used for buffer pack "ignore" after this seconds of flight

      doHaptic               = true,
      doWarnTone             = true,

      switchAnnounces        = SwitchAnnounceTable,
      BattPackSelectorSwitch = nil, -- !!! NOT IMPLEMENTED YET !!!

      powerSources           = {

        {
          displayName = "Main", -- single words have to be present as wav or voice announce wont work
          VoltageSensor = { sensorName = "Cels" },
          CurrentSensor = { sensorName = "Curr" },
          MahSensor =     { sensorName = "mah" },
          type = powerSources.lipo,
          CellCount = 8,
          capacities = { 500, 1000, 1500, 2000, 2500, 3000 } -- not used as of now
        },
  

        {
          displayName = "Receiver", -- single words have to be present as wav or voice announce wont work
          VoltageSensor = { sensorName = "RxBt" },
          CurrentSensor = { sensorName = "Curr" },
          MahSensor =     { sensorName = "mah" },
          type = powerSources.buffer,
          CellCount = 2,
          capacities = { 500, 1000, 1500, 2000, 2500, 3000 } -- not used as of now
        }
  
      }

  },
  {
    modelNameMatch         = "580t", -- this is currently my REAL testing model
    modelName              = "SAB RAW 580",
    modelImage             = "580.png",
    modelWav               = "sr580",
    rxReferenceVoltage     = 7.96,
    resetSwitch            = "TELE",
    AdlSensors             = sensg580,

    telemetrysettlement    = 8, -- how long to let telemetry and sensors to settle before taking values for real

    doScreenshot           = true, -- Take a Screenshot after a reset (see resetSwitch above)

    screenshotLS           = 0, -- Number has to be a Sticky LS (0=L01) LS has to be used for Special Function Screenshot. See github page on how to implement this.
    loggingLS              = 1, -- Number has to be a Sticky LS (0=L01) LS has to be used for Special Function SD Logs. See github page on how to implement this.
    resetTeleLS            = 2, -- Number has to be a Sticky LS (0=L01) LS has to be used for Reset - Telemetry. See github page on how to implement this.

      -- Switches have to be lowercase ... Sensors are Case Sensitive ... Condition for a 3 position switch -1024, 0 and 1024
      -- See Example(s) below. ActivityTrigger (normally your Arm Switch) will currently only be used to dismiss the preflight status screen
      activityTrigger = { source = "RPM", condition = ">50" },
      --loggingTrigger =  { source = "sd",  condition = "=0" },
      loggingTrigger =  { source = "RPM",  condition = ">50" },
      flightDetection = { source = "RPM",  condition = ">1000" },

      flightCountGV          = 1, -- Global Variable (Number as displayed, like GV1) to store the value, make sure it is not used for something else. Set to nil to disable. Please Note: only a flight time longer as one (1) minute will make this count !
      flighttimeHoursGV      = 2, -- Global Variable (Number as displayed, like GV2) to store the value, make sure it is not used for something else. Set to nil to disable. Please Note: only a flight time longer as one (1) minute will make this count !
      flighttimeMinutesGV    = 3, -- Global Variable (Number as displayed, like GV3) to store the value, make sure it is not used for something else. Set to nil to disable. Please Note: only a flight time longer as one (1) minute will make this count !

      gvFm                   = 0, -- flightmode for storing Global Variables above, change as needed if GV's are occupied above

      activeFlightDetTime    = 5, -- todo ... choose a better name for this ... as it is currently only used for buffer pack "ignore" after this seconds of flight

    doHaptic               = true,
    doWarnTone             = true,

    switchAnnounces        = SwitchAnnounceTable,
    BattPackSelectorSwitch = nil, -- !!! NOT IMPLEMENTED YET !!!

    powerSources           = {

      {
        displayName = "Main", -- single words have to be present as wav or voice announce wont work
        VoltageSensor = { sensorName = "RB1V" },
        CurrentSensor = { sensorName = "RB1A" },
        MahSensor =     { sensorName = "RB1C" },
        type = powerSources.lipo,
        CellCount = 12,
        capacities = { 500, 1000, 1500, 2000, 2500, 3000 } -- not used as of now
      },


      {
        displayName = "Receiver", -- single words have to be present as wav or voice announce wont work
        VoltageSensor = { sensorName = "RB2V" },
        CurrentSensor = { sensorName = "" },
        MahSensor =     { sensorName = "" },
        type = powerSources.buffer,
        CellCount = 2,
        capacities = { 500, 1000, 1500, 2000, 2500, 3000 } -- not used as of now
      }

    }    
},  
  {
      modelNameMatch         = "heli", -- this is the simulator for dev/tests actually 
      modelName              = "SAB Goblin 630",
      modelImage             = "goblin.png",
      modelWav               = "sg630",
      rxReferenceVoltage     = 8.19,
      resetSwitch            = "TELE",
      AdlSensors             = sensSimulator,

      telemetrysettlement    = 5, -- how long to let telemetry and sensors to settle before taking values for real

      doScreenshot           = true, -- Take a Screenshot after a reset (see resetSwitch above)

      screenshotLS           = 0, -- Number has to be a Sticky LS (0=L01) LS has to be used for Special Function Screenshot. See github page on how to implement this.
      loggingLS              = 1, -- Number has to be a Sticky LS (0=L01) LS has to be used for Special Function SD Logs. See github page on how to implement this.
      resetTeleLS            = 2, -- Number has to be a Sticky LS (0=L01) LS has to be used for Reset - Telemetry. See github page on how to implement this.

      -- Switches have to be lowercase ... Sensors are Case Sensitive ... Condition for a 3 position switch -1024, 0 and 1024
      -- See Example(s) below. ActivityTrigger (normally your Arm Switch) will currently only be used to dismiss the preflight status screen
      activityTrigger = { source = "RPM", condition = ">50" },
      --loggingTrigger =  { source = "sd",  condition = "=0" },
      loggingTrigger =  { source = "RPM",  condition = ">50" },
      flightDetection = { source = "RPM",  condition = ">1000" },

      flightCountGV          = 1, -- Global Variable (Number as displayed, like GV1) to store the value, make sure it is not used for something else. Set to nil to disable. Please Note: only a flight time longer as one (1) minute will make this count !
      flighttimeHoursGV      = 2, -- Global Variable (Number as displayed, like GV2) to store the value, make sure it is not used for something else. Set to nil to disable. Please Note: only a flight time longer as one (1) minute will make this count !
      flighttimeMinutesGV    = 3, -- Global Variable (Number as displayed, like GV3) to store the value, make sure it is not used for something else. Set to nil to disable. Please Note: only a flight time longer as one (1) minute will make this count !

      gvFm                   = 0, -- flightmode for storing Global Variables above, change as needed if GV's are occupied above

      activeFlightDetTime    = 5, -- todo ... choose a better name for this ... as it is currently only used for buffer pack "ignore" after this seconds of flight

      doHaptic               = true,
      doWarnTone             = true,

      switchAnnounces        = SwitchAnnounceTable,
      BattPackSelectorSwitch = nil , -- !!! NOT IMPLEMENTED YET !!!

      powerSources           = {

        {
          displayName = "Main", -- single words have to be present as wav or voice announce wont work
          --VoltageSensor = { sensorName = "Cels" },
          VoltageSensor = { sensorName = "VFAS" },
          CurrentSensor = { sensorName = "Curr" },
          MahSensor =     { sensorName = "mah" },
          type = powerSources.lipo,
          CellCount = 12,
          capacities = { 500, 1000, 1500, 2000, 2500, 3000 } -- not used as of now
        },
  

        {
          displayName = "Receiver", -- single words have to be present as wav or voice announce wont work
          VoltageSensor = { sensorName = "RxBt" },
          CurrentSensor = { sensorName = "Curr" },
          MahSensor =     { sensorName = "mah" },
          type = powerSources.buffer,
          CellCount = 2,
          capacities = { 500, 1000, 1500, 2000, 2500, 3000 } -- not used as of now
        }
  
      }

  }
}

----------------------------------------------------------------------------------------------------------------------
-- Battery Capacity Change Switches - !!! NOT IMPLEMENTED YET !!!
----------------------------------------------------------------------------------------------------------------------

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

---------------------------------------------------------------------------------------------------------------------------------------
-- INTERNAL VARIABLES -- to NOT Change unless needed and you know what you are doing
---------------------------------------------------------------------------------------------------------------------------------------

local DEBUG_ENABLED = true
local verbosity = 3 --todo verbosity levels

-- State management for reset if needed and screenshot
local resetInitiated = false
local screenshotTriggered = false

local loggingState = false
local activityState = false
local flightState = false
local activeFlightState = false

local prevFlightTime = 0

idstatusTele = getSwitchIndex("TELE") -- Telemetry Status

local telegrace = 0

local properties = {
  "CurVolt", "LatestVolt", "LowestVolt", "HighestVolt",
  "CurPercRem", "LatestPercRem", "CurAmp", "LatestAmp",
  "LowestAmp", "HighestAmp", "CellsDetectedCurrent",
  "cellMissing", "cellInconsistent"
}

local sensornamedefs = {
  "VoltageSensor", "CurrentSensor", "MahSensor"
}

pfStatus = {
  text = "unknown",  -- This can be "ok", "warning", "error", or "unknown"
  color = GREY      -- Default color for unknown status
}

FirstModelInit = false

local modelAlreadyLoaded = false

local priorizeSwitchAnnouncements = true


local ShowPostFlightSummary = true --todo
local ShowPreFlightStatus = true -- todo
local ActiveFlightIndicator = "choose switch" -- todo ... use arm switch or maybe there is a good tele sensor for this

local statusTable = {}

-- to support future functions like taking screenshot and logging on/off
local ver, radio, maj, minor, rev, osname = getVersion()

if DEBUG_ENABLED then
print                ( "version: "        .. ver   )
if radio  then print ( "version radio: "  .. radio ) end
if maj    then print ( "version maj: "    .. maj   ) end
if minor  then print ( "version minor: "  .. minor ) end
if rev    then print ( "version rev: "    .. rev   ) end
if osname then print ( "version osname: " .. osname) end
end

local AutomaticResetOnResetSwitchToggle = 4 -- 5 seconds for TELE Trigger .... maybe 1 second for switch trigger

-- local AutomaticResetOnNextChange = true
local isPreFlightStage = true

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

local CanCallInitFuncAgain = false		-- updated in bg_func

local VoltageHistory = {}   -- updated in bg_func

-- Display
local x, y, fontSize, yColumn2
local xAlign = 0

local BlinkWhenZero = 0 -- updated in run_func
local Color = BLUE
local BGColor = BLACK

local soundQueue = {}
local currentState = "idle"
local waitUntil = 0

local timer = {
  startTime = 0,
  accumulatedTime = 0,
  running = false
}


---------------------------------------------------------------------------------------------------------------------------------------
-- FUNCTIONS
---------------------------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------------------------------

local function timerControl(action, offset)
  local currentTime = getTime()
  offset = offset or 0

  if action == "start" and not timer.running then
      timer.startTime = currentTime - offset
      timer.running = true
      print("TMRCTRL: Timer Started. Start Time: " .. timer.startTime)
  elseif action == "stop" and timer.running then
      timer.accumulatedTime = timer.accumulatedTime + (currentTime - timer.startTime)
      timer.running = false
      print("TMRCTRL: Timer Stopped. Accumulated Time: " .. timer.accumulatedTime / 100 )
  elseif action == "reset" then
      timer.startTime = 0
      timer.accumulatedTime = 0
      timer.running = false
      print("TMRCTRL: Timer Reset.")
  elseif action == "get" then
      local elapsedTime
      if timer.running then
          elapsedTime = (timer.accumulatedTime + (currentTime - timer.startTime)) / 100
      else
          elapsedTime = timer.accumulatedTime / 100
      end
      print("TMRCTRL: Elapsed Time: " .. elapsedTime)
      return elapsedTime
  end
end

---------------------------------------------------------------------------------------------------------------------------------------

  -- Helper function to evaluate conditions
  local function evaluateCondition(value, condition)
    local operator, threshold = string.match(condition, "([><=])%s*(%d+%.?%d*)")
    threshold = tonumber(threshold)
    if operator == ">" then
        return value > threshold
    elseif operator == "<" then
        return value < threshold
    elseif operator == "=" then
        return value == threshold
    else
        return false
    end
end

---------------------------------------------------------------------------------------------------------------------------------------

function round(num, numDecimalPlaces) -- todo --- quick work arround ---- remove
  local mult = 10 ^ (numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

---------------------------------------------------------------------------------------------------------------------------------------

local function debugPrint(message)
  if DEBUG_ENABLED then
      print(message)
  end
end

---------------------------------------------------------------------------------------------------------------------------------------

function setDebug(enabled)
  DEBUG_ENABLED = enabled
end

---------------------------------------------------------------------------------------------------------------------------------------

-- Function to add sound files to the queue
local function queueSound(file, duration, priority)

  priority = priority or false
  local position = priority and 1 or #soundQueue + 1

  debugPrint("PQ: insert: ", file)
  table.insert(soundQueue, position, {type = "file", value = soundDirPath..file, duration = duration})
end

---------------------------------------------------------------------------------------------------------------------------------------

local function queueSysSound(file, duration, priority)

  priority = priority or false
  local position = priority and 1 or #soundQueue + 1

  debugPrint(string.format("PQ: insert: %s pos: %s", file, position))
  table.insert(soundQueue, position, {type = "file", value = file, duration = duration})
end

---------------------------------------------------------------------------------------------------------------------------------------

-- Function to add numbers to the queue
local function queueNumber(number, unit, precision, duration)
  table.insert(soundQueue, {type = "number", value = number, unit = unit, precision = precision, duration = duration})
end

---------------------------------------------------------------------------------------------------------------------------------------

-- Function to add numbers to the queue
local function queueHaptic()
  table.insert(soundQueue, {type = "haptic", value = 1 , duration = 1})
end

---------------------------------------------------------------------------------------------------------------------------------------

-- Function to add numbers to the queue
local function queueTone()
  table.insert(soundQueue, {type = "tone", value = 1, duration = 0.5 })
end

---------------------------------------------------------------------------------------------------------------------------------------

local function processQueue()

  local now = getTime()

  if currentState == "idle" and #soundQueue > 0 then
      local item = soundQueue[1]
      
      table.remove(soundQueue, 1)  -- Remove the processed item from the queue

      if item.type == "file" then
          playFile(item.value..".wav")
      elseif item.type == "number" then
          playNumber(item.value, item.unit, item.precision, 5)
        
        elseif item.type == "haptic" then

          playHaptic(1,0, PLAY_NOW )
        
        elseif item.type == "tone" then
             playTone(2550, 100, 10, 0 , 0, 5) -- todo
             playTone(2550, 100, 10, 0 , 0, 5) -- todo
             playTone(2550, 100, 10, 0 , 0, 5) -- todo
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

---------------------------------------------------------------------------------------------------------------------------------------

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

---------------------------------------------------------------------------------------------------------------------------------------

-- Simplified wildcard matching function
local function matchModelName(mname, pattern)

  lmname = string.lower(mname)
  lpattern = string.lower(pattern)

  debugPrint("TEST modelName:", mname, "type:", type(mname))
  debugPrint("TEST pattern:", pattern, "type:", type(pattern))

 
  -- Check if the pattern is a substring of the currentModelName
  return string.find(lmname, lpattern) ~= nil

end

---------------------------------------------------------------------------------------------------------------------------------------

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

---------------------------------------------------------------------------------------------------------------------------------------

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

---------------------------------------------------------------------------------------------------------------------------------------

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

---------------------------------------------------------------------------------------------------------------------------------------

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

---------------------------------------------------------------------------------------------------------------------------------------

local function findPercentRemNew(source)
  local cellVoltage = source.VoltageSensor.LatestVolt / source.CellCount

  debugPrint("findPercentRem Cell Voltage: ", cellVoltage)

  if cellVoltage > source.type.highVoltage then
      return 100
  elseif cellVoltage < source.type.lowVoltage then
      return 0
  else
      -- Method of finding percent in array provided by on4mh (Mike)
      for i, v in ipairs(source.type.dischargeCurve) do
          debugPrint(string.format("findPercentRem Check Voltage: %s", v[1]))
          if cellVoltage >= v[1] then
              local newPercent = v[2]

              -- Initialize previous value if not present
              source.findPercentRempreviousValue = source.findPercentRempreviousValue or newPercent

              local previousPercent = source.findPercentRempreviousValue
              local gracePeriod = source.type.graceperiod

              debugPrint(string.format("findPercentRem CHG Previous Percent: %s", previousPercent))
              debugPrint(string.format("findPercentRem CHG Grace Period: %s", gracePeriod))

              -- Check if new value is different from the previous one
              if newPercent ~= previousPercent then
                  -- Use Timer function to check grace period
                  if Timer(source.displayName, gracePeriod) then
                      source.findPercentRempreviousValue = newPercent
                      return newPercent
                  else
                      return previousPercent
                  end
              else
                  -- Reset the timer if the value hasn't changed
                  TriggerTimers[source.displayName] = 0
                  return previousPercent
              end
          end
      end
  end
end

---------------------------------------------------------------------------------------------------------------------------------------

local function checkChangedIntervalNew(currentStatus, item, source)

local context = source and source.displayName or "global"

  -- Get the configuration for the item or use announcementConfigDefault
  local config, critTH, warnTH, critMD, warnMD, normMD, graceP

  if item ~= "Battery" and item ~= "BatteryNotFull" then
      config = announcementConfig[item] or announcementConfigDefault
      critTH = config.critical.threshold
      warnTH = config.warning.threshold
      critMD = config.critical.mode
      warnMD = config.warning.mode
      normMD = config.normal.mode
      graceP = config.normal.gracePeriod
  else
      config = source.type
      if item == "Battery" then
          warnTH = config.alertModes.warning.threshold or 80
          critTH = config.alertModes.critical.threshold or 70

          normST = config.alertModes.normal.steps or 5
          warnST = config.alertModes.warning.steps or 5
          critST = config.alertModes.critical.steps or 5
          
          normMD = config.alertModes.normal.mode or "change"
          warnMD = config.alertModes.warning.mode or "change"
          critMD = config.alertModes.critical.mode or "change"
          graceP = 0 -- handled in findpercremaining
      elseif item == "BatteryNotFull" then
          warnTH = config.notFullAlertModes.warning.threshold or 80
          critTH = config.notFullAlertModes.critical.threshold or 70

          normST = config.notFullAlertModes.normal.steps or 0
          warnST = config.notFullAlertModes.warning.steps or 0
          critST = config.notFullAlertModes.critical.steps or 0

          normMD = config.notFullAlertModes.normal.mode or "change"
          warnMD = config.notFullAlertModes.warning.mode or "change"
          critMD = config.notFullAlertModes.critical.mode or "change"
          graceP = 0 -- handled in findpercremaining
      end
  end

  -- local context = source.displayName or "global"
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
  local severity, mode, steps = "normal", normMD, normST
  if type(currentStatus) == "number" then
      if currentStatus <= critTH then
          severity, mode, steps = "critical", critMD, critST
      elseif currentStatus <= warnTH then
          severity, mode, steps = "warning", warnMD, warnST
      end
  elseif type(currentStatus) == "boolean" then
      if currentStatus == warnTH then
          severity, mode, steps = "warning", warnMD, warnST
      elseif currentStatus == critTH then
          severity, mode, steps = "critical", critMD, critST
      end
  end

  debugPrint(string.format("STCHDET: Item: %s, Current Status: %s, Severity Level: %s, Mode: %s, Context: %s",
  item, tostring(currentStatus), severity, mode, context))

  if mode == "disable" then
      -- Do nothing if announcements are disabled
      debugPrint(string.format("STCHDET: Announcements are disabled for item: %s, Context: %s", item, context))
      return
  end

  local announceNow = false

  if mode == "change" then
      --if itemStatus.lastStatus ~= currentStatus then
      local percentageChange = itemStatus.lastStatus and math.abs(currentStatus - itemStatus.lastStatus) or 0
      if itemStatus.lastStatus ~= currentStatus and percentageChange >= steps then

          if itemStatus.changeStartTime == 0 then
              -- Start the grace period
              itemStatus.changeStartTime = currentTime
              debugPrint(string.format("STCHDET: Change detected for item: %s, Starting grace period at time: %.2f, Context: %s", item, currentTime, context))
          else
              local elapsedGracePeriod = currentTime - itemStatus.changeStartTime
              debugPrint(string.format("STCHDET: Elapsed grace period for item %s: %.2f seconds, Context: %s", item, elapsedGracePeriod, context))
              if elapsedGracePeriod >= graceP then
                  -- Announce if grace period has passed (config.normal.gracePeriod is in seconds)
                  announceNow = true
                  debugPrint(string.format("STCHDET: Grace period passed for item: %s, Announcing change, Context: %s", item, context))
                  itemStatus.lastStatus = currentStatus
              end
          end
      else
          -- Reset grace period if status reverts to previous within grace period
          if itemStatus.changeStartTime ~= 0 then
              debugPrint(string.format("STCHDET: Status reverted to previous within grace period for item: %s, Resetting grace period, Context: %s", item, context))
              itemStatus.changeStartTime = 0
          end
      end
  elseif type(mode) == "number" then
      -- Interval mode
      local interval = mode
      if (currentTime - itemStatus.lastAnnounceTime) >= interval then
          announceNow = true
          debugPrint(string.format("STCHDET: Interval passed for item: %s, Announcing at interval, Context: %s", item, context))
      end
  end

  -- Collect announcements
  if announceNow then
      debugPrint(string.format("STCHDET: Adding announcement for item: %s, Current status: %s, Severity level: %s, Context: %s", item, currentStatus, severity, context))
      table.insert(announcements, { item = item, status = currentStatus, severity = severity, context = context })
      itemStatus.lastAnnounceTime = currentTime
  end
end

---------------------------------------------------------------------------------------------------------------------------------------

local function doAnnouncementsNew(source)
  -- Clear announcements table at the start of each call
  announcements = {}

  if statusTele and allSensorsValid then
      -- Debug print the current percentage remaining
      debugPrint("CCIV: " .. source.VoltageSensor.CurPercRem)

      -- Check for missing cells and trigger interval announcement if applicable
      if source.VoltageSensor.cellMissing ~= 10 then
          checkChangedIntervalNew(source.VoltageSensor.cellMissing, "BatteryMissingCell", source)
      end

      -- Check battery not full condition before pre-flight checks
      if not preFlightChecksPassed and source.VoltageSensor.CurPercRem ~= "--" and source.VoltageSensor.cellMissing == 0 then
          checkChangedIntervalNew(source.VoltageSensor.LatestPercRem, "BatteryNotFull", source)
      end

      -- Check for inconsistent cell voltages
      checkChangedIntervalNew(source.VoltageSensor.cellInconsistent, "CellDelta", source)

      -- Check the battery status if no cells are missing
      if source.VoltageSensor.CurPercRem ~= "--" and source.VoltageSensor.cellMissing == 0 then
          checkChangedIntervalNew(source.VoltageSensor.LatestPercRem, "Battery", source)
      end
  end

  -- Process collected announcements
  if next(announcements) ~= nil then
      debugPrint("STCHDET: Found announcements to be done.")
      local contextAnnounceDone = false

      for _, announcement in ipairs(announcements) do
          debugPrint(string.format("STCHDET: Announcing item: %s, Severity: %s, Current value: %s", announcement.item, announcement.severity, announcement.status))

          -- Announce the source display name and type name once per context
          if not contextAnnounceDone then
              for word in string.gmatch(source.displayName .. " " .. source.type.name, "%S+") do
                  local lowerWord = string.lower(word)
                  queueSound(lowerWord, 0)
              end
              contextAnnounceDone = true
          end

          if announcement.severity ~= "normal" then

            if thisModel.doHaptic then queueHaptic() end

            if thisModel.doWarnTone then queueTone() end
            --   playTone(2550, 100, 10, 0 , 0, 5) -- todo
            --   playTone(2550, 100, 10, 0 , 0, 5) -- todo
            --   playTone(2550, 100, 10, 0 , 0, 5) -- todo
            -- end
-- playTone(0,200,PLAY_NOW)

            queueSound(announcement.severity, 0)



          end 

          -- Announce based on the item type and severity
          if announcement.item == "BatteryMissingCell" then

                  local reverseValue = math.abs(source.VoltageSensor.cellMissing)

                  if source.type.isNotABattery then
                      queueSound("low", 0)
                      queueSound("voltage", 0)
                  else
                      queueSound("missing", 0)
                      queueNumber(reverseValue, 0, 0, 0)
                      queueSound("of", 0)
                      queueNumber(source.CellCount, 0, 0, 0)
                      queueSound("cells", 0)
                  end
          elseif announcement.item == "CellDelta" then
                  queueSound("icw", 0)
          elseif announcement.item == "BatteryNotFull" then

            if source.type.isNotABattery then
              queueSound("low", 0)
              queueSound("voltage", 0)
          else
                  queueSound("notfull", 0)
          end

          elseif announcement.item == "Battery" then
              queueNumber(source.VoltageSensor.LatestPercRem, 13, 0, 2)
          end
      end
  else
      debugPrint("STCHDET: No announcements to be done.")
  end
end

---------------------------------------------------------------------------------------------------------------------------------------

local function doGeneralAnnouncements()
  -- checkChangedInterval(85, "telemetry", context) -- Numerical status example
  -- checkChangedInterval("online", "telemetry", context) -- Boolean status example
  -- checkChangedInterval(45, "unknownItem", context) -- Example with an item not in the config

  announcements = {}  -- Clear announcements table at the start of each call


  --setDebug(true)

  checkChangedIntervalNew(statusTele, "telemetry")


    -- Process collected announcements
    if next(announcements) ~= nil then
      debugPrint("STCHDET: Found announcements to be done.")

      --local contextAnnounceDone = false

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

    end

    else
      debugPrint("STCHDET: No announcements to be done.")
    end

    --setDebug(false)

end

---------------------------------------------------------------------------------------------------------------------------------------

local function check_cell_delta_voltageNew(source)
  -- Get the cell voltage delta threshold for the power source type
  local vDelta = source.type.cellDeltaVoltage

  -- Check if the VoltageSensor value is a table
  if type(source.VoltageSensor.value) == "table" then
      source.VoltageSensor.cellInconsistent = false

      -- Compare each cell voltage with every other cell voltage
      for i, v1 in ipairs(source.VoltageSensor.value) do
          for j, v2 in ipairs(source.VoltageSensor.value) do
              -- If the difference between any two cells is greater than the threshold, mark as inconsistent
              if i ~= j and (math.abs(v1 - v2) > vDelta) then
                  source.VoltageSensor.cellInconsistent = true
                  break
              end
          end
          if source.VoltageSensor.cellInconsistent then
              break
          end
      end
  end
end


---------------------------------------------------------------------------------------------------------------------------------------

 -- Function to estimate the number of cells efficiently
 local function estimateNumberOfCells(source)
  for cells, range in pairs(source.type.cellVoltageRanges) do
      if source.VoltageSensor.value >= range.minVoltage and source.VoltageSensor.value <= range.maxVoltage then
          return cells
      end
  end
  return 0 -- In case no valid cell count is found
end

---------------------------------------------------------------------------------------------------------------------------------------

local function check_for_missing_cellsNew(source)
  -- Check if the cell count is greater than 0
  if source.CellCount > 0 then
      local missingCellDetected = false

      -- Handle case where VoltageSensor value is a table
      if type(source.VoltageSensor.value) == "table" then
          source.VoltageSensor.CellsDetectedCurrent = #source.VoltageSensor.value
          if #source.VoltageSensor.value ~= source.CellCount then
              missingCellDetected = true
          end

      -- Handle case where VoltageSensor value is a number (e.g., VFAS sensor)
      elseif type(source.VoltageSensor.value) == "number" then
          
        
        -- source.VoltageSensor.CellsDetectedCurrent = math.floor(source.VoltageSensor.value / source.type.lowVoltage)

        source.VoltageSensor.CellsDetectedCurrent = estimateNumberOfCells(source)

          if source.VoltageSensor.CellsDetectedCurrent ~= source.CellCount then
              missingCellDetected = true
          end
      end

      -- Debug print statement for verification
      debugPrint("CBSF: " .. tostring(source.VoltageSensor.cellMissing) .. " SOURCE: " .. source.displayName .. " CC: " .. source.CellCount .. " DETECT NOW: " .. source.VoltageSensor.CellsDetectedCurrent)

      -- Set cellMissing value
      source.VoltageSensor.cellMissing = source.VoltageSensor.CellsDetectedCurrent - source.CellCount
  end
end

---------------------------------------------------------------------------------------------------------------------------------------

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

---------------------------------------------------------------------------------------------------------------------------------------

-- Function to update sensor values
local function updateSensorValue(sensor)
  
  if sensor.sensorId then
    sensor.value = getValue(sensor.sensorId)
    debugPrint("UPDSEN: VAL: " .. tostring(sensor.value) .. " ID: " .. sensor.sensorId)
  end
end

---------------------------------------------------------------------------------------------------------------------------------------

-- Initialize sensor IDs for all sensor groups
local function initializeAndCheckAllSensorIds()

  if not allSensorsValid then

  --invalidSensorList = {}

  invalidSensorList = ""

debugPrint("IAS: start")
 for _, source in ipairs(thisModel.powerSources) do
  debugPrint("IAS: Source: " .. source.displayName )
  --if thisModel.powerSources[source] then
    for _, name in ipairs(sensornamedefs) do
      local sensor = source[name]
      if sensor then
        debugPrint("IAS: Source: Name: " .. name)
        initializeSensorId(sensor)
      end
    end
  --end
end

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

else
  debugPrint("INVS: Invalid Sensors: " .. invalidSensorList)

  pfStatus.text = "Invalid Sensors: " .. invalidSensorList
  pfStatus.color = YELLOW

end

end

end

---------------------------------------------------------------------------------------------------------------------------------------

local function checkAllSourceStatuspreFlight(source)

  --debugPrint("PFS CELL COUNT: " .. source.VoltageSensor.cellMissing .. "1:" .. preFlightChecksPassed .. "2:" .. allSensorsValid)

  if not preFlightChecksPassed and allSensorsValid then
      -- Check if the VoltageSensor current percentage remaining is valid

      if activityState then -- if we are "active" (flying, disarmed, whatever) we accept and dismiss all the warnings (but NOT if sensors are not valid ... see above)
        return true
      end

      if source.VoltageSensor.CurPercRem == "--" then
          pfStatus.text = source.displayName .. " " .. source.type.name .. " waiting for Percent update"
          pfStatus.color = GREEN          
          return false
      end

      -- Check if the cell count update is still pending
      if source.VoltageSensor.cellMissing == 10 then
          pfStatus.text = source.displayName .. " " .. source.type.name .. " waiting for Cell update"
          pfStatus.color = GREEN          
          return false
      end

      -- Check for missing cells
      if source.VoltageSensor.cellMissing ~= 0 then
        if source.type.isNotABattery then
          pfStatus.text = source.displayName .. " " .. source.type.name .. " low Voltage"
          pfStatus.color = RED
          return false

        else
          pfStatus.text = source.displayName .. " " .. source.type.name .. " check Cell count"
          pfStatus.color = RED          
          return false
        end
      end

      -- Check if the latest percentage remaining is below the threshold
      if source.VoltageSensor.LatestPercRem < source.type.notFullWarningThreshold then

        if source.type.isNotABattery then
          pfStatus.text = source.displayName .. " " .. source.type.name .. " low Voltage"
          pfStatus.color = RED
          return false

        else
          pfStatus.text = source.displayName .. " " .. source.type.name .. " not Full"
          pfStatus.color = RED
          return false
        end

        end
  end

  return true
end


---------------------------------------------------------------------------------------------------------------------------------------

local function reset()


-- Iterate over each power source
for _, source in ipairs(thisModel.powerSources) do

  -- Initialize sensor properties
  for _, property in ipairs(properties) do
    if property == "CurVolt" then
      source.VoltageSensor[property] = "--.--"
    elseif property == "CurPercRem" then
      source.VoltageSensor[property] = "--"    
    elseif property == "cellMissing" then
      source.VoltageSensor[property] = 10
    elseif property == "cellInconsistent" then
      source.VoltageSensor[property] = false
    else
      if string.find(property, "Amp") then
        source.CurrentSensor[property] = 0
      else
        source.VoltageSensor[property] = 0
      end
    end
  end

  -- Set default voltage values
  if source.type.lowVoltage == nil then
    if source.type.isNotABattery then
      source.type.lowVoltage = 6 -- Default for non-battery sources
    else
      source.type.lowVoltage = 3.27 -- Default for battery sources
    end
  end

  if source.type.highVoltage == nil then
    if source.type.isNotABattery then
      source.type.highVoltage = rxReferenceVoltage
    else
      source.type.highVoltage = 4.2 -- Default for battery sources
    end
  end

  -- Adjust voltages for non-battery sources
  if source.type.isNotABattery and not modelAlreadyLoaded then
    source.type.lowVoltage = source.type.lowVoltage / 2
    source.type.highVoltage = source.type.highVoltage / 2
  end

  -- Calculate linear discharge curve if not defined
  if source.type.dischargeCurve == nil then
    debugPrint("NO DISCHARGE CURVE FOR " .. (source.displayName or "UNKNOWN SOURCE"))
    source.type.dischargeCurve = calculateLinearDischargeCurve(source.type.lowVoltage, source.type.highVoltage)
  end



  source.type.cellVoltageRanges = {}
  local maxcells = 14

  for cells = 1, maxcells do
    source.type.cellVoltageRanges[cells] = {
          minVoltage = cells * source.type.lowVoltage,
          maxVoltage = ( cells * source.type.highVoltage ) + 0.3
      }

      debugPrint("CVRG: Source: " .. source.type.name .. " cell: " .. cells .. " min: " .. cells * source.type.lowVoltage .. " max: " .. ( cells * source.type.highVoltage ) + 0.3 )
  end





end

--if activeFlightState  then


  -- local endtime = getTime()
  -- local delta = ( endtime - thisModel.flightstarttime ) / 100
  -- delta = delta + thisModel.activeFlightDetTimeSet
-- 
  -- -- thisModel.flightstarttime
-- 
  -- local minutesToAdd = math.floor(delta / 60)

  if prevFlightTime ~= 0 then 

  local newtotalMinutes = thisModel.flighttimettotalminutes + prevFlightTime

  -- prevFlightTime = minutesToAdd

  local hours = math.floor(newtotalMinutes / 60)
  local minutes = newtotalMinutes % 60

  local prehours = math.floor(thisModel.flighttimettotalminutes / 60)
  local preminutes = thisModel.flighttimettotalminutes % 60

  debugPrint("CHKLL: NEW FLIGHT TIME: previous minutes: " .. thisModel.flighttimettotalminutes .. " hours: " .. prehours .. " Minutes: " .. preminutes .. " new Minutes : " .. newtotalMinutes .. " Diff Minutes : " .. newtotalMinutes - thisModel.flighttimettotalminutes .. " hours: " .. hours .. " Minutes: ".. minutes)

  if thisModel.flightCountGV ~= nil then
    model.setGlobalVariable(thisModel.flightCountGV - 1, thisModel.gvFm , thisModel.flightcount + 1)
  end

  if thisModel.flighttimeHoursGV ~= nil or thisModel.flighttimeMinutesGV ~= nil then
   model.setGlobalVariable(thisModel.flighttimeHoursGV - 1, thisModel.gvFm , hours)
   model.setGlobalVariable(thisModel.flighttimeMinutesGV - 1, thisModel.gvFm , minutes)
  end

  timerControl("reset")
--  end
end

thisModel.activityTrigger.Value = 0
thisModel.loggingTrigger.Value = 0
thisModel.flightDetection.Value = 0

--thisModel.activityTriggerID = getFieldInfo(thisModel.activityTrigger).id
--thisModel.loggingTriggerID = getFieldInfo(thisModel.loggingTrigger).id

setStickySwitch(thisModel.resetTeleLS, true)

telegrace = thisModel.telemetrysettlement

activeFlightState = false


preFlightChecksPassed = false
-- AutomaticResetOnNextChange = true
isPreFlightStage = true


resetInitiated = false
screenshotTriggered = false

      FirstModelInit = true -- todo maybe there is a better place to put this ... maybe init ?

      if thisModel.flightCountGV ~= nil then

      thisModel.flightcount = model.getGlobalVariable(thisModel.flightCountGV - 1, thisModel.gvFm)
      end

      if thisModel.flighttimeHoursGV ~= nil or thisModel.flighttimeMinutesGV ~= nil then

      thisModel.flighttimeHours = model.getGlobalVariable(thisModel.flighttimeHoursGV - 1, thisModel.gvFm)
      thisModel.flighttimeMinutes = model.getGlobalVariable(thisModel.flighttimeMinutesGV - 1, thisModel.gvFm)
    
      thisModel.flighttimettotalminutes = ( thisModel.flighttimeHours  * 60 ) + thisModel.flighttimeMinutes
      end

      -- thisModel.flightstarttime = 0
    
      thisModel.activeFlightDetTimeSet = thisModel.activeFlightDetTime or 30

end

---------------------------------------------------------------------------------------------------------------------------------------


local function reset_if_needed()
  -- test if the reset switch is toggled, if so then reset all internal flags
  -- if not ResetSwitchState  then -- Update switch position
  -- if ResetSwitchState == nil or AutomaticResetOnResetPrevState ~= ResetSwitchState then -- Update switch position
    --if AutomaticResetOnResetPrevState ~= ResetSwitchState then -- Update switch position

    ResetSwitchState = getSwitchValue(thisModel.resetswitchid)

    --debugPrint("RESET: Switch state :", ResetSwitchState)

    -- if ResetSwitchState and not isPreFlightStage then
      if ResetSwitchState  then
        TriggerTimers["resetdelay"] = 0
      return -- no need to do anything when telemetry is on and no reset is needed
    end



    if not ResetSwitchState  and not isPreFlightStage and not resetInitiated then -- no telemetry for longer then delay
  
      if Timer("resetdelay", AutomaticResetOnResetSwitchToggle) then
    --AutomaticResetOnResetPrevState = ResetSwitchState

    --TriggerTimers["resetdelay"] = getTime()

    --debugPrint(string.format("RESET: State change Triggered ... Trigger State: %s at Count: %s",ResetSwitchState, AutomaticResetStateChangeCount))

    debugPrint("RESET: no telemetry for longer than 4 seconds... will reset at next telemetry on")

   -- if maj >= 2 and minor >= 11 then
   --   debugPrint("RESET: Taking Screenshot")
   -- screenshot()
   -- end

    -- AutomaticResetOnNextChange = true

 
    resetInitiated = true

      --debugPrint("RESET: RESETTING")
  
      --TriggerTimers["resetdelay"] = 0

      queueSound("eoad", 0)

      if thisModel.doScreenshot ~= nil and thisModel.doScreenshot then
        setStickySwitch(thisModel.screenshotLS, true)
        --setStickySwitch(thisModel.doScreenshot, false)
        screenshotTriggered = true
                --Timer("waitForScreenshot")
        queueSound("tss", 0)
     end

      queueSound("rs", 0)

--      --     timerControl("get" )
--
--      if activeFlightState  then
--
--        local endtime = getTime()
--        local delta = ( endtime - thisModel.flightstarttime ) / 100
--        delta = delta + thisModel.activeFlightDetTimeSet
--      
--        -- thisModel.flightstarttime
--      
--        local minutesToAdd = math.floor(delta / 60)
--        --local newtotalMinutes = thisModel.flighttimettotalminutes + minutesToAdd
--      
--        prevFlightTime = minutesToAdd
--      end

      --     timerControl("get" )

      --if activeFlightState  then

        --local endtime = getTime()
        local delta = timerControl("get")
        --delta = delta + thisModel.activeFlightDetTimeSet
      
        -- thisModel.flightstarttime
      
        local minutesToAdd = math.floor(delta / 60)
        --local newtotalMinutes = thisModel.flighttimettotalminutes + minutesToAdd
      
        prevFlightTime = minutesToAdd
      --end      

      --reset()



      end


      --if not ResetSwitchState  and not isPreFlightStage then
      --      else
      --  reset()
      --end

    end

    if not ResetSwitchState  and not isPreFlightStage and resetInitiated then

      if screenshotTriggered and Timer("waitForScreenshot", 2) then
        debugPrint("RESET: after Screenshot")
        reset()
      elseif not screenshotTriggered then
        debugPrint("RESET: immediate reset")
        reset()
      end

    end

  --      if ResetSwitchState and AutomaticResetOnNextChange then
  --        --return
--      
  --        -- AutomaticResetOnResetPrevState = ResetSwitchState
--      
  --        debugPrint("RESET: RESETTING")
--      
  --        TriggerTimers["resetdelay"] = 0
--      
  --        reset()
--      
--      
  --      end
end

---------------------------------------------------------------------------------------------------------------------------------------

local function init_func()

if not modelAlreadyLoaded then --todo --- maybe move all of this stuff out of init 

  local currentModelName = model.getInfo().name

  debugPrint ("TEST MODEL:" , currentModelName)

  modelDetails = getModelDetails(currentModelName)

  rxReferenceVoltage = modelDetails.rxReferenceVoltage
  
  thisModel = modelDetails

  switchIndexes = {}
  previousSwitchState = {}

  queueSound(modelDetails.modelWav,2)

  debugPrint("MODEL NAME: ", thisModel.modelName)
  debugPrint("MODEL IMAGE: ",thisModel.modelImage)
 
  invalidSensorList = ""

  allSensorsValid = false

  statusTele = false

  debugPrint("INIVAL: " .. thisModel.resetSwitch)

  thisModel.resetswitchid = getSwitchIndex(thisModel.resetSwitch)

  if thisModel.gvFm == nil then thisModel.gvFm = 0 end


  for _, switchInfo in ipairs(thisModel.switchAnnounces) do --todo --- maybe with a table and index too ?
    local switch = switchInfo[1]
    local switchIndex = getFieldInfo(switch).id
    debugPrint("ANN SW IDX: ", switch)
    switchIndexes[switch] = switchIndex
  end

  thisModel.bmpModelImage = Bitmap.open("/IMAGES/" .. thisModel.modelImage)

  thisModel.bmpSizedModelImage = Bitmap.resize(thisModel.bmpModelImage, 400, 300)

  BatRemainmAh = 0 -- todo

  BatRemPer = 0 -- todo remove

  thisModel.activityTrigger.id = getFieldInfo(thisModel.activityTrigger.source).id
  thisModel.loggingTrigger.id = getFieldInfo(thisModel.loggingTrigger.source).id
  thisModel.flightDetection.id = getFieldInfo(thisModel.flightDetection.source).id
  
  -- debugPrint("AID: name: " .. getFieldInfo(thisModel.activityIndicator).name)
  -- debugPrint("AID: desc: " .. getFieldInfo(thisModel.activityIndicator).desc)

  reset()

  modelAlreadyLoaded = true



end

end

---------------------------------------------------------------------------------------------------------------------------------------

local function checkForTelemetry()

  local currentStatusTele = getSwitchValue(idstatusTele)



  -- thisModel.VoltageSensor.main.
  if not currentStatusTele then

  for _, source in ipairs(thisModel.powerSources) do
    if thisModel.powerSources[source] then
      thisModel.powerSources[source].VoltageSensor.CurVolt = "--.--"
      thisModel.powerSources[source].VoltageSensor.CurPercRem = "--"
      thisModel.powerSources[source].CurrentSensor.CurAmp = "--.--"
    end
  end

    pfStatus.text = "Waiting for Telemetry"
    pfStatus.color = RED
  else

    if not statusTele and currentStatusTele and not Timer("telegrace", telegrace ) then
      pfStatus.text = "Waiting for Telemetry to settle"
      pfStatus.color = GREEN
      return
    end


    pfStatus.text = "Telemetry OK"
    pfStatus.color = GREEN
    telegrace = 0 -- will be set to model telemetrysettlement on reset (battery changed/new flight)

    end

  TriggerTimers["telegrace"] = 0

  statusTele = currentStatusTele

end
---------------------------------------------------------------------------------------------------------------------------------------

local function updateOtherSensorValues(source)

  for sensorKey, sensor in pairs(thisModel.AdlSensors) do
    updateSensorValue(sensor)
  end

end
---------------------------------------------------------------------------------------------------------------------------------------

local function updateMinMaxValues(currentValue, valueType, sensor)

  if sensor["Latest" .. valueType] == 0 or currentValue ~= 0 then
      sensor["Latest" .. valueType] = currentValue
  end

  if sensor["Highest" .. valueType] == 0 or (currentValue > sensor["Highest" .. valueType] and currentValue ~= 0.00) then
      sensor["Highest" .. valueType] = currentValue
  end

  if sensor["Lowest" .. valueType] == 0 or (currentValue < sensor["Lowest" .. valueType] and currentValue ~= 0.00) then
      sensor["Lowest" .. valueType] = currentValue
  end

end

---------------------------------------------------------------------------------------------------------------------------------------

local function updatePowerSourceSensorValues(source)
  debugPrint("UPDSEN: " .. source.displayName)

  -- Buffer Pack (or is not battery) is a special case:
  -- During flight .. we would like to get all the alerts as soon and as much as possible
  -- because this would be an emergency situation.
  -- However after Flight, when you unplug the Battery, The Buffer Pack will start doing its job 
  -- and supply "Backup" Voltage to the Receiver just like it would during flight.
  -- But in this case ... we do not want the radio yelling at us, because well ... we are landed
  -- And for this case ... if after flight (on the ground) we simply ignore and do not update
  -- the sensor anymore.
  -- how to read below if ;-) : if not battery and we have been flying for longer than activeFlightDetTimeSet and are currently NOT flying then ignore
  if source.type.isNotABattery and timerControl("get") >= thisModel.activeFlightDetTimeSet and not flightState then
    debugPrint("Special Case Buffer Return after flight")
   return
  end

  -- Update sensor values
  updateSensorValue(source.VoltageSensor)
  updateSensorValue(source.CurrentSensor)
  updateSensorValue(source.MahSensor)

  -- Update current values for display
  source.VoltageSensor.CurVolt = math.floor(getCellVoltage(source.VoltageSensor.value) * 100) / 100
  source.CurrentSensor.CurAmp = math.floor(getAmp(source.CurrentSensor.value) * 100) / 100

  -- Debug print updated sensor values
  debugPrint(string.format("SUPD Updated Sensor Values: source: %s Sensor Voltage: %s (Cell: %s) Sensor Current: %s Sensor mah: %s Volt: %s Current: %s mAh: %s",
      source.displayName,
      source.VoltageSensor.sensorName,
      source.VoltageSensor.CurVolt,
      source.CurrentSensor.sensorName,
      source.MahSensor.sensorName,
      source.VoltageSensor.value,
      source.CurrentSensor.value,
      source.MahSensor.value))

  -- Update Latest, Highest, and Lowest values if conditions are met
  updateMinMaxValues(source.VoltageSensor.CurVolt, "Volt", source.VoltageSensor)
  updateMinMaxValues(source.CurrentSensor.CurAmp, "Amp", source.CurrentSensor)

  -- Update percentage remaining if necessary
  --if not source.VoltageSensor.cellMissing then
      source.VoltageSensor.CurPercRem = findPercentRemNew(source)
      debugPrint(string.format("SUPD: Got Percent: %s for source: %s", source.VoltageSensor.CurPercRem, source.displayName))

      if source.VoltageSensor.LatestPercRem == 0 or source.VoltageSensor.LatestPercRem ~= 0 then
          source.VoltageSensor.LatestPercRem = source.VoltageSensor.CurPercRem
      end

end

---------------------------------------------------------------------------------------------------------------------------------------

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

  previousSwitchState[switch] = state

end

end

---------------------------------------------------------------------------------------------------------------------------------------

local function checkLoggingAndActivity()

--   AID: name: RPM
-- AID: desc: 
-- AID: name: se
-- AID: desc: Switch E


thisModel.activityTrigger.value = getValue(thisModel.activityTrigger.id)
thisModel.loggingTrigger.value = getValue(thisModel.loggingTrigger.id)
thisModel.flightDetection.value = getValue(thisModel.flightDetection.id)

debugPrint("CHKL: activityTriggerValue: " .. thisModel.activityTrigger.value )
debugPrint("CHKL: loggingTriggerValue: " .. thisModel.loggingTrigger.value )

local evalActivity = evaluateCondition(thisModel.activityTrigger.value, thisModel.activityTrigger.condition)
local evalLogging = evaluateCondition(thisModel.loggingTrigger.value, thisModel.loggingTrigger.condition)
local evalFlight = evaluateCondition(thisModel.flightDetection.value, thisModel.flightDetection.condition)



  if evalLogging then
    if not loggingState then 
      setStickySwitch(thisModel.loggingLS, true) 
    loggingState = true
    queueSound("tl", 0)
    queueSound("on", 2)
    debugPrint("CHKL: Logging : ON " )

  end
  else
    if loggingState then 
      setStickySwitch(thisModel.loggingLS, false) 
        loggingState = false
        queueSound("tl", 0)
        queueSound("off", 2)
        debugPrint("CHKL: Logging : OFF " )

      end
  end


  if evalActivity then
    if not activityState then 
      activityState = true
      debugPrint("CHKL: Activity : ON " )

    end
  else
    if activityState then 
      activityState = false
      debugPrint("CHKL: Activity : OFF " )

    end
  end

  if evalFlight then
    if not flightState then 
      flightState = true
      debugPrint("CHKL: Flight : ON " )

    end
  else
    if flightState then 
      flightState = false
      debugPrint("CHKL: Flight : OFF " )

    end
  end

--   if not activeFlightState then -- todo -- track time better when landed and flown again without changing battery (tele loss)
--     
--   if flightState and activityState and statusTele and Timer("activeflightstate", thisModel.activeFlightDetTimeSet ) then
--     activeFlightState = true
--     debugPrint("CHKLL: activeflightstate : ON " )
--     queueSound("afd", 2)
--     thisModel.flightstarttime = getTime()
--     timerControl("start", thisModel.activeFlightDetTimeSet )
-- 
--   elseif not flightState or not activityState or not statusTele then
--     TriggerTimers["activeflightstate"] = 0 --reset timer
--     timerControl("stop" )
--   end
-- end

--if not activeFlightState then -- todo -- track time better when landed and flown again without changing battery (tele loss)
    
  if flightState and activityState and statusTele and not activeFlightState then
    activeFlightState = true
    debugPrint("CHKLL: activeflightstate : ON " )
    queueSound("afd", 2)
    --thisModel.flightstarttime = getTime()
    timerControl("start", thisModel.activeFlightDetTimeSet )

  elseif ( not flightState or not activityState or not statusTele ) and activeFlightState then
    --TriggerTimers["activeflightstate"] = 0 --reset timer
    debugPrint("CHKLL: activeflightstate : OFF " )
    timerControl("stop" )
    activeFlightState = false
  end
--end


end
---------------------------------------------------------------------------------------------------------------------------------------

local function bg_func()

processQueue()

checkForTelemetry()

reset_if_needed() -- test if the reset switch is toggled, if so then reset all internal flags

initializeAndCheckAllSensorIds()

switchAnnounce()

doGeneralAnnouncements()

checkLoggingAndActivity()

if statusTele and allSensorsValid then -- if we have no telemetry .... don't waste time doing anything that requires telemetry

updateOtherSensorValues()

  local allSourcesPassed = true

for _, source in ipairs(thisModel.powerSources) do
  -- Check if the Voltage sensor is valid for the current source
  if source.VoltageSensor.valid then

    debugPrint("MNL: " .. source.displayName )

      updatePowerSourceSensorValues(source)
    
      check_for_missing_cellsNew(source)

      -- Perform additional checks if cell number is fine
      if source.VoltageSensor.cellMissing == 0 then
          check_cell_delta_voltageNew(source)
      end

      -- Check source status and print debug information
      local sourceStatus = checkAllSourceStatuspreFlight(source)
      debugPrint("PFST: " .. tostring(preFlightChecksPassed) .. " source: " .. source.displayName .. " Status: " .. tostring(sourceStatus))

      -- Update overall status
      if not sourceStatus then
          allSourcesPassed = false
      end

      -- Perform announcements based on the source
      doAnnouncementsNew(source)
  end
end

preFlightChecksPassed = allSourcesPassed -- Update the main flag based on the local variable

if preFlightChecksPassed then isPreFlightStage = false end -- todo --- the right place to do this ?

end -- end of if telemetry

end

---------------------------------------------------------------------------------------------------------------------------------------

local function getPercentColor(cpercent, battery)
  -- This function returns:
  -- - Red if below the critical threshold
  -- - Graduated color between red and yellow if below the warning threshold
  -- - Green if above the warning threshold
  
  local warn = battery.alertModes.warning.threshold
  local crit = battery.alertModes.critical.threshold

  if cpercent == "--" then return lcd.RGB(0xff, 0, 0) end

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

---------------------------------------------------------------------------------------------------------------------------------------

local function formatCellVoltage(voltage)
  if type(voltage) == "number" then
    vColor, blinking = Color, 0
    if voltage < 3.7 then vColor, blinking = RED, BLINK end
    return string.format("%.2f", voltage), vColor, blinking
  else
    return "------", Color, 0
  end
end

---------------------------------------------------------------------------------------------------------------------------------------

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

---------------------------------------------------------------------------------------------------------------------------------------

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
---------------------------------------------------------------------------------------------------------------------------------------

local function drawNewBatteryNew(xOrigin, yOrigin, source, wgt, batCol, txtCol, size)
  -- Context
  local myBatt = {
    ["x"] = xOrigin,
    ["y"] = yOrigin,
    ["w"] = 120,
    ["h"] = 30,
    ["segments_w"] = 15,
    ["color"] = WHITE,
    ["cath_w"] = 4,
    ["font"] = 0,
    ["cath_h"] = 18
  }

  if size == "x" then
    myBatt.h = 40
    myBatt.cath_w = 6
    myBatt.cath_h = 22
    myBatt.w = 160
    myBatt.font = MIDSIZE
  end

  local percentage = source.VoltageSensor.LatestPercRem
  local battery = source.type

  if percentage == "--" then
    percentage = 0
  end

  if percentage > 0 then
    BlinkWhenZero = 0
  else
    BlinkWhenZero = BLINK
  end

  -- Fill battery gauge
  lcd.setColor(CUSTOM_COLOR, getPercentColor(percentage, battery) )
  lcd.drawGauge(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y, myBatt.w, myBatt.h, percentage, 100, CUSTOM_COLOR)

  -- Draw battery outline
  lcd.setColor(CUSTOM_COLOR, batCol)
  lcd.drawRectangle(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y, myBatt.w, myBatt.h, batCol, 2)
  lcd.drawFilledRectangle(wgt.zone.x + myBatt.x + myBatt.w,
                          wgt.zone.y + myBatt.y + myBatt.cath_h / 2 - 2.5,
                          myBatt.cath_w,
                          myBatt.cath_h,
                          batCol)

  -- Draw battery percentage text
  lcd.drawText(wgt.zone.x + myBatt.x + 20, wgt.zone.y + myBatt.y + 5, string.format("%d%%", percentage), LEFT + myBatt.font + batCol)

  -- Draw additional information if available
  if source.MahSensor.value ~= nil and source.MahSensor.value ~= 0 then
    lcd.drawText(wgt.zone.x + myBatt.x, wgt.zone.y + myBatt.y + myBatt.h,
                 string.format("%d mAh used", source.MahSensor.value), myBatt.font + txtCol + BlinkWhenZero)
  end
end

---------------------------------------------------------------------------------------------------------------------------------------

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

---------------------------------------------------------------------------------------------------------------------------------------

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

---------------------------------------------------------------------------------------------------------------------------------------

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

---------------------------------------------------------------------------------------------------------------------------------------

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
---------------------------------------------------------------------------------------------------------------------------------------

local function refreshZoneXLarge(wgt)
  --- Size is 390x172 1/1
  --- Size is 460x252 1/1 (no sliders/trim/topbar)
  lcd.setColor(CUSTOM_COLOR, wgt.options.Color)
  local CUSTOM_COLOR = WHITE
  fontSize = 10

  -- todo     if BatRemPer > 0 then -- Don't blink
  -- todo       BlinkWhenZero = 0
  -- todo     else
  -- todo       BlinkWhenZero = BLINK
  -- todo     end
-- todo     
  -- todo     if type(thisModel.VoltageSensor.main.CurVolt) ~= "number" or thisModel.VoltageSensor.main.CurVolt == 0 then -- Blink
  -- todo       mainVoltBlink = BLINK
  -- todo     else
  -- todo       mainVoltBlink = 0
  -- todo     end
-- todo     
  -- todo     if type(thisModel.CurrentSensor.main.CurAmp) ~= "number" or thisModel.CurrentSensor.main.CurAmp == 0 then -- Blink
  -- todo       mainCurrentBlink = BLINK
  -- todo     else
  -- todo       mainCurrentBlink = 0
  -- todo     end
-- todo     
-- todo     
  -- todo     if type(thisModel.VoltageSensor.receiver.CurVolt) ~= "number" or thisModel.VoltageSensor.receiver.CurVolt == 0 then -- Blink
  -- todo       rxVoltBlink = BLINK
  -- todo     else
  -- todo       rxVoltBlink = 0
  -- todo     end
-- todo     
  -- todo     if type(thisModel.CurrentSensor.receiver.CurAmp) ~= "number" or thisModel.CurrentSensor.receiver.CurAmp == 0 then -- Blink
  -- todo       rxCurrentBlink = BLINK
  -- todo     else
  -- todo       rxCurrentBlink = 0
  -- todo     end

  -- todo -- here -- after rest has been done
  -- if thisModel.VoltageSensor.main.valid or thisModel.CurrentSensor.main.valid then drawMain = true else drawMain = false end
  -- if thisModel.VoltageSensor.receiver.valid or thisModel.CurrentSensor.receiver.valid then drawReceiver = true else drawReceiver = false end
  
  --for _, source in ipairs(availSources) do
--
  --if thisModel.powerSources[source].VoltageSensor.valid or thisModel.powerSources[source].CurrentSensor.valid then drawMain = true else drawMain = false end
  --if thisModel.powerSources.source2.VoltageSensor.valid or thisModel.powerSources.source2.CurrentSensor.valid then drawReceiver = true else drawReceiver = false end
  --
  --end


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



  --if preFlightChecksPassed or not ShowPreFlightStatus or not isPreFlightStage or ( waitForScreenshot and not Timer("waitForScreenshot", 2) ) then
    if preFlightChecksPassed or not ShowPreFlightStatus or not isPreFlightStage then




local headerSpacing = 0
local topSpacing = 0


if screenshotTriggered then -- Add Modelname to the Screenshot before it is taken -- todo can be improved
  lcd.drawText(col1, line1, thisModel.modelName , SMLSIZE + WHITE)
  lcd.drawText(col5, line1, "Active Flight Time: " .. prevFlightTime .. " m" , SMLSIZE + WHITE)
end


local fontSizes = {
  l  = { FONT = MIDSIZE, fontpxl = 24, lineSpacing = 4, colSpacing = 17 },
  m  = { FONT = 0,       fontpxl = 16, lineSpacing = 3, colSpacing = 16 },
  s  = { FONT = SMLSIZE, fontpxl = 12, lineSpacing = 2, colSpacing = 9 }
}

if wgt.zone.h > 168 then
  headerSpacing = 16
end

if wgt.zone.h > 185 then
  headerSpacing = 0
end

if wgt.zone.h > 226 then
  headerSpacing = 10
  topSpacing = 5
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

-- local function drawSensorLine(label1, label1col, value1, value1col, label2, label2col, value2, value2col, y)
--   local offsetX = x + 2
--   drawText(label1, offsetX, y, "m", label1col)
--   drawText(value1, offsetX + fontSizes["m"].colSpacing * 2, y, "m", value1col)
--   offsetX = offsetX + fontSizes["m"].colSpacing * 6
--   drawText(label2, offsetX, y, "m", label2col)
--   drawText(value2, offsetX + fontSizes["m"].colSpacing * 2, y, "m", value2col)
--   y = y + fontSizes["m"].fontpxl + fontSizes["m"].lineSpacing
--   return y
-- end





local function drawBottomSensorLine(sensors, y)
  local offsetX = x + 1
  local totalSensors = #sensors  -- Get total number of sensors
  local maxLines = 3

  local lowestCharDisplayname = 4
  local lowestCharValue = 6

  local totalCharsperLine = math.floor(( wgt.zone.w - offsetX ) / fontSizes["s"].colSpacing) 

  -- Determine the optimal number of sensors per line
  local sensorsPerLine = math.min(4, math.ceil(totalSensors / maxLines))

  local charsPerCell = math.floor(totalCharsperLine / sensorsPerLine)
  
  --local charsPerCell = math.ceil(totalCharsperLine / sensorsPerLine)

-- Calculate remaining chars after allocating charsPerCell to each sensor
local remainingChars = totalCharsperLine - (charsPerCell * sensorsPerLine)


-- Calculate additional characters to add to each sensor beyond charsPerCell
local additionalCharsPerSensor = math.floor(remainingChars / (sensorsPerLine - 1))

if additionalCharsPerSensor > 0 then charsPerCell = charsPerCell + additionalCharsPerSensor end

  local charsRemaining = charsPerCell - lowestCharDisplayname - lowestCharValue - 2 -- 2 for pre and suffix


  local function splitInTwo(total)
    local part1 = math.floor((2/3) * total)
    local part2 = total - part1
    
    -- Adjust if part1 or part2 is negative
    if part1 < 0 then
        part1 = 0
    end
    if part2 < 0 then
        part2 = 0
    end
    
    return part1, part2
end

  addCharsDisplay, addCharsValue = splitInTwo(charsRemaining)
  addCharsValue = addCharsValue / 2

  local suffixCharPosition = charsPerCell - 1
  local prefixCharPosition = lowestCharDisplayname + addCharsDisplay  -- 1 for prefix itself

  local valuePxlWidth = ( suffixCharPosition - prefixCharPosition + 1 ) * fontSizes["s"].colSpacing


-- Print debug information
print(string.format("SCCOL - valuePxlWidth: %s totalCharsperLine: %s, sensorsPerLine: %s, remainingChars: %s, additionalCharsPerSensor: %s, charsPerCell: %s, suffixCharPosition: %s, prefixCharPosition: %s, charsRemaining: %s, addCharsDisplay: %s, addCharsValue: %s width: %s colspacing: %s",
valuePxlWidth, totalCharsperLine, sensorsPerLine, remainingChars, additionalCharsPerSensor, charsPerCell, suffixCharPosition, prefixCharPosition, charsRemaining, addCharsDisplay, addCharsValue, wgt.zone.w, fontSizes["s"].colSpacing))

-- SCCOL - valuePxlWidth: 72 totalCharsperLine: 47, sensorsPerLine: 4, remainingChars: 3, additionalCharsPerSensor: 1, charsPerCell: 12, suffixCharPosition: 11, prefixCharPosition: 4, charsRemaining: 0, addCharsDisplay: 0, addCharsValue: 0 width: 426 colspacing: 9




  -- Helper function to calculate text width with special character adjustments
  local function calculateTextWidth(text, fontSize)
      local specialChars = { [","] = 2, ["."] = 2, ["°"] = -2 }
      local width = 0


      for i = 1, #text do

          local char = string.sub(text, i, i)
          
          local byte1 = string.byte(text, i)
          local byte2 = string.byte(text, i + 1)
          
          print(string.format("CHAR: %s SPC: %d %d", char, byte1 or 0, byte2 or 0))  -- Should print 194 176 for ° in UTF-8
  
          if byte1 == 194 and byte2 == 176 then
              char = "°"
              i = i + 2 -- Skip the next byte since we processed the degree symbol
          else
              i = i + 1
          end

          if specialChars[char] then
              width = width + specialChars[char]
          else
              width = width + fontSize.colSpacing
          end
      end
      return width
  end

  -- Iterate over sensors table using ipairs
  for i, sensor in ipairs(sensors) do

      -- if y > wgt.zone.h  then
      --     break
      -- end

      -- Calculate position based on sensor index and sensorsPerLine
      local currentLine = math.floor((i - 1) / sensorsPerLine)
      local colIndex = (i - 1) % sensorsPerLine
      --local sensorWidth = wgt.zone.w / sensorsPerLine
      local lineOffsetX = offsetX + colIndex * ( charsPerCell * fontSizes["s"].colSpacing )
--
      ---- Starting X position for elements
      --local elementX = lineOffsetX

      drawText(sensor.displayName, lineOffsetX, y - currentLine * (fontSizes["s"].fontpxl + fontSizes["s"].lineSpacing), "s", sensor.displayNameColor)

      lineOffsetX =  ( prefixCharPosition + ( colIndex * charsPerCell ) ) * fontSizes["s"].colSpacing
      --lineOffsetX =  prefixCharPosition  * fontSizes["s"].colSpacing * ( charsPerCell * fontSizes["s"].colSpacing * (colIndex + 1) )

      drawText(sensor.prefix, lineOffsetX, y - currentLine * (fontSizes["s"].fontpxl + fontSizes["s"].lineSpacing), "s", sensor.prefixColor)




      local valueColor = sensor.valueColor
      if sensor.cond and sensor.cond ~= "" then
          if evaluateCondition(sensor.value, sensor.cond) then
              valueColor = sensor.condColor or WHITE
          end
      end

      local formattedValue = sensor.value
      if type(sensor.value) == "number" then
          if math.floor(sensor.value) ~= sensor.value then
              formattedValue = string.format("%.2f", sensor.value)
          else
              formattedValue = tostring(sensor.value)
          end
      end

      -- Limit value to 7 characters maximum
      -- local maxValueLength = 7
      -- formattedValue = string.sub(formattedValue, 1, maxValueLength)
      local valueWithUnit = formattedValue .. sensor.unit
      local valueWidth = calculateTextWidth(valueWithUnit, fontSizes["s"])

      -- print(string.format("SCCOL - valueWidth: %d",
      -- valueWidth ))

      lineOffsetX =  lineOffsetX + ( ( valuePxlWidth - valueWidth ) / 2 )

      drawText(valueWithUnit, lineOffsetX, y - currentLine * (fontSizes["s"].fontpxl + fontSizes["s"].lineSpacing), "s", valueColor )




      
      lineOffsetX =  ( suffixCharPosition + ( colIndex * charsPerCell ) ) * fontSizes["s"].colSpacing
      --lineOffsetX =  prefixCharPosition  * fontSizes["s"].colSpacing * ( charsPerCell * fontSizes["s"].colSpacing * (colIndex + 1) )

      drawText(sensor.suffix, lineOffsetX, y - currentLine * (fontSizes["s"].fontpxl + fontSizes["s"].lineSpacing), "s", sensor.suffixColor)
      
      


      -- Adjust y position for new line if necessary
      if colIndex == sensorsPerLine - 1 and i < totalSensors then
          y = y + fontSizes["s"].lineSpacing

     end

--      debugPrint("WDGHT: H: " .. wgt.zone.h .. " FS:" ..  fontSizes["s"].fontpxl .. " Y: " .. y )
-- 
-- 
--      if y + fontSizes["s"].fontpxl >= wgt.zone.h  then
--      --  if y  >= wgt.zone.h  then
--          break
--   end



  end

  print("SNLN - Total Sensors:", totalSensors)  -- Print total sensors processed
  return y
end



--local function drawSensorLineNew(label1, label1col, value1, value1col, label2, label2col, value2, value2col, y)
  local function drawSensorLineNew(sensor, unit, y)

    if sensor.valid then

    local offsetX = x + 2

    if unit == "A" then
     val1 = sensor.CurAmp .. unit
     val2 = sensor.HighestAmp .. unit
     val2label = "H:"
    else
      val1 = sensor.CurVolt .. unit
      val2 = sensor.LowestVolt .. unit
      val2label = "L:"
    end

  drawText("C:", offsetX, y, "m", COLOR_THEME_FOCUS)
  drawText(val1, offsetX + fontSizes["m"].colSpacing * 1 + 5 , y, "m", GREEN)
  offsetX = offsetX + fontSizes["m"].colSpacing * 6
  drawText(val2label, offsetX, y, "m", COLOR_THEME_FOCUS)
  drawText(val2, offsetX + fontSizes["m"].colSpacing * 1 + 5 , y, "m", RED)

  end

  y = y + fontSizes["m"].fontpxl + fontSizes["m"].lineSpacing
  return y
end



y = 0
y = y + headerSpacing

if #thisModel.powerSources < 2 then 
  y = y + ( ( wgt.zone.h / 6 ) * #thisModel.powerSources )
end


-- Iterate over each power source
for index, source in ipairs(thisModel.powerSources) do

  -- local yOffset = topSpacing + index * (fontSizes["l"].fontpxl + fontSizes["l"].lineSpacing + headerSpacing)

  -- Draw section for each source
  y = drawText(source.displayName .. " " .. source.type.name, x, y, "l", COLOR_THEME_SECONDARY2)
  baty = y - ( fontSizes["l"].fontpxl / 2 )

  y = drawSensorLineNew(source.VoltageSensor, "V", y)
  y = drawSensorLineNew(source.CurrentSensor, "A", y)

  y = y + headerSpacing

  -- Draw battery indicator based on screen height
  if wgt.zone.h >= 272 then
    drawNewBatteryNew(280, baty , source,  wgt, COLOR_THEME_PRIMARY2, COLOR_THEME_ACTIVE, "x")
  else
    drawNewBatteryNew(230, baty, source, wgt, COLOR_THEME_PRIMARY2, COLOR_THEME_ACTIVE, "l")
  end


end

-- bottomlift = 0

-- Draw bottom sensor line
-- drawBottomSensorLine(thisModel.AdlSensors, wgt.zone.h - fontSizes["s"].fontpxl - fontSizes["s"].lineSpacing - 5)
y = y + ( fontSizes["s"].fontpxl * 2 )
drawBottomSensorLine(thisModel.AdlSensors, y)




  
  else

    

  local topSpacing = 0
  local headerSpacing = 0
  local firstHeader = true

  local fontSizes = {
      l = { FONT = MIDSIZE, fontpxl = 24, lineSpacing = 4, colSpacing = 17 },
      m = { FONT = 0,       fontpxl = 16, lineSpacing = 3, colSpacing = 16 },
      s = { FONT = SMLSIZE, fontpxl = 12, lineSpacing = 2, colSpacing = 8 }
  }


  if wgt.zone.h > 168 then
    headerSpacing = 16
  end
  
  if wgt.zone.h > 185 then
    headerSpacing = 0
  end

  if wgt.zone.h > 226 then
    headerSpacing = 10
    topSpacing = 5
  end


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

  local function drawKeyValLine(key, value, keycol, valcol, y, optval, optvalcol )
    local optval = optval or ""
    local optvalcol = optvalcol or WHITE
    local offsetX = x + 2
    drawText(key, offsetX, y, "s", keycol)
    drawText(":", offsetX + fontSizes["s"].colSpacing * 11, y, "s", WHITE)
    drawText(value, offsetX + fontSizes["s"].colSpacing * 12, y, "s", valcol)
    if optval ~= "" then
    drawText(optval, offsetX + fontSizes["s"].colSpacing * 14, y, "s", optvalcol)
    end
    y = y + fontSizes["s"].fontpxl + fontSizes["s"].lineSpacing
    return y
  end




  drawText(thisModel.modelName, wgt.zone.w / 2, y, "l", COLOR_THEME_SECONDARY2)
  lcd.drawBitmap(thisModel.bmpSizedModelImage, wgt.zone.w / 2, y + fontSizes["l"].fontpxl + fontSizes["l"].lineSpacing, 50)

  y = topSpacing

  if #thisModel.powerSources < 2 then 
    y = topSpacing + ( ( wgt.zone.h / 6 ) * #thisModel.powerSources )
  end

  -- Iterate over each power source in thisModel.powerSources
for index, source in ipairs(thisModel.powerSources) do
  -- Determine the y position based on the index and section spacing
  --y = topSpacing + index * (fontSizes["m"].fontpxl + fontSizes["m"].lineSpacing )


  -- Draw the display information for each source
  y = drawText(source.displayName .. " " .. source.type.name, x, y, "m", COLOR_THEME_SECONDARY2)


  y = drawKeyValLine("Battery Type", source.type.typeName, COLOR_THEME_FOCUS, GREEN, y)

  local CELLCOL = source.VoltageSensor.CellsDetectedCurrent ~= source.CellCount and RED or GREEN
  y = drawKeyValLine("Cell Count", source.CellCount, COLOR_THEME_FOCUS, GREEN, y, "( " .. source.VoltageSensor.CellsDetectedCurrent .. " detected )", CELLCOL)

  local VOLCOL = source.VoltageSensor.CurVolt == "--.--" and RED or GREEN
  y = drawKeyValLine("Voltage", source.VoltageSensor.CurVolt .. "V", COLOR_THEME_FOCUS, VOLCOL, y)
  y = drawKeyValLine("Percentage", source.VoltageSensor.CurPercRem .. "%", COLOR_THEME_FOCUS, getPercentColor(source.VoltageSensor.LatestPercRem, source.type), y)

  y = y + headerSpacing

end


  -- Status Section
  y = y + headerSpacing
  y = drawText("Status:", x, y, "m", COLOR_THEME_SECONDARY2)
  drawText(pfStatus.text, x, y, "s", pfStatus.color)

  y = ( wgt.zone.h / 8 ) * 6
  x = wgt.zone.w / 2

  if thisModel.flightCountGV ~= nil and thisModel.flightcount ~= 0 then

  y = drawKeyValLine("Total Flights", thisModel.flightcount, COLOR_THEME_FOCUS, GREEN, y)
  end


  if thisModel.flighttimeHoursGV ~= nil and thisModel.flighttimeMinutesGV ~= nil  then

  y = drawKeyValLine("Flight Time", thisModel.flighttimeHours .. " h " .. thisModel.flighttimeMinutes .. " m " , COLOR_THEME_FOCUS, GREEN, y)
  end

  if prevFlightTime ~= 0 then
    y = drawKeyValLine("Previous Flight", prevFlightTime .. " m " , COLOR_THEME_FOCUS, GREEN, y)

  end


end

end



---------------------------------------------------------------------------------------------------------------------------------------

local function run_func(wgt)	-- Called periodically when screen is visible
  bg_func()
  if     wgt.zone.w  > 380 and wgt.zone.h > 165 then refreshZoneXLarge(wgt)
  elseif wgt.zone.w  > 180 and wgt.zone.h > 145 then refreshZoneLarge(wgt)
  elseif wgt.zone.w  > 170 and wgt.zone.h >  65 then refreshZoneMedium(wgt)
  elseif wgt.zone.w  > 150 and wgt.zone.h >  28 then refreshZoneSmall(wgt)
  elseif wgt.zone.w  >  65 and wgt.zone.h >  35 then refreshZoneTiny(wgt)
  end
end

---------------------------------------------------------------------------------------------------------------------------------------

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

---------------------------------------------------------------------------------------------------------------------------------------

function update(Context, options)
  Color = options.Color -- left for historical reasons ... remove Color Variable -- todo 
  BGColor = Color
  Context.options = options
  Context.back = nil
  Battery_Cap = options.Battery_Cap
end

---------------------------------------------------------------------------------------------------------------------------------------

function background(Context)
  bg_func()
end

-- ---------------------------------------------------------------------------------------------------------------------------------------

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
