#include <SPI.h>
#include <Ethernet.h>
#include <UDP.h>
#include <Time.h>
#include <wprogram.h>
#include <wiring_private.h>
#include <pins_arduino.h>
#include <Timer.h>
#include <Button.h>

// constants
const int TIMEOUT_THRESHOLD = 5; // 5 minutes
const int PIR_THRESHOLD = 600;
const long TIME_ZONE_CORRECTION =  4*3600L; // correction for time zone in seconds
const int PIR_PIN = 5;
const int TEMP_PIN = 4;

// relay setup
int relays[] =
{
    6,7
};
const int NUMOFRELAYS = sizeof(relays)/sizeof(relays[0]);
char* relayDescriptions[] =
{
    "Accent lights", "Ceiling lights"
};

Button buttons[NUMOFRELAYS] = 
{
	Button(relays[0], relayDescriptions[0], 1),
	Button(relays[1], relayDescriptions[1], 1)	
};

// TODO: make a class for buttons...
bool overrideFlag = false; // override sensor input, note: lights still turn off after TIMEOUT_THRESHOLD
int allOnFlag = -1; // track the all on/off button state, tri state...

// network setup globals
byte mac[] =
{
    0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED
};
byte ip[] =
{
    192,168,2,177
};
Server server(80);
unsigned int localPort = 8888;      // local port to listen for UDP packets
String readString = String(35);

// NTP stuff
byte timeServer[] =
{	// time.nist.gov NTP serve
    192, 43, 244, 18
};
const int NTP_PACKET_SIZE = 48;	    // NTP time stamp is in the first 48 bytes of the message
byte packetBuffer[NTP_PACKET_SIZE]; // buffer to hold incoming and outgoing packets

// Timers
Timer timerWebRequests = Timer((unsigned long)50);		// 50ms for checking HTTP requests
Timer timerPIR = Timer((unsigned long)TIMEOUT_THRESHOLD*60*1000); // 5 minutes for PIR timeout
Timer timerNTP = Timer((unsigned long)TIMEOUT_THRESHOLD*60*1000); // 5 minutes for NTP

void setup()
{
    Serial.begin(9600);

    // initialize I/O
    pinMode(PIR_PIN, INPUT);
	pinMode(TEMP_PIN, INPUT);

    // start the Ethernet connection and the server
    Ethernet.begin(mac, ip);
    Udp.begin(localPort);
    server.begin();
    Serial.println("waiting for sync");
    setSyncProvider(GetNtpTime);

    while (timeStatus()== timeNotSet)
    {	// wait until the time is set by the sync provider
        delay(10);
    }
}

void loop()
{    
	if (timerWebRequests.isDone())
	{	// check about 20 times a second for incoming clients, tried 10 and 5 times a second was a little unrepsonsive
		Client client = server.available();
		if (client)
		{
			CheckRequest(client);
		}
		timerWebRequests.reset();
	}

    if (analogRead(PIR_PIN) > PIR_THRESHOLD)
    {	// turn on lights
		if (!overrideFlag)
		{	// if override is not active, turn the lights on
			for (int i=0; i < NUMOFRELAYS; ++i)
			{
				buttons[i].setState(HIGH);
			}
		}
		timerPIR.enable();
    }

	if (timerPIR.isDone())
    {	// no motion has been sensed, turn off even if override is on...
		for (int i=0; i < NUMOFRELAYS; ++i)
		{
			buttons[i].setState(LOW);
		}
		timerPIR.disable();
    }

	if (timerNTP.isDone())
	{	// re-sync time every 5 minutes.
		GetNtpTime();
		timerNTP.reset();
	}
	delay(10);
}

// --------------- UTILITIES ----------------------
void UpTime(Client client)
{	// print up time
    long days = 0;
    long hours = 0;
    long mins = 0;
    long secs = 0;
    secs = millis()/1000;		//convect milliseconds to seconds
    mins = secs/60;				//convert seconds to minutes
    hours = mins/60;			//convert minutes to hours
    days = hours/24;			//convert hours to days
    secs = secs - mins*60;		//subtract the coverted seconds to minutes in order to display 59 secs max
    mins = mins - hours*60;		//subtract the coverted minutes to hours in order to display 59 minutes max
    hours = hours - days*24;	//subtract the coverted hours to days in order to display 23 hours max

    // print running time
	client.println("<br>");
	client.println("Running Time(DD:HH:MM:SS): ");
	PrintDigits(days, client, false);
    PrintDigits(hours, client, true);
    PrintDigits(mins, client, true);
	PrintDigits(secs, client, true);
}
void PrintDigits(int digits, Client client, bool printColon)
{	// utility function for digital clock display: prints preceding colon and leading 0
	if (printColon)
	{
		client.print(":");
	}

    if (digits < 10)
    {
        client.print('0');
    }
    client.print(digits);
}

