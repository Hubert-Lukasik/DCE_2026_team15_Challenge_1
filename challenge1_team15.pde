import nl.tue.id.oocsi.*;

//CONSTANTS ("settings")
//Radar screen
int RADAR_SCREEN_WIDTH = 600;

//height of the window where obstacles are generated (not visible by default)
int OBSTACLE_WINDOW_HEIGHT = 600;

//GRAY STRIPES (on radar)
int SPACE_BETWEEN = 100; //how many pixels are between stripes
//the number of stripes is computed in setup() because
//it relies on the screen height and since we use full screen
//the program does not know the height before the window is created in setup
int NUMBER_OF_STRIPES; 
int STRIPE_HEIGHT = 5; //the height of an individual stripe in pixels

//Obstacle
int OBSTACLE_WIDTH = 200;
int OBSTACLE_HEIGHT = 30;
//how many obstacles are maintained by the program at each time moment
int NUMBER_OF_OBSTACLES = 20;
boolean SHOW_OBSTACLES = false; //change to true if you want to see the obstacles

//Submarine
int SUBMARINE_WIDTH = 30;
int SUBMARINE_HEIGHT = 30;
int SUBMARINE_Y_POSITION = OBSTACLE_WINDOW_HEIGHT - 100; //Y coordinate of submarine is fixed

//Animations
int GLOBAL_Y_STEP = 1; //how fast does the articial Y coordinate grow
int BRIGHTENING_FACTOR = 20; //the smaller, the faster sumbarine reaches "surface"
//direction coefficient of a linear function computing the vertical change 
float LINE_DIRECTION_FACTOR = 107.5;
//second coefficient for the same linear function
float SECOND_FACTOR = -8.75;

//OOCSI seetings
OOCSI OOCSI_LISTENER = new OOCSI(this, "OOCSI-things/team-15/Kip-listener", "oocsi.id.tue.nl"); //listens to data sent by MrKip
OOCSI OOCSI_SENDER = new OOCSI(this, "OOCSI-things/team-15/Distance_sender", "oocsi.id.tue.nl"); //publishes the distance data
String DISTANCE_CHANNEL_NAME = "OOCSI-things/team-15"; //change if you want to submit to other channel

//GLOBALS (variables that change)
int currentSubmarineX = RADAR_SCREEN_WIDTH/2; //current vertical position
int xChange = 0; //change in submarine's vertical movement

int globalY = 0; //artificial Y coordinate, grows as submarine goes "up"

//X and Y coordinates of obstacles
int[] obstaclesStartingX = new int[NUMBER_OF_OBSTACLES];
int[] obstaclesStartingY = new int[NUMBER_OF_OBSTACLES];

//Y coordinate of the strips (X coords are fixed)
int[] sideStripesY;

void setup() {
  fullScreen();
  background(0, 0, 0);
  
  NUMBER_OF_STRIPES = ceil((height - 100) / SPACE_BETWEEN) + 1;
  sideStripesY = new int[NUMBER_OF_STRIPES];
  //initialize the starting positions of stripes
  for (int i = 0; i < NUMBER_OF_STRIPES; ++i) {
     sideStripesY[i] = i * SPACE_BETWEEN + 50;
  }
  
  for (int i = 0; i < NUMBER_OF_OBSTACLES; ++i) {
    obstaclesStartingX[i] = 0;
    obstaclesStartingY[i] = 0;
  }
  
  updateObstacles();

  //subscribe to channel
  OOCSI_LISTENER.subscribe("OOCSI-things/team-15", "receiveData");
}



//accepts: the sensor reading send by MrKip
//returns: the size of the step in vertical direction
float stepSize(float strength) {
  return LINE_DIRECTION_FACTOR * strength + SECOND_FACTOR;
}

//method responsible for receiving data from MrKip and updating the xChange variable
void receiveData(OOCSIEvent event) {
  float sensorValue = event.getFloat("mr-kip_d1", 0);
  if (abs(sensorValue) > 0.1){
    if (sensorValue < 0.0) {
      xChange = min(xChange, 0) + int(-1 * stepSize(abs(sensorValue)));
    } else {
      xChange = max(xChange, 0) + int(1 * stepSize(abs(sensorValue)));
    }
  } else {
    //make the slowing down "smooth"
    xChange = int(floor(float(xChange) * 0.75));
  }
}


