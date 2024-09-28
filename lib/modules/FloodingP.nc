#include "../../includes/channels.h"

module FloodingP{
    provides interface Flooding;
    uses interface SimpleSend;
    uses interface Timer<TMilli> as sendTimer;
}

implementation{
    uint8_t packet = "";
    uint16_t ttl = MAX_TTL;
    uint16_t sequenceNum = 0; // Tracks packets by giving each a unique #, increases whenever a packet is sent
    uint8_t* payload = "";

    pack sendReq;

    command void Flooding.flood(){
        call sendTimer.startPeriodic(5000);
    }



    event void sendTimer.fired(){
        sendPack();
    }

        void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
        Package->src = src;
        Package->dest = dest;
        Package->TTL = TTL;
        Package->seq = seq;
        Package->protocol = protocol;
        memcpy(Package->payload, payload, length);
    }

    void sendPack(){
        makePack(&sendReq, TOS_NODE_ID, 0, MAX_TTL, PROTOCOL_PING, 0, &payload, packet); 
        call SimpleSend.send(sendReq, AM_BROADCAST_ADDR);
    }
}