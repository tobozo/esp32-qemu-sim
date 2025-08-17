
void setup()
{
  Serial.begin( 115200 );
  Serial.println("Hello World!");
  delay(1000);
  Serial.println("Testing log levels");
  log_n("Hello World!");
  log_e("Hello World!");
  log_w("Hello World!");
  log_i("Hello World!");
  log_d("Hello World!");
  log_v("Hello World!");
  delay(1000);
  Serial.println("Testing PSRAM");
  if( psramInit() ) {
    Serial.printf("Found %d bytes of PSRAM!\n", ESP.getFreePsram() );
  } else {
    Serial.println("This device has no PSRAM" );
  }
}

void loop()
{
  Serial.println("Hello World!");
  delay(1000);

  static int count = 0;
  count++;

  if( count == 10 ) {
    Serial.println("Test Complete, now halting!");
    while(1) delay(1);
  }
}
