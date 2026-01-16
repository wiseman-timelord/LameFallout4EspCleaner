# LameFallout4EspCleaner
Status: Beta - It seems to work, and I did some work in Claude Opus to ensure its safe, and the game loads, but possibly it can be improved.

### Description:
Its lame becaue you have to give it full control, it must press enter on the active window when it pops up, and it assumes FO4Edit will be loaded within 3s, which it useually is, AND it only works in 1 thread, however its a means to an end for batch auto-cleaning Falout 4 Esps on Windows 7-8.1, because obviously if you are on Windows 10-11, then you should be using PACT.

## Requirements:
- Powershell 5.1 - Find your powershell version by typing this in `powershell -nop -c "$PSVersionTable.PSVersion"`.
- Fallout 4 + Mods - Obviously you need Fallout 4, and some significant number of mods installed, like 50+, to justify having to spend the time cleaning mods.
- FO4Edit - Get it from here... https://www.nexusmods.com/fallout4/mods/2737

### Instructions:
1) Put the extracted files in a sensible location/folder, then put, "FO4Edit 4.1.5f.zip" or some "FO4Edit*.zip", in the same folder as the scripts, the scripts will sort out the unpacking.
2) Run the batch as Admin, and then select the installer, type in your Fallout 4 full path, then from the following menu try option 3s first (This is how long after launch it will attempt to click OK, a slower machine will require longer).
3) Returning to the batch menu, run the main program, at which point the auto-cleaner will start, it will blacklist processed mods and avoid the mods detailed in avoidance.
- If reinstalling a collection, then you will want to delete the contents of the .\data\blacklist.txt file, and it will begin again fresh, otherwise it will only process new esps not on the blacklist, similar to PACT.

### Notation:
- You are advised to play a 1hr movie on the second display if you have one, then run the main program on primary display, allowing the autoclean to do its thing, or otherwise on single monitor computer, do some chors/housework leaving the machine alone to work. Worst case scenario it will be pressing enter on other focused windows, and not have pressed enter in autoclean, halting the process.

## Development:
This program may be improved upon later.
