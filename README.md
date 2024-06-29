# TxBatTele :battery:

![GitHub stars](https://img.shields.io/github/stars/derelict/TxBatTele?style=social)
![GitHub forks](https://img.shields.io/github/forks/derelict/TxBatTele?style=social)
![GitHub watchers](https://img.shields.io/github/watchers/derelict/TxBatTele?style=social)
![GitHub repo size](https://img.shields.io/github/repo-size/derelict/TxBatTele)
![GitHub language count](https://img.shields.io/github/languages/count/derelict/TxBatTele)
![GitHub top language](https://img.shields.io/github/languages/top/derelict/TxBatTele)
![GitHub last commit](https://img.shields.io/github/last-commit/derelict/TxBatTele?color=red)
![Hits](https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2Fderelict%2FTxBatTele&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=hits&edge_flat=false)

EdgeTX/OpenTX Battery and Telemetry Monitoring LUA Widget which tries to rely as less as possible on radio settings (Everything is defined in the Script). So no need for "manual" Logical Switches or Custom Functions.

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
- If you need/want custom voice announcements (for instance modelname) submit a feature request or patch the CSV .. i will try to generate new voices as soon as i have time to

## How to contribute
- **Design the LCD Widget for various sizes** ( i'm not very good at designing / see Screenshots ;-) )

## How To's
### no mah Sensor
If you don't have a native mah Sensor but you do have a Current Sensor, you can add a custom Sensor like so:
![image](https://github.com/derelict/TxBatTele/assets/2826671/7510e0a4-cda9-4f3e-937d-59755bf00a51)
and use it here:
![image](https://github.com/derelict/TxBatTele/assets/2826671/899175e5-2013-4740-a058-fd3edc4ff4bc)

