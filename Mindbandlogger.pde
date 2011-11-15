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

#define BRAIN_QUALITY_TH 150

byte print_debug_mode = 0x0;
//byte print_debug_mode = 0x1;
byte log_mode = 0x1;
//byte log_mode = 0x0;

#define COMMAND_STRING_SIZE 20
char incoming_command[COMMAND_STRING_SIZE+2]; // Allocate for CRLF too
byte incoming_position;

void set_rtc()
{
    char tmp[3]; // Temp buffer for atoi
    tmp[0] = incoming_command[2]; // Ignore the century part of 4-digit year
    tmp[1] = incoming_command[3];
    byte year = atoi(tmp);

    tmp[0] = incoming_command[5]; 
    tmp[1] = incoming_command[6];
    byte month = atoi(tmp);
    
    tmp[0] = incoming_command[8]; 
    tmp[1] = incoming_command[9];
    byte day = atoi(tmp);

    tmp[0] = incoming_command[11]; 
    tmp[1] = incoming_command[12];
    byte hour = atoi(tmp);

    tmp[0] = incoming_command[14]; 
    tmp[1] = incoming_command[15];
    byte minute = atoi(tmp);

    tmp[0] = incoming_command[17]; 
    tmp[1] = incoming_command[18];
    byte second = atoi(tmp);

    Serial.print("Parsed command '");
    Serial.print(incoming_command);
    Serial.print("' to: ");
    Serial.print(year, DEC);
    Serial.print("-");
    Serial.print(month, DEC);
    Serial.print("-");
    Serial.print(day, DEC);
    Serial.print(" ");
    Serial.print(hour, DEC);
    Serial.print(":");
    Serial.print(minute, DEC);
    Serial.print(":");
    Serial.println(second, DEC);
    
    DS1307.set_clock(year, month, day, hour, minute, second);
}

inline void process_command()
{
    if (strlen(incoming_command) > 15)
    {
        set_rtc();
    }
    switch (incoming_command[0])
    {
        case 0x50: // ASCII P
        {
            print_debug_mode = (print_debug_mode & B00000001) ^ 0x1;
            if (print_debug_mode == 0x1)
            {
                Serial.println("CSV Debug output ON");
            }
            else
            {
                Serial.println("CSV Debug output OFF");
            }
            break;
        }
        /**
         * Needs hacking of the brain library for proper support
        case 0x5A: // ASCII Z
        {
            print_debug_mode = (print_debug_mode & B00000010) ^ 0x2;
            if (print_debug_mode == 0x2)
            {
                Serial.println("Binary pass-through ON");
            }
            else
            {
                Serial.println("Binary pass-through OFF");
            }
            break;
        }
          */
    }
}

inline void read_command()
{
    for (byte d = Serial.available(); d > 0; d--)
    {
        incoming_command[incoming_position] = Serial.read();
        // Check for line end and in such case do special things
        if (   incoming_command[incoming_position] == 0xA // LF
            || incoming_command[incoming_position] == 0xD) // CR
        {
            incoming_command[incoming_position] = 0x0;
            if (   incoming_position > 0
                && (   incoming_command[incoming_position-1] == 0xD // CR
                    || incoming_command[incoming_position-1] == 0xA) // LF
               )
            {
                incoming_command[incoming_position-1] = 0x0;
            }
            process_command();
            // Clear the buffer and reset position to 0
            memset(&incoming_command, 0, COMMAND_STRING_SIZE+2);
            incoming_position = 0;
            return;
        }
        incoming_position++;

        // Sanity check buffer sizes
        if (incoming_position > COMMAND_STRING_SIZE+2)
        {
            Serial.print("PANIC: No end-of-line seen and incoming_position=");
            Serial.print(incoming_position, DEC);
            Serial.println(" clearing buffers");
            
            memset(&incoming_command, 0, COMMAND_STRING_SIZE+2);
            incoming_position = 0;
        }
    }
}


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

    // Reset OpenLog
    pinMode(3, OUTPUT);
    digitalWrite(3, HIGH); // Start high
    digitalWrite(3, LOW); // pulling low will reset
    delay(50);
    digitalWrite(3, HIGH); // return high so we can reset later
    delay(2000); // Wait for openlog to boot (alternative we could read the port until we see: "12<" 0x31 0x32 0x3C)

    DS1307.read_clock();
    /*
    SWSerial.print(DS1307.iso_ts()),
    SWSerial.print(" ");
    SWSerial.println("Booted");
    */

    

    Serial.println("Booted");
}

byte uart_incoming;
byte serial_incoming;
byte swserial_incoming;
void loop()
{
    read_command();
    /*
    if (SWSerial.available())
    {
        swserial_incoming = SWSerial.read(); 
        Serial.print("Got from SWSerial ");
        Serial.print(swserial_incoming, BYTE);
        Serial.print(" 0x");
        Serial.println(swserial_incoming, HEX);
    }
    */
    byte brain_packets = brain.update();
    
    // TODO: Add indicator led that indicates the signal quality (red/green mixing via PWM for example)
    
    // Pause logging if signalquality is above threshold (higher is worse)
    if (brain.signalQuality > BRAIN_QUALITY_TH)
    {
        return;
    }
    // Packet with the calculated power bands, these we get about once a second
    if (bitRead(brain_packets, 3))
    {
        // Update RTC
        DS1307.read_clock();
        // Put the brain and RTC data to strings
        const char* csv_data = brain.readCSV();
        const char* iso_ts = DS1307.iso_ts();
        // And dump it according to modes
        switch (log_mode)
        {
            case 0x1:
            {
                SWSerial.print(iso_ts);
                SWSerial.print(",");
                SWSerial.print(brain.rawValue, DEC);
                SWSerial.print(",");
                SWSerial.println(csv_data);
                break;
            }
        }
        switch (print_debug_mode)
        {
            case 0x1:
            {
                Serial.print(iso_ts);
                Serial.print(",");
                Serial.print(brain.rawValue, DEC);
                Serial.print(",");
                Serial.println(csv_data);
                break;
            }
        }
    }
    // Raw value packet, we don't bother writing the timestamp to these as we get them *fast* (at about 500Hz)
    if (bitRead(brain_packets, 4))
    {
        switch (log_mode)
        {
            case 0x1:
            {
                SWSerial.print(",");
                SWSerial.println(brain.rawValue, DEC);
                break;
            }
        }
        switch (print_debug_mode)
        {
            case 0x1:
            {
                Serial.print(",");
                Serial.println(brain.rawValue, DEC);
                break;
            }
        }
    }
}
