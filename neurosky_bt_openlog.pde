/**
 * NOTE: this code is for Teensy 2.0 in USB-serial mode
 *
 * The UART is used to talk with the NeuroSky chip
 * SWSerial used to log data to SD card
 * USB serial used for debugging
 *
 */
// Get this from https://github.com/rambo/I2C
#include <I2C.h> // For some weird reason including this in the relevant .h file does not work
#define I2C_DEVICE_DEBUG
// Get this from https://github.com/rambo/i2c_device
#include <i2c_device.h> // For some weird reason including this in the relevant .h file does not work
#include <ds1307.h>
// Get this from https://github.com/rambo/Arduino-Brain-Library
#include <Brain.h>
// Get this from http://www.pjrc.com/teensy/td_libs_NewSoftSerial.html
#include <NewSoftSerial.h>
NewSoftSerial SWSerial(1, 2);
HardwareSerial Uart = HardwareSerial();
Brain brain(Uart);

void setup()
{
    // Initialize RTC
    DS1307.begin(true);

    // USB-Serial speed
    Serial.begin(115200);

    // Set the UART speed for BlueSmirf/TGAM
    Uart.begin(57600);

    // Enable power to the BlueSmirf
    pinMode(13, OUTPUT);
    digitalWrite(13, HIGH);

    // UART Speed for the OpenLog
    SWSerial.begin(38400); // This should be enough, we get data quite rarely

    // Enable power to the OpenLog
    pinMode(0, OUTPUT);
    digitalWrite(0, HIGH);
    delay(2000);
    DS1307.read_clock();
    SWSerial.print(DS1307.iso_ts()),
    SWSerial.print(" ");
    SWSerial.println("Booted");
    Serial.println("Booted");
}

byte uart_incoming;
byte serial_incoming;
byte swserial_incoming;
void loop()
{
    if (brain.update())
    {
        DS1307.read_clock();
        const char* csv_data = brain.readCSV();
        //const char* csv_data2 = csv_data;
        const char* iso_ts = DS1307.iso_ts();
        SWSerial.print(iso_ts);
        SWSerial.print(",");
        SWSerial.println(csv_data);
        Serial.print(iso_ts);
        Serial.print(",");
        //Serial.println(csv_data2);
        Serial.println(csv_data);
    }
    /*
    if (SWSerial.available())
    {
        swserial_incoming = Uart.read(); 
        Serial.print("Got from SWSerial ");
        Serial.print(swserial_incoming, BYTE);
        Serial.print(" 0x");
        Serial.println(swserial_incoming, HEX);
    }
    */
}
