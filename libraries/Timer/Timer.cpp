#include "WProgram.h"
#include "Timer.h"

bool Timer::isDone()
{	// check to see if timer is complete

	if (isEnabled())
	{
		if (startTime > millis())
		{	// millis has rolled over, shouldn't happen for 50 days...
			startTime = millis();
		}
		else if ((millis() -  startTime) >= timeElapse)
		{
			startTime = millis();
			return true;
		}
	}
	return false;
}

unsigned long Timer::timeToDone()
{
	unsigned long timeLeft = timeElapse - (millis() -  startTime);
	if (timeLeft >= 0 && isEnabled())
	{
		return timeLeft;
	}
	else
	{
		return 0;
	}
	
}

void Timer::reset()
{	// reset the timer
	startTime = millis();
}

void Timer::enable()
{	// enable the timer
	enabled = true;
	reset(); // clear any remaining value
}

void Timer::disable()
{	// disable the timer
	enabled = false;
}

bool Timer::isEnabled()
{	// return if the timer is enabled
	return enabled;
}