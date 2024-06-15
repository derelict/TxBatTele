# TxBatTele

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
- **Receiver** and **Main Battery** Monitoring: Monitor your Main and Receiver Battery. Support for different Battery Types (lipo and buffer currently)
- **Current Sensor**: Monitor Current Consumption if a Sensor is available
- **Other Sensors**: Monitor and show other Sensors
- **Switch State Announcements**: Voice Announcements for any Switch Position (like Armed, Disarmed, Flightmode, and so on)
- **Status Pages**: Show pre, post and in flight Statuspage (widget)
- **Pre-Flight Checks**: Check for missing/inconsistent Cells, Battery not full conditions before flight
- **Voice Announcements**: Get Voice Announcements for any Condition including haptic Feedback if needed
- **Logging**: Take Screenshot of the Statuspage after flight or turn on logging if/as needed based on Conditions (like Battery at 30%)

## Screenshots
![image](https://github.com/derelict/TxBatTele/assets/2826671/480d3ce7-b507-47c2-8f4d-54872552ef35)
![image](https://github.com/derelict/TxBatTele/assets/2826671/736a24f7-07dc-46b2-9aee-5dd0c7888315)
![image](https://github.com/derelict/TxBatTele/assets/2826671/86d20bad-c9b3-4dc4-bc53-4cc4f43b8d66)

## Note
- **This is currently in alpha/"works for me" state ... use/try at your own Risk**
- Based on [mahRe2](https://github.com/fdm225/mahRe2). So full Credits to them!
- This is my first attempt in LUA Scripting. So please be gentle ;-)

## How to contribute
- **Design the LCD Widget for various sizes** ( i'm not very good at designing / see Screenshots ;-) ) 
