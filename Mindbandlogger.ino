/**
 * NOTE: this code is for Teensy 3 in USB-serial mode
 *
 * The UART is used to talk with the NeuroSky chip
 * USB serial used for debugging
 *
 */
#include <SD.h>
#include <Time.h>  


// Get this from https://github.com/rambo/Arduino-Brain-Library
#include <Brain.h>
HardwareSerial Uart = HardwareSerial();
Brain brain(Uart);


// change this to match your SD shield or module;
// Arduino Ethernet shield: pin 4
// Adafruit SD shields and modules: pin 10
// Sparkfun SD shield: pin 8
// Teensy 2.0: pin 0
// Teensy++ 2.0: pin 20
const int chipSelect = 4;


#define BRAIN_QUALITY_TH 150
#define BRAIN_RAW_FLUSH_INTEVAL 10

byte print_debug_mode = 0x0;
//byte print_debug_mode = 0x1;
byte log_mode = 0x1;
//byte log_mode = 0x0;

#define COMMAND_STRING_SIZE 20
char incoming_command[COMMAND_STRING_SIZE+2]; // Allocate for CRLF too
byte incoming_position;


char isobuffer[20];
char* get_iso_ts()
{
    time_t t = now();
    sprintf(isobuffer,"%04u-%02u-%02u %02u:%02u:%02u",
        (int)year(t),
        (int)month(t),
        (int)day(t),
        (int)hour(t),
        (int)minute(t),
        (int)second(t)
    );

    return isobuffer;
}

void set_rtc()
{
    char tmp[3]; // Temp buffer for atoi
    tmp[0] = incoming_command[2]; // Ignore the century part of 4-digit year
    tmp[1] = incoming_command[3];
    byte t_year = atoi(tmp);

    tmp[0] = incoming_command[5]; 
    tmp[1] = incoming_command[6];
    byte t_month = atoi(tmp);
    
    tmp[0] = incoming_command[8]; 
    tmp[1] = incoming_command[9];
    byte t_day = atoi(tmp);

    tmp[0] = incoming_command[11]; 
    tmp[1] = incoming_command[12];
    byte t_hour = atoi(tmp);

    tmp[0] = incoming_command[14]; 
    tmp[1] = incoming_command[15];
    byte t_minute = atoi(tmp);

    tmp[0] = incoming_command[17]; 
    tmp[1] = incoming_command[18];
    byte t_second = atoi(tmp);

    Serial.print(F("Parsed command '"));
    Serial.print(incoming_command);
    Serial.print(F("' to: "));
    Serial.print(t_year, DEC);
    Serial.print(F("-"));
    Serial.print(t_month, DEC);
    Serial.print(F("-"));
    Serial.print(t_day, DEC);
    Serial.print(F(" "));
    Serial.print(t_hour, DEC);
    Serial.print(F(":"));
    Serial.print(t_minute, DEC);
    Serial.print(F(":"));
    Serial.println(t_second, DEC);
    
    setTime(t_hour,t_minute,t_second,t_day,t_month,t_year);
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
                Serial.println(F("CSV Debug output ON"));
            }
            else
            {
                Serial.println(F("CSV Debug output OFF"));
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
                Serial.println(F("Binary pass-through ON"));
            }
            else
            {
                Serial.println(F("Binary pass-through OFF"));
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
            Serial.print(F("PANIC: No end-of-line seen and incoming_position="));
            Serial.print(incoming_position, DEC);
            Serial.println(F(" clearing buffers"));
            
            memset(&incoming_command, 0, COMMAND_STRING_SIZE+2);
            incoming_position = 0;
        }
    }
}


File dataFile;
void setup()
{
    // USB-Serial speed
    Serial.begin(115200);

    // Set the UART speed for BlueSmirf/TGAM
    Uart.begin(57600);

    Serial.print(F("Initializing SD card..."));
    // make sure that the default chip select pin is set to
    // output, even if you don't use it:
    // TODO: Check if needed on teensy 3
    pinMode(10, OUTPUT);
  
    // see if the card is present and can be initialized:
    if (!SD.begin(chipSelect))
    {
        Serial.println(F("Card failed, or not present"));
    }
    else
    {
        Serial.println(F("card initialized."));
    }
    // TODO: Use datetime based filename
    dataFile = SD.open("datalog.txt", FILE_WRITE);
    if (!dataFile)
    {
        Serial.println(F("Failed to open logfile"));
    }

    // set the Time library to use Teensy 3.0's RTC to keep time
    setSyncProvider(Teensy3Clock.get);
    if(timeStatus() != timeSet)
    {
        Serial.println(F("Unable to sync with the RTC"));
    }
    else
    {
        Serial.println(F("RTC has set the system time"));
    }

    Serial.println(F("Booted"));
}

byte uart_incoming;
byte serial_incoming;
byte swserial_incoming;
byte loop_i;
void loop()
{
    ++loop_i;
    read_command();
    /*
    if (SWSerial.available())
    {
        swserial_incoming = SWSerial.read(); 
        Serial.print(F("Got from SWSerial "));
        Serial.write(swserial_incoming);
        Serial.print(F(" 0x"));
        Serial.println(swserial_incoming, HEX);
    }
    */
    byte brain_packets = brain.update();
    
    // TODO: Add indicator led that indicates the signal quality (red/green mixing via PWM for example)
    
    // Pause logging if signalquality is above threshold (higher is worse)
    if (brain.signalQuality > BRAIN_QUALITY_TH)
    {
        // Reset the counter
        loop_i = 0;
        return;
    }
    // Packet with the calculated power bands, these we get about once a second
    if (bitRead(brain_packets, 3))
    {
        // Update RTC
        //DS1307.read_clock();
        // Put the brain and RTC data to strings
        const char* csv_data = brain.readCSV();
        const char* iso_ts = get_iso_ts();
        // And dump it according to modes
        switch (log_mode)
        {
            case 0x1:
            {
                if (dataFile)
                {
                    dataFile.print(iso_ts);
                    dataFile.print(F(","));
                    dataFile.print(brain.rawValue, DEC);
                    dataFile.print(F(","));
                    dataFile.println(csv_data);
                    dataFile.flush();
                }
                break;
            }
        }
        switch (print_debug_mode)
        {
            case 0x1:
            {
                Serial.print(iso_ts);
                Serial.print(F(","));
                Serial.print(brain.rawValue, DEC);
                Serial.print(F(","));
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
                if (dataFile)
                {
                    dataFile.print(F(","));
                    dataFile.println(brain.rawValue, DEC);
                    if ((loop_i % BRAIN_RAW_FLUSH_INTEVAL) == 0)
                    {
                        dataFile.flush();
                    }
                }
                break;
            }
        }
        switch (print_debug_mode)
        {
            case 0x1:
            {
                Serial.print(F(","));
                Serial.println(brain.rawValue, DEC);
                break;
            }
        }
    }
}