// --------------- HTML HANDLING ------------------
void CheckRequest(Client client)
{
    // an http request ends with a blank line
    boolean currentLineIsBlank = true;

    while (client.connected())
    {
        if (client.available())
        {
            char c = client.read();

            if (readString.length() < 35)
            {	// read char by char HTTP request, store characters to string
                readString += c;
            }

            // if you've gotten to the end of the line (received a newline
            // character) and the line is blank, the http request has ended,
            // so you can send a reply
            if (c == '\n' && currentLineIsBlank)
            {
                // send a standard http response header
                client.println("HTTP/1.1 200 OK");
                client.println("Content-Type: text/html");
                client.println();

                //client.println(readString); // debug
				
				if (overrideFlag)
				{	// turn on lights if override is active
					for (int i = 0; i < NUMOFRELAYS; ++i)
					{	// loop to parse out commands
						String tmpNumRelay = String(i+1, DEC); // using 0 based for loop index, but we want the relay number to start at one

						if (readString.indexOf("R00" + tmpNumRelay + "=ON") != -1)
						{
							buttons[i].setState(LOW);
							allOnFlag = -1;
						}
						else if (readString.indexOf("R00" + tmpNumRelay + "=OFF") != -1)
						{
							buttons[i].setState(HIGH);
							allOnFlag = -1;
						}
					}

					if (readString.indexOf("allOn=ON") != -1)
					{
						for (int i = 0; i < NUMOFRELAYS; ++i)
						{	// toggle to off
							buttons[i].setState(LOW);
						}
						allOnFlag = 0;
					}
					else if (readString.indexOf("allOn=OFF") != -1)
					{
						for (int i = 0; i < NUMOFRELAYS; ++i)
						{	// toggle to on
							buttons[i].setState(HIGH);
						}
						allOnFlag = 1;
					}
					else if (readString.indexOf("allOn=N%2FA") != -1)
					{	// it hasn't been initialized at this point, let's use a little intelligence
						int onCtr = 0;
						for (int i = 0; i < NUMOFRELAYS; ++i)
						{
							if (buttons[i].getState())
							{
								onCtr++;
							}
						}
						if (onCtr > 1)
						{	// found two or more relays on, let us just turn them off
							for (int i = 0; i < NUMOFRELAYS; ++i)
							{
								buttons[i].setState(LOW);
							}
							allOnFlag = 0;
						}
						else
						{   // one or less are on, let's just assume they want them on... 
							for (int i = 0; i < NUMOFRELAYS; ++i)
							{
								buttons[i].setState(HIGH);
							}
							allOnFlag = 1;
						}
					}
				}
				else
				{	// override not on
					allOnFlag = -1;
				}

                if (readString.indexOf("Override=ON") != -1)
                {
                    overrideFlag = false;
                }
                else if (readString.indexOf("Override=OFF") != -1)
                {
                    overrideFlag = true;
                }

                readString = 0;

                PrintHTML(client);
				
				// Other information...
                client.println("<br>");
				DigitalClockDisplay(client);
				PrintTemperature(client);
				UpTime(client);
				
				if (!overrideFlag)
				{
					client.println("<br>");
					client.print("Time left before lights turn off (Sec): ");
					client.print(long(timerPIR.timeToDone()/1000));
				}
				client.println("<br>");
				client.print("PIR value (A5): ");
                client.print(analogRead(PIR_PIN));

                break;
            }

            if (c == '\n')
            {	// starting a new line
                currentLineIsBlank = true;
            }
            else if (c != '\r')
            {	// you've gotten a character on the current line
                currentLineIsBlank = false;
            }
        }
    }

    delay(1);		// give the web browser time to receive the data

    client.stop();	// close the connection
}

void PrintHTML(Client client)
{
    client.println("<body>");
    client.println("<center>");
    // todo, read this from an SD Card, save, load, edit would be nice...
    client.println("<table style=\"text-align: center\" border=\"1\" cellpadding=\"2\" cellspacing=\"2\">");
    client.println("<tbody>");

    // print the header row
    client.println("<tr>");

    client.println("<td>");
    client.println("Status");
    client.println("</td>");

    client.println("<td>");
    client.println("Description");
    client.println("</td>");

    client.println("</tr>");

    for (int i = 0; i < NUMOFRELAYS; ++i)
    {	// print the relay table
        String tmpNumRelay = String(i+1, DEC); // using 0 based for loop index, but we want the relay number to start at one
        client.println("<tr>");
        client.println("<td>");

        client.println("<form method=\"get\" name=\"R00" + tmpNumRelay + "\">");

        // display current relay status on buttons

        if (buttons[i].getState())
        {
            client.println("<input name=\"R00" + tmpNumRelay + "\" value=\"ON\" type=\"submit\">");
        }
        else
        {
            client.println("<input name=\"R00" + tmpNumRelay + "\" value=\"OFF\" type=\"submit\">");
        }

        client.println("</form>");
        client.println("</td>");

        client.println("<td>" + buttons[i].getDescription() + "</td>");
        client.println("</tr>");
    }
	
	// override button
    client.println("<tr>");
    client.println("<td>");
	client.println("<form method=\"get\" name=\"Override\">");
	client.println("<input name=\"Override\"");
    if (overrideFlag)
    {		       
        client.println("value=\"ON\"");
    }
    else
    {
        client.println("value=\"OFF\"");
       
    }
	client.println("type=\"submit\">");
	client.println("</form>");
    client.println("</td>");
    client.println("<td>Sensor Override</td>");
    client.println("</tr>");

	
	if (overrideFlag)
	{	// all on/off button, print only if override is on
		client.println("<tr>");
		client.println("<td>");
		client.println("<form method=\"get\" name=\"allOn\">");
		client.println("<input name=\"allOn\"");

		if (allOnFlag == 1)
		{		       
			client.println("value=\"ON\"");
		}
		else if (allOnFlag == 0) 
		{
			client.println("value=\"OFF\"");	       
		}
		else
		{	// not active
			client.println("value=\"N/A\"");	
		}

		client.println("type=\"submit\">");
		client.println("</form>");
		client.println("</td>");
		client.println("<td>All On/Off</td>");
		client.println("</tr>");
	}

	// end the table
    client.println("</tbody>");
    client.println("</table>");
    client.println("<br>");
    client.println("<center>");
    client.println("</body>");
}

