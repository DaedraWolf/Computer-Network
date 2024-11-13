module TCPSendP{
    provides interface TCPSend;
    uses interface SimpleSend;
    uses interface Receive as Receiver;
    uses interface Timer<TMilli> as sendTimer;
}

implementation {
    uint8_t packet = 0;
    uint16_t ttl = MAX_TTL;
    uint16_t seqNum = 0;
    uint8_t* SendPayload = "";
    pack sendReq;

    command void TCPSend.send(uint16_t dest){
        dbg(GENERAL_CHANNEL, "Starting TCP Send\n");
        call sendTimer.startPeriodic(5000);
    }

    event void sendTimer.fired(){
        dbg(GENERAL_CHANNEL, "fired \n");
    }

    event message_t* Receiver.receive(message_t* msg, void* payload, uint8_t len) {
        dbg(GENERAL_CHANNEL, "received \n");
    }

}