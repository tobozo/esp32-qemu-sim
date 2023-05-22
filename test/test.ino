
void setup()
{
  Serial.begin( 115200 );
  while(!Serial.available()); // wait for serial to come up
  Serial.println("Hello World!");
  if( psramInit() ) {
    Serial.printf("Found %d bytes of PSRAM!\n", ESP.getFreePsram() );
  } else {
    Serial.println("This device has no PSRAM" );
  }
}

void loop()
{
}