// ---------------- NTP CODE ----------------------
unsigned long GetNtpTime()
{
    SendNTPpacket(timeServer);
    delay(1000);

    if (Udp.available())
    {
        Udp.readPacket(packetBuffer,NTP_PACKET_SIZE); // put packet into buffer, ignore every field except the time (start at buffer pos
        unsigned long highWord = word(packetBuffer[40], packetBuffer[41]);
        unsigned long lowWord = word(packetBuffer[42], packetBuffer[43]);
        // combine the four bytes (two words) into a long integer
        // this is NTP time (seconds since Jan 1 1900):
        unsigned long secsSince1900 = highWord << 16 | lowWord;
        const unsigned long seventy_years = 2208988800UL + TIME_ZONE_CORRECTION;
        return secsSince1900 -  seventy_years; // convert from NTP to UNIX time (70 years difference), offset for time zone
    }

    Serial.println("waiting for sync 1234");

    return 0; // return 0 if unable to get the time
}

unsigned long SendNTPpacket(byte *address)
{	// send a NTP request to the time server at the given address
    // set all bytes in the buffer to 0
    memset(packetBuffer, 0, NTP_PACKET_SIZE);

    // initialize values needed to form NTP request
    packetBuffer[0] = 0b11100011;   // LI, Version, Mode
    packetBuffer[1] = 0;     // Stratum, or type of clock
    packetBuffer[2] = 6;     // Polling Interval
    packetBuffer[3] = 0xEC;  // Peer Clock Precision
    // 8 bytes of zero for Root Delay & Root Dispersion
    packetBuffer[12]  = 49;
    packetBuffer[13]  = 0x4E;
    packetBuffer[14]  = 49;
    packetBuffer[15]  = 52;

    // all NTP fields have been given values, now
    // you can send a packet requesting a timestamp:
    Serial.println("waiting for sync 123");
    Udp.sendPacket(packetBuffer,NTP_PACKET_SIZE, address, 123); //NTP requests are to port 123
    Serial.println("waiting for sync 125");
}

void DigitalClockDisplay(Client client)
{	// digital clock display of the time
	client.print("Time: ");
    client.print(hourFormat12());
    PrintDigits(minute(),client, true);
    PrintDigits(second(),client, true);

    if (isAM())
    {
        client.print(" AM");
    }
    else
    {
        client.print(" PM");
    }

    client.print("<br>");

    client.print("Date: ");
    client.print(month());
    client.print("-");
    client.print(day());
    client.print("-");
    client.print(year());
    client.println("<br>");
}

// ---------------- TEMPERATURE -------------------
void PrintTemperature(Client client)
{
	float volt = 0.0;
	float mVolt = 0.0;
	float ferenheit = 0.0;
	float celcius = 0.0;
	float sampleVal = 0.0;
	const int numSamples = 8;
	const int VCC = 4980; // Vref in millivolts, we can probably make this a little more accurate with measurement
	int samplesAccumulator = 0;
	const float correctionGain = 0.97;

	for (int i = 1; i <= numSamples; i++) 
	{	// take multiple samples and take average for better accuracy
		samplesAccumulator += analogRead(TEMP_PIN);
		delay(1);
	}
	sampleVal = samplesAccumulator/numSamples;

	volt = ((VCC*sampleVal)/1024.0)*0.10;  // AD conversion, gives us 1mV/0.1K; divide by 10 to get 10mV/1K + decimal as per data sheet for LM335
	celcius = (volt - 273.15)*correctionGain;
	ferenheit = (celcius * 9/5) + 32;
	client.println("<br>");
	client.print("Temperature: ");
	client.print(ferenheit);
}
