#include "WProgram.h"
#include "Button.h"
#include <wiring_private.h>
#include <pins_arduino.h>

bool Button::getState()
{	// check to see if digital pin state
    uint8_t bit = digitalPinToBitMask(pinNumber);
    uint8_t port = digitalPinToPort(pinNumber);

    if (port == NOT_A_PIN)
    {
        return LOW;
    }
    return (*portOutputRegister(port) & bit) ? HIGH : LOW;
}

void Button::setState(bool state)
{
	digitalWrite(pinNumber, state);
}

bool Button::getPin()
{
	return pinNumber;
}

void Button::setPin(uint8_t pin)
{
	pinNumber = pin;
}

String Button::getDescription()
{
	return description;
}

void Button::setDescription(String userDescription)
{
	description = userDescription;
}