//generates enough obstacles to always have NUMBER_OF_OBSTACLES of them
void updateObstacles() {
    int minimumY = globalY + 100;
    int lastRemoved = -1;

        
    for(int i = 0; i < NUMBER_OF_OBSTACLES; ++i) {
      if(obstaclesStartingY[i] == 0) {
        obstaclesStartingX[i] = int(random(0, RADAR_SCREEN_WIDTH - OBSTACLE_WIDTH));
        minimumY = minimumY + int(random(7, 20)) * SUBMARINE_HEIGHT;
        obstaclesStartingY[i] = minimumY;
      }
    }
    
   //check if the obstacle should be removed
  for(int i = 0; i < NUMBER_OF_OBSTACLES; ++i) {
    if (obstaclesStartingY[i] < globalY - OBSTACLE_HEIGHT) {
      lastRemoved = i;
    }
  }
  
  if (lastRemoved > -1) {
    for(int i = lastRemoved + 1; i < NUMBER_OF_OBSTACLES; ++i) {
       obstaclesStartingX[i - lastRemoved - 1] = obstaclesStartingX[i];
       obstaclesStartingY[i - lastRemoved - 1] = obstaclesStartingY[i];
       obstaclesStartingX[i] = 0;
       obstaclesStartingY[i] = 0;
    }
    
    //generate new obstacles
    if (lastRemoved == NUMBER_OF_OBSTACLES - 1) {
      minimumY = globalY + 100;
    } else {
      minimumY = obstaclesStartingY[NUMBER_OF_OBSTACLES - (lastRemoved + 1) - 1];
    }
    
    for(int i = NUMBER_OF_OBSTACLES - (lastRemoved + 1); i < NUMBER_OF_OBSTACLES; ++i) {
      if(obstaclesStartingY[i] == 0) {
        obstaclesStartingX[i] = int(random(0, RADAR_SCREEN_WIDTH - OBSTACLE_WIDTH));
        minimumY = minimumY + int(random(7, 20)) * SUBMARINE_HEIGHT;
        obstaclesStartingY[i] = minimumY;
      }
    }
  }
}

//Draw obstacles
void drawObstacles() {
  for(int i = 0; i < NUMBER_OF_OBSTACLES; ++i) {
    if(obstaclesStartingY[i] < globalY + OBSTACLE_WINDOW_HEIGHT + 2*OBSTACLE_HEIGHT) {
      fill(255, 0, 0);
      rect(obstaclesStartingX[i], OBSTACLE_WINDOW_HEIGHT - (obstaclesStartingY[i] - globalY), OBSTACLE_WIDTH, OBSTACLE_HEIGHT);
    }  
  }
}


//Check for collision between new position of submarine and obstacles and radar screen edges 
//0 -> no collision
//1 -> collision with an obstacle
//2 -> bouncing from the screen edge
int noCollision(int leftX, int upY, int stepX) {
  int newLeftX = leftX + stepX;
  int newRightX = newLeftX + SUBMARINE_WIDTH;
  int downY = upY + SUBMARINE_HEIGHT;

  //check collision with obstacles
  for (int i = 0; i < NUMBER_OF_OBSTACLES; ++i) {
     int obstLeftX = obstaclesStartingX[i];
     int obstRightX = obstLeftX + OBSTACLE_WIDTH;

     int obstUpY = OBSTACLE_WINDOW_HEIGHT - (obstaclesStartingY[i] - globalY);
     int obstDownY = obstUpY + OBSTACLE_HEIGHT;

     //Check if collision can happen based solely on heights
     if(obstUpY > upY - OBSTACLE_HEIGHT && obstDownY < downY + OBSTACLE_HEIGHT) {
       //Compare X coordinates
       if(newLeftX > obstLeftX - SUBMARINE_WIDTH && newRightX < obstRightX + SUBMARINE_WIDTH) {
         return 1;
       }
     }
  }

  //is going out of bounds of screen?
  if(newLeftX < 50 || newRightX > RADAR_SCREEN_WIDTH + 50) {
    return 2;
  }

  return 0;
}

