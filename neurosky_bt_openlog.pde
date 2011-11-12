#include <NewSoftSerial.h>
#include <Brain.h>
NewSoftSerial SWSerial(1, 2);
HardwareSerial Uart = HardwareSerial();
Brain brain(Uart);

void setup()
{
    // USB-Serial speed
    Serial.begin(115200);

    // Set the UART speed for BlueSmirf
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
        const char* csv_data = brain.readCSV();
        const char* csv_data2 = csv_data;
        SWSerial.println(csv_data);
        Serial.println(csv_data2);
    }
    if (SWSerial.available())
    {
        swserial_incoming = Uart.read(); 
        Serial.print("Got from SWSerial ");
        Serial.print(swserial_incoming, BYTE);
        Serial.print(" 0x");
        Serial.println(swserial_incoming, HEX);
    }
}
