# TxBatTele :battery:

[![GitHub release (latest by date)](https://img.shields.io/github/v/release/derelict/TxBatTele)](https://github.com/derelict/TxBatTele/releases/latest)
[![GitHub all releases](https://img.shields.io/github/downloads/derelict/TxBatTele/total)](https://github.com/derelict/TxBatTele/releases)
![GitHub repo size](https://img.shields.io/github/repo-size/derelict/TxBatTele)
![GitHub language count](https://img.shields.io/github/languages/count/derelict/TxBatTele)
![GitHub top language](https://img.shields.io/github/languages/top/derelict/TxBatTele)
![GitHub last commit](https://img.shields.io/github/last-commit/derelict/TxBatTele?color=red)
![Hits](https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2Fderelict%2FTxBatTele&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=hits&edge_flat=false)
[![Discord](https://img.shields.io/discord/839849772864503828.svg?label=&logo=discord&logoColor=ffffff&color=7389D8&labelColor=6A7EC2)](https://discord.com/channels/839849772864503828/842693696629899274)
![GitHub stars](https://img.shields.io/github/stars/derelict/TxBatTele?style=social)
![GitHub forks](https://img.shields.io/github/forks/derelict/TxBatTele?style=social)
![GitHub watchers](https://img.shields.io/github/watchers/derelict/TxBatTele?style=social)

EdgeTX/OpenTX **Battery** and **Telemetry** Monitoring LUA Widget which tries to **rely as less as possible on radio settings** (Everything is defined in the Script). So no need for "manual" Logical Switches or Custom Functions.

It's supposed to be **"A jack of all trades"** kind of thing (at least for most "standard" needs) but with a main focus on Battery Monitoring.

You can also reach out to me on the EdgeTX LUA Discord Channel (see above)

## Key Features of TxBatTele ⭐
- **Receiver** and/or **Main Battery** Monitoring: Monitor your Main **and/or** Receiver Battery. Support for different Battery Types (lipo and buffer currently, can be extended for additional battery types easily)
- **Current Sensor**: Monitor Current Consumption if a Sensor is available
- **Other Sensors**: Monitor and show other Sensors and change their color based on >, < and = condition
- **Switch State Announcements**: Voice Announcements for any Switch Position (like Armed, Disarmed, Flightmode, and so on)
- **Status Pages**: Show pre, post and in flight Statuspage (widget)
- **Pre-Flight Checks**: Check for missing/inconsistent Cells, Battery not full conditions before flight
- **Voice Announcements**: Get periodic or on changes Voice Announcements for any Condition including haptic Feedback if needed (highly customizable)
- **Logging**: Take Screenshot of the Statuspage after flight or turn on logging if/as needed based on Conditions (like Battery at 30%) ( not yet possible ... but maybe >= EdgeTX 2.11 ... see pending Feature Request: https://github.com/EdgeTX/edgetx/issues/5191 and pending pull request: https://github.com/EdgeTX/edgetx/pull/5181 )

## Video :tv:
[<img src="screenshots/demovid.gif">](https://youtu.be/zkkMqSeXS8w)

## Note
- **This is currently in alpha/"works for me" state ... use/try at your own Risk**
- Based on [mahRe2](https://github.com/fdm225/mahRe2). So full Credits to them!
- This is my first attempt in LUA Scripting. So please be gentle ;-)
- If you need/want custom voice announcements (for instance modelname) submit a feature request or patch the CSV .. i will try to generate new voices as soon as i have time to. Same applies for new Languages and/or voices (although that would require more work on my side and may take a little longer to implement ;-) )
- **Important:** We are dealing (actually relying on) with **Voltages** and "real" discharge Curves. So make sure your **Sensors are reporting the correct Values** (Check with a **Voltagemeter**) and adjust the Sensor **Offset** accordingly until it reports the real measured Value !

## How to contribute
- **Design the LCD Widget for various sizes** ( i'm not very good at designing / see Screenshots ;-) )

## How To's
### NO MAH Sensor
If you don't have a native **mah** Sensor but you do have a **Current** Sensor, you can add a **custom Sensor** like so:

![image](https://github.com/derelict/TxBatTele/assets/2826671/7510e0a4-cda9-4f3e-937d-59755bf00a51)

and use it here:

![image](https://github.com/derelict/TxBatTele/assets/2826671/899175e5-2013-4740-a058-fd3edc4ff4bc)

### How to make automatic logging working
There is a pending Feature request open, to directly implement this in LUA. But for the time being you'll have to make some small Radio Settings in order to use this Feature:

Create a **Logical Switch** like so:

![image](https://github.com/derelict/TxBatTele/assets/2826671/b6b1c3cd-5002-4b37-a6c9-de3d3fd41b73)

and then a **Special Function** for the actual logging:

![image](https://github.com/derelict/TxBatTele/assets/2826671/a6bc40c3-0486-4716-b21f-451a296fca34)

Make sure to reference the correct **logical switch**. Then in the LUA Model Definition:

![image](https://github.com/derelict/TxBatTele/assets/2826671/9e94d1ed-b566-4ed2-bf47-f1744532c5d8)

and again ... make sure to reference the correct **logical switch** by its index number. 0=L01, 1=L02 and so on.

### How to make automatic screenshots working
There is a pending Pull request open, to directly implement this in LUA. But for the time being you'll have to make some small Radio Settings in order to use this Feature:

Create a **Logical Switch** like so:

![image](https://github.com/derelict/TxBatTele/assets/2826671/fe1071b8-fe24-4f0e-98a9-3b7b9d034f02)

and then a **Special Function** for the actual screenshot taking:

![image](https://github.com/derelict/TxBatTele/assets/2826671/93556a3a-2cc2-4581-849e-09326ece0aa0)

Make sure to reference the correct **logical switch**. Then in the LUA Model Definition:

![image](https://github.com/derelict/TxBatTele/assets/2826671/3582b5b4-ddea-4129-b208-fc20a4f7bc61)

and again ... make sure to reference the correct **logical switch** by its index number. 0=L01, 1=L02 and so on.

