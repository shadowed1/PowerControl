# PowerControl
### How to Install:
Open Crosh (ctrl-alt-t), enter `shell`, copy paste, and run: 

 <pre>bash <(curl -s "https://raw.githubusercontent.com/shadowed1/PowerControl/main/bin/Download_PowerControl.sh?$(date +%s)")</pre>

__How It Works:__

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
