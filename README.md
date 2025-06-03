# The IRS (The ~~Internal Revenue Service~~ Internet Recovery Shim)

v1.1.1

those who recover

# Building
Run on a SH1MMER shim
```bash
git clone https://github.com/SSU-Development/IRS.git
```
Copy a Legacy SH1MMER shim into the cloned repo
```bash
sudo bash irs_builder.sh sh1mmer_board.bin
```

# What can it do?
Uses wifi (Yes, it works!!!) or Ethernet.

* ✅ Connect to wifi
* ✅ Download recovery images
* ✅ Recover with those recovery images, or images put in the device by another device.
* ✅ Boot shims

> [!WARNING]
> Wifi on some grunt boards is broken. One of them is, in fact, barla. Fuck you, barla. If anyone has a solution for this, please open an issue <br>
> <sub> edit: a solution is being worked on, all we need to do is compile the rtw88 kernel modules for the grunt shim kernel :3 - kxtz (eta wen? idk, probably irs 2) <sub>
# Prebuilts
no.

# Credits
- Sophia: The lead developer of IRS, Figured out wifi
- Synaptic: Emotional Support
- Simon: Brainstormed how to do wifi, helped with determining wireless interface
- kraeb: QoL improvements and initial idea
- xmb9: The name, builder, and part of shim booting
- AC3: Literally nothing
- Rainestorme: Murkmod's version finder

```
               _____   _    __  __                
              |_   _| / \   \ \/ /                
                | |  / _ \   \  /                 
                | | / ___ \  /  \                 
                |_|/_/   \_\/_/\_\                
   _____ __     __ _     ____  ___  ___   _   _ 
  | ____|\ \   / // \   / ___||_ _|/ _ \ | \ | |
  |  _|   \ \ / // _ \  \___ \ | || | | ||  \| |
  | |___   \ V // ___ \  ___) || || |_| || |\  |
  |_____|   \_//_/   \_\|____/|___|\___/ |_| \_|
```
> [!WARNING]
> We just got 8 free pizzas!
