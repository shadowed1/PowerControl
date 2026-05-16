# PowerControl
## How to Install:
Open Terminal, copy paste, and run: 

 <pre>bash <(curl -s "https://raw.githubusercontent.com/shadowed1/PowerControl/main/bin/Download_PowerControl.sh?$(date +%s)")</pre>

### Supports all Intel, AMD, and ARM64 (including Apple) SoCs.

<br>

*PowerControl:*

- Uses ARM, AMD, and Intel's max_perf_pct for easy user control.
- Pairs user adjustable max_perf_pct and thermal0 temp sensors to create a user adjustable clockspeed-temperature curve. 
- If $min_temp threshold is below a certain point, the CPU will be able to reach max_perf_pct of its speed.
- The closer the CPU approaches $max_temp, the closer it is to min_perf_pct.
- PowerControl will always be stringent regarding thermals and performance versus native behavior.
- Editable clockspeed ramp-up and ramp-down feature; emulating modern AMD thermal behavior for Intel + ARM.
- Alter the clockspeed-temperature curve to be more aggressive/passive using hotzone variable.
<br>

*GPUControl:* <br>

__For Mediatek and Intel only__ <br>

- Identifies the GPU (AMD, Adreno, Mali, and Intel) based on the name of the device's path in /sys/class/
- Limits control to only below the maximum clock speed for safety and with Chromebooks in mind.
- ChromeOS has built-in overclock prevention, so these safety precautions are just extra guardrails.
- Altering GPU clockspeed in real-time is a useful tool to debug performance. 
- Intel GPU's maximum clock speed changed from: /sys/class/drm/card0/gt_max_freq_mhz
- AMD GPU's maximum clockspeed changed from: /sys/class/drm/card0/pp_od_clk_voltage
- Adreno GPU's maximum clockspeed changed from /sys/class/kgsl/kgsl-3d0/max_gpuclk
- Mali GPU's maximum clockspeed changed from: /sys/class/devfreq/mali0/max_freq
<br>

__PowerControl commands with examples:__                                
                                                                                                     
  `powercontrol                    # Show status`                                                      
  `sudo powercontrol start         # Throttle CPU based on temperature curve`                          
  `sudo powercontrol stop          # Restore default CPU settings`                                     
  `sudo powercontrol no_turbo 1    # 0 = Enable, 1 = Disable Turbo Boost`                              
  `sudo powercontrol max 75        # Set max performance percentage`                                   
  `sudo powercontrol min 50        # Set minimum performance at max temp`                              
  `sudo powercontrol max_temp 86   # Max temperature threshold - Limit is 90°C`                        
  `sudo powercontrol min_temp 60   # Min temperature threshold`                                        
  `sudo powercontrol hotzone 78    # Temperature threshold for aggressive thermal management`          
  `sudo powercontrol ramp_up 15    # % in steps CPU will increase in clockspeed per second`            
  `sudo powercontrol ramp_down 20  # % in steps CPU will decrease in clockspeed per second`            
  `sudo powercontrol hotzone 78    # Temperature threshold for aggressive thermal management`          
  `sudo powercontrol poll 1        # PowerControl polling rate in seconds (0.1s - 5s)`                 
  `sudo powercontrol monitor       # Toggle live temperature monitoring`        
  `sudo powercontrol limits        # Print x86_64 Power Limits`         
  `sudo powercontrol startup       # Copy or Remove no_turbo.conf & powercontrol.conf at: /etc/init/`          
  `sudo powercontrol startup_all   # Copy or remove all /etc/init/ .conf files for PowerControl`     
  `sudo powercontrol start_all     # Start all modules for PowerControl`      
  `sudo powercontrol stop_all      # Stop all modules for PowerControl`       
  `sudo powercontrol reinstall     # Redownload and reinstall PowerControl from Github`       
  `sudo powercontrol uninstall     # Uninstall PowerControl`                                  
  `sudo powercontrol version       # Check PowerControl version`        
<br><br>

  __GPUControl commands with examples:__                                       
                                                                                                                  
  `gpucontrol                     # Show current GPU info and frequency`                                            
  `gpucontrol help                # Show this help menu`         
  `gpucontrol monitor             # Monitor GPU clockspeed in real-time.`        
  `sudo gpucontrol restore        # Restore GPU max frequency to original value`                                         
  `sudo gpucontrol 800            # Set GPU max frequency to 800 MHz`            
  `sudo gpucontrol startup        # Enable or disable GPUControl on startup`
  <br><br>

  
*Changelog:*

- 0.1:  `Released PowerControl for Linux.`<br> <br>
- 0.2:  `Added Graph for PowerControl. Fixed AMD CPU temp sensor on Linux. Thanks to Tavreth for helping.` <br><br>
  
