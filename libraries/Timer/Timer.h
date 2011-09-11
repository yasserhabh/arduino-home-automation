#ifndef Timer_h
#define Timer_h

// Timer Class
class Timer
{
private:
  unsigned long timeElapse;
  unsigned long startTime;
  bool enabled;
public:
  Timer(unsigned long msTime)
  {
	enabled = true;
    timeElapse = msTime;
  }
  bool isDone();
  void reset();
  void enable();
  void disable();
  bool isEnabled();
  unsigned long timeToDone();
}; 

#endif

