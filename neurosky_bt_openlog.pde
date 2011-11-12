#include <NewSoftSerial.h>
#include <Brain.h>
NewSoftSerial SWSerial(1, 2);
HardwareSerial Uart = HardwareSerial();
Brain brain(Uart);

void setup()
{
    Serial.begin(115200);
    Uart.begin(57600);
    pinMode(13, OUTPUT);
    // Give power to bluesmirf and enter command mode
    digitalWrite(13, HIGH);
    SWSerial.begin(38400); // This should be enough, we get data quite rarely
    Serial.println("Booted");
}

byte uart_incoming;
byte serial_incoming;
byte swserial_incoming;
void loop()
{
    if (brain.update())
    {
        Serial.println(brain.readErrors());
        Serial.println(brain.readCSV());
        
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
    if (Serial.available())
    {
        serial_incoming = Serial.read(); 
        Uart.print(serial_incoming, BYTE);
        /*
        //SWSerial.write complains about being private
        SWSerial.print(serial_incoming, BYTE);
        */
    }
}