//Compute and send the distance to the nearest obstacle above the submarine
//Send non-negative integer (the distance) or -1 (means that there are no obstacles above submarine) 
void sendDistance() {
  int distance = -1;

  //determine the smallest distance
  for (int i = 0; i < NUMBER_OF_OBSTACLES; ++i) {
     int obstLeftX = obstaclesStartingX[i];
     int obstRightX = obstLeftX + OBSTACLE_WIDTH;

     int obstUpY = OBSTACLE_WINDOW_HEIGHT - (obstaclesStartingY[i] - globalY);
     int obstDownY = obstUpY + OBSTACLE_HEIGHT;

     //Only take into account the obstacles that can collide with submarine
     if (currentSubmarineX > obstLeftX - SUBMARINE_WIDTH && currentSubmarineX < obstRightX) {
       //Discard obstacles that are below submarine
       if(obstUpY > SUBMARINE_Y_POSITION + SUBMARINE_HEIGHT) {
         continue;
       }

       int currentDistance = SUBMARINE_Y_POSITION - obstDownY;

       if(distance < 0 || currentDistance < distance) {
         distance = currentDistance;
       }
     }
  }

  //no obstacle found - distance -1
  OOCSI_SENDER.channel(DISTANCE_CHANNEL_NAME).data("distance", distance).send();
}

//updates and draws the radar stripes 
void updateAndDrawSideStripes() {
   for(int i = 0; i < NUMBER_OF_STRIPES; ++i) {
      sideStripesY[i] += GLOBAL_Y_STEP;
   }

   while (sideStripesY[NUMBER_OF_STRIPES - 1] > height - 50) {
     for(int i = NUMBER_OF_STRIPES - 2; i >= 0; --i) {
       sideStripesY[i+1] = sideStripesY[i];
     }

     sideStripesY[0] = 50;
   }

   for(int i = 0; i < NUMBER_OF_STRIPES; ++i) {
      fill(211, 211, 211);
      rect(50, sideStripesY[i], RADAR_SCREEN_WIDTH, STRIPE_HEIGHT);
   }
}

void drawRadar() {
   fill(0);
   rect(50, 50, RADAR_SCREEN_WIDTH, height - 100);   
   updateAndDrawSideStripes();
}

void drawWindow(int outside) { 
   fill(154, 154, 154);
   strokeWeight(2);
   ellipse(RADAR_SCREEN_WIDTH + 700, height / 2, 2 * (width - RADAR_SCREEN_WIDTH - 100) / 3, 2 * (width - RADAR_SCREEN_WIDTH - 100) / 3);
   fill(outside / 2, outside / 5, 54 + outside / 2);
   ellipse(RADAR_SCREEN_WIDTH + 700, height / 2, 2 * (width - RADAR_SCREEN_WIDTH - 100) / 3 - 50, 2 * (width - RADAR_SCREEN_WIDTH - 100) / 3 - 50);
}

void draw() {
  updateObstacles();
  
  //set background to white
  background(255, 255, 255);
  
  //draw Radar
  drawRadar();
  
  //Draw obstacles, if asked
  if(SHOW_OBSTACLES) {
    drawObstacles();
  }
  
  //Factor affecting the color seen through the window
  int outsideColorFactor = int(globalY / BRIGHTENING_FACTOR);
  //draw a window in submarine
  drawWindow(outsideColorFactor);
  
  //Update the artificial coordinate
  globalY += GLOBAL_Y_STEP;

  //Check winning condition
  if (outsideColorFactor >= 200) {
      textSize(60);
      fill(80, 200, 120);
      text("Congratulations, you won!", width/2, height/2);
      delay(2000);
      exit();
  }
  
  //Check losing conditions
  int collisionCode = noCollision(currentSubmarineX, SUBMARINE_Y_POSITION, xChange);
  if (collisionCode != 0 ) {
    xChange = 0;

    if (collisionCode == 1) {
      textSize(60);
      fill(255, 0, 0);
      text("Game over!", width/2, height/2);
      delay(2000);
      exit();
    }
  }

  
  currentSubmarineX += xChange;
  xChange = 0;
  noStroke();
  fill(225, 255, 0);
  rect(currentSubmarineX, height / 2, SUBMARINE_WIDTH, SUBMARINE_HEIGHT);

  //Use OOCSI to send distance to nearest obstacle
  sendDistance();
}
