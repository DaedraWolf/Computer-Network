#include "../../includes/channels.h"

module FloodingP{
    provides interface Flooding;
    uses interface SimpleSend;
    uses interface Timer<TMilli> as sendTimer;
}

implementation{
    uint8_t packet = 0;
    uint16_t ttl = MAX_TTL;
    uint16_t sequenceNum = 0; // Tracks packets by giving each a unique #, increases whenever a packet is sent
    uint8_t* floodPayload = "";

    pack sendReq;

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);
    void sendPack();

    command void Flooding.flood(){
        dbg(GENERAL_CHANNEL, "Starting Flood");
        call sendTimer.startPeriodic(5000);
    }

    command void Flooding.receivePack(pack *Package){

    }

    event void sendTimer.fired(){
        sendPack();
    }

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
        Package->src = src; // Link Layer Head
        Package->dest = dest; // Link Layer Head
        Package->TTL = TTL; // Flooding Header
        Package->seq = seq; // Flooding Header
        Package->protocol = protocol; // Flooding Header
        memcpy(Package->payload, payload, length);
    }

    void sendPack(){
        makePack(&sendReq, TOS_NODE_ID, 0, MAX_TTL, PROTOCOL_PING, sequenceNum, floodPayload, packet); 
        call SimpleSend.send(sendReq, AM_BROADCAST_ADDR);
        dbg(FLOODING_CHANNEL, "Package sent from: %d\nSequence number: %d", TOS_NODE_ID, sequenceNum);
    }

    //sequenceNum=0;

}