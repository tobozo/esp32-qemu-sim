
void setup()
{
  Serial.begin( 115200 );
  Serial.println("Hello World!");
  log_n("Hello World!");
  log_e("Hello World!");
  log_w("Hello World!");
  log_i("Hello World!");
  log_d("Hello World!");
  log_v("Hello World!");
  // if( psramInit() ) {
  //   Serial.printf("Found %d bytes of PSRAM!\n", ESP.getFreePsram() );
  // } else {
  //   Serial.println("This device has no PSRAM" );
  // }
}

void loop()
{
  Serial.println("Hello World!");
  delay(1000);
}
