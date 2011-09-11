#ifndef Button_h
#define Button_h

// Button Class
class Button
{
private:
  uint8_t pinNumber;
  String description;
  int btnType;

public:
  Button(uint8_t iPin, String iDescription, int iBtnType)
  {
	pinMode(iPin, OUTPUT);
	pinNumber = iPin;
	description = iDescription;
	btnType = iBtnType;
  }
  bool getState();
  void setState(bool state);
  bool getPin();
  void setPin(uint8_t pinNum);
  String getDescription();
  void setDescription(String userDescription);
}; 

#endif

