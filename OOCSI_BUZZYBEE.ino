/****************************************************************************

  Code runs a vibration motor connected to an ESP32 so that the frequency of 
  the buzzes increases as the value being recieved from OOCSI decreases. 

  This module only RECEIVES data.

  Vibration motor connection:
    5V (red wire)        -> battery pack  !!!DO NOT POWER DIRECTLY FROM ESP!!!
    I0 (white wire)      -> pin 33
    GND (black wire).    -> ground on ESP and ground on battery pack

 ****************************************************************************/

#include "OOCSI.h"

#define SEP "/"
// this is the course space
#define COURSE "OOCSI-things"
// this is the team space
#define TEAM "team-15"
// this is the thing name
#define THING "BUZZYBEE_####"

// name for connecting with OOCSI (unique handle)
const char* OOCSIName = COURSE SEP TEAM SEP THING;
const char* OOCSIChannel = COURSE SEP TEAM;

// SSID of your Wifi network
const char* ssid = "iotroam";
// Password of your Wifi network.
const char* password = "StvRD2fAtt";
// put the address of your OOCSI server here, can be URL or IP address string
const char* hostserver = "oocsi.id.tue.nl";

// OOCSI reference for the entire sketch
OOCSI oocsi = OOCSI();

//set the pin the vibration motor is attached to
const int buzzPin = 33;       

int distance = 0;
//Set the min and max input values that will be received via OOCSI
int minDistance = 0;      
int maxDistance = 3000;

//Setting up variables used in the code. These do not need to be changed
const int pwmChannel = 0;
const int pwmFreq = 500;
const int pwmResolution = 8;
unsigned long previousBuzz = 0;
unsigned long frequency = 1000;
unsigned long buzzTime = 100;



// put your setup code here, to run once:
void setup() {
  Serial.begin(115200);

  //connect vibration motor to ESP32
  ledcAttach(buzzPin, pwmFreq, pwmResolution);

  // connect wifi and OOCSI to the server
  oocsi.connect(OOCSIName, hostserver, ssid, password, processOOCSI);

  // subscribe to a channel
  oocsi.subscribe(OOCSIChannel);
}

void loop() {

  oocsi.check();

  //remove any value higher or lower than the max and min recieved by OOCSI to clean the data
  distance = constrain(distance, minDistance, maxDistance);

  //plot against a curve so time between buzzes gets more noticably shorter
  float normalised = (float)(distance - minDistance) / (maxDistance - minDistance);
  frequency = 100 + (normalised * normalised * 2000);       //change the two number values to adjust the rate the buzz frequency changes

  //update millis 
  unsigned long currentMillis = millis();

  //check if another buzz is due by comparing the time since the last buzz to the frequency
  if (currentMillis - previousBuzz >= frequency) {
    previousBuzz = currentMillis;
    
    //short buzz and then pause   
    ledcWrite(buzzPin, 255);  
    delay(50);
    ledcWrite(buzzPin, 0);  

  }
}


// function which OOCSI calls when an OOCSI message is received
void processOOCSI() {

  if (oocsi.has("distance")) {
    distance = oocsi.getInt("distance", 0);

    //distances off the screen are shown as -1 so must be set to the max distance. This can be removed
    if (distance == -1 ) {
    distance = maxDistance;
    }

    Serial.println(distance);

  }
}