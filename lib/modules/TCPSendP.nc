#define SLIDING_WINDOW_SIZE 1

module TCPSendP{
    provides interface TCPSend;
    uses interface SimpleSend;
    uses interface Receive as Receiver;
    uses interface Timer<TMilli> as sendTimer;
}

implementation {
    uint8_t sendLength = 0;
    uint16_t ttl = MAX_TTL;
    // uint16_t seqNum = 0;
    uint16_t frame = 0;
    uint8_t* sendPayload = ""; //use array?
    uint16_t destination;
    pack sendReq;

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);
    void sendPack(uint16_t seqNum);
    void forwardPack(pack* Package);

    command void TCPSend.send(uint16_t dest){
        dbg(GENERAL_CHANNEL, "Starting TCP Send\n");
        destination = dest;
        call sendTimer.startPeriodic(5000);
    }

    event void sendTimer.fired(){
        uint16_t i;

        for (i = 0; i < SLIDING_WINDOW_SIZE; i++) {
            sendPack(frame + i);
        }
    }

    // using routing table to send and forward
    event message_t* Receiver.receive(message_t* msg, void* payload, uint8_t len) {
        if (len == sizeof(pack)) {
            pack* package = (pack*)payload;
            if (package->protocol == PROTOCOL_TCP) {
                if (package->seq < frame || package->seq > frame + SLIDING_WINDOW_SIZE) {
                    //drop
                }

                //send ack
            }
            if (package->protocol == PROTOCOL_TCPREPLY) {
                if (package->seq == frame) {
                    frame++;
                }
            }
        }
    }

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
        Package->src = src;
        Package->dest = dest;
        Package->TTL = TTL;
        Package->seq = seq;
        Package->protocol = protocol; 
        memcpy(Package->payload, payload, length);
    }

    void sendPack(uint16_t seqNum){
        makePack(&sendReq, TOS_NODE_ID, 0, MAX_TTL, PROTOCOL_TCP, seqNum, sendPayload, sendLength); 
        call SimpleSend.send(sendReq, destination);
        // dbg(GENERAL_CHANNEL, "Node %d broadcasting package; Sequence number: %d\n", TOS_NODE_ID, sequenceNum);
    }

}