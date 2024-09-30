#define MAX_NEIGHBORS 20

#include "../../includes/channels.h"

module NeighborDiscoveryP{
    provides interface NeighborDiscovery;
    uses interface SimpleSend;
    uses interface Timer<TMilli> as sendTimer;
    uses interface Receive as Receiver;
}

implementation{
    uint8_t packet = 0;
    uint16_t ttl = MAX_TTL;
    uint16_t sequenceNum = 0; // Tracks packets by giving each a unique #, increases whenever a packet is sent
    uint8_t* neighborPayload = "";

    pack sendReq;

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);
    void sendPack();

    command void NeighborDiscovery.discoverNeighbors(){
        dbg(GENERAL_CHANNEL, "Starting Neighbor Discovery\n");
        call sendTimer.startPeriodic(5000);
    }

    event void sendTimer.fired(){
        sendPack();
    }

    event message_t* Receiver.receive(message_t* msg, void* payload, uint8_t len) {
        pack* package = (pack*)payload;
        if (package->protocol == PROTOCOL_NEIGHBOR) {
            makePack(&sendReq, TOS_NODE_ID, package->src, MAX_TTL, PROTOCOL_NEIGHBOR, package->seq, neighborPayload, packet);
            call SimpleSend.send(sendReq, sendReq.dest);
            dbg(NEIGHBOR_CHANNEL, "Package returned from %d to %d; Sequence number: %d\n", TOS_NODE_ID, sendReq.dest, sendReq.seq);
        }
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
        uint8_t i = 1;
        while (i <= MAX_NEIGHBORS) {
            makePack(&sendReq, TOS_NODE_ID, i, MAX_TTL, PROTOCOL_NEIGHBOR, sequenceNum, neighborPayload, packet); 
            call SimpleSend.send(sendReq, sendReq.dest);
            dbg(NEIGHBOR_CHANNEL, "Package sent from %d to %d; Sequence number: %d\n", TOS_NODE_ID, i, sequenceNum);
            i++;
        }
        sequenceNum++;
    }
}