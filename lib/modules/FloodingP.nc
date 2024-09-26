module FloodingP{
    provides interface Flooding;
    uses interface SimpleSend;
    uses interface Timer<TMilli> as FloodTimer;
}

implementation{
    uint8_t packet = "";
    uint16_t ttl = MAX_TTL;
    uint16_t sequenceNum = 0;

    pack sendReq;

    command void Flooding.flood(){}

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
        Package->src = src;
        Package->dest = dest;
        Package->TTL = TTL;
        Package->seq = seq;
        Package->protocol = protocol;
        memcpy(Package->payload, payload, length);
    }

    void sendPack(){
        makePack(&sendReq, TOS_NODE_ID, AM_BROADCAST_ADDR, MAX_TTL, PROTOCOL_FLOOD, 0, {1}, packet); 
        call SimpleSend.send(sendReq, AM_BROADCAST_ADDR);
    }

    command void Flooding.start(){
        call FloodTimer.startPeriodic(5000);
    }

    event void FloodTimer.fired(){
        sendPack();
    }
}