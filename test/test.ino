
void setup()
{
  Serial.begin( 115200 );
  Serial.println("Hello World!");
  if( psramInit() ) {
    Serial.printf("Found %d bytes of PSRAM!\n", ESP.getFreePsram() );
  }
}

void loop()
{
}
