Project to create a completely scalable smart home solution with Arduino.  The project is very much in its infancy.  In this project, only one room is being controlled.


**Features:**

- PIR sensor to turn on lighting when motion is sensed

- Ethernet shield with HTML page to control relays

- Override buttons to manually control lighting

- Buttons library to create as many relays controls as needed

- Timer library for general timing (couldn't find a good one...)

- Temperature reporting

- NTP server


**Hardware:**

- Arduino Uno

- Ethernet shield based On Wiznet W5100 Ethernet

- PIR

- LM335 temperature sensor

- DFRobot IR receiver/remote

- uln2803a

- 74HC4051 8-CHANNEL ANALOG MULTIPLEXER

- 74HC595 8 bit Shift Register

- High Power Relays JQX-102F


**To Do:**

- Load HTML from SD card shield

- Add security to the site

- Add IR Remote control

- Replace Ethernet shield with WiFi shield http://www.cutedigi.com/product_info.php?products_id=4564