#include <SoftwareSerial.h>
#include <SimpleKalmanFilter.h>

//  Variables
SoftwareSerial bluetooth(2, 3);
int PulseSensorPurplePin = 0; // Pulse Sensor PURPLE WIRE connected to ANALOG PIN 0
SimpleKalmanFilter kf = SimpleKalmanFilter(0.5, 0.5, 0.1);

//int LED13 = 13;  //  The on-board Arduion LED
//int ppg;  // holds the incoming raw data. Signal value can range from 0-1024
//int Threshold = 550;  // Determine which Signal to "count as a beat", and which to ingore.


// write command to bluetooth and read back
void sendCommand(const char * command){
  Serial.print("Command send :");
  Serial.println(command);
  bluetooth.println(command);
  //wait some time
  delay(100);
  
  char reply[100];
  int i = 0;
  while (bluetooth.available()) {
    reply[i] = bluetooth.read();
    i += 1;
  }
  //end the string
  reply[i] = '\0';
  Serial.print(reply);
  Serial.println("Reply end");
}


// The setUp Function:
void setup() {
  
  Serial.begin(9600);         // Set's up Serial Communication at certain speed.
  bluetooth.begin(9600);

  //pinMode(LED13,OUTPUT);       // pin that will blink to your heartbeat!

  // check communication is ok, it will return ok when you read it
  //bluetooth.println("AT");

  // reprogram the name
  //bluetooth.println("AT+NAMEppg");

}


// The main loop Function
void loop() {

  //while (bluetooth.available()) {
  //  Serial.write(bluetooth.read());
  //}

  // Read the PulseSensor's value.
  int ppg = analogRead(PulseSensorPurplePin);  
  ppg = int(kf.updateEstimate(ppg) + 0.5);
  unsigned long ts = millis();
  
  // Send the ppg value to Serial.
  //Serial.print(ts);
  //Serial.print(",");
  //Serial.println(ppg);      

  //send string to bluetooth: ts,value
  String rs = String(ts, DEC); 
  rs += ",";
  rs += String(ppg, DEC); 
  bluetooth.println(rs);    

  // dealy 10ms
  //delay(10);
  
}
