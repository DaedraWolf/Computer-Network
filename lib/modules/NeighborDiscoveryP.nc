#define MAX_NEIGHBORS 20

#include "../../includes/channels.h"

module NeighborDiscoveryP{
    provides interface NeighborDiscovery;
    uses interface SimpleSend;
    uses interface Timer<TMilli> as sendTimer;
    uses interface Receive as Receiver;
    uses interface Hashmap<uint8_t>; //key = node #, value = sequenceNum at time of last neighbor discovery ping
}

implementation{
    uint8_t i;
    uint8_t packet = 0;
    uint16_t ttl = MAX_TTL;
    uint16_t sequenceNum = 0; // Tracks packets by giving each a unique #, increases whenever a packet is sent
    uint8_t* neighborPayload = "";
    pack sendReq;
    uint32_t neighbors[MAX_NEIGHBORS];
    uint16_t neighborCount = 0;

    /* NOT IMPLEMENTED
    command uint32_t* NeighborDiscovery.getNeighbors() { 
        return neighbors;
    }

    command uint16_t NeighborDiscovery.getNeighborCount() {
        return neighborCount;
    }
    */
    // To-Do
    // function that deletes any disconnected neighbors from hashmap

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);
    void sendPack();
    void printNeighbors();

    command void NeighborDiscovery.discoverNeighbors(){
        dbg(GENERAL_CHANNEL, "Starting Neighbor Discovery\n");
        call sendTimer.startPeriodic(5000);
    }

    event void sendTimer.fired(){
        sendPack();
        printNeighbors();
    }

    event message_t* Receiver.receive(message_t* msg, void* payload, uint8_t len) {
        if (len == sizeof(pack)) {
            pack* package = (pack*)payload;
            if (package->protocol == PROTOCOL_NEIGHBOR) {
                dbg(NEIGHBOR_CHANNEL, "Node %d received package from %d; Sequence number: %d\n", TOS_NODE_ID, package->src, package->seq);
                call Hashmap.insert(package->src, sequenceNum);
            }
            // if (package->protocol == PROTOCOL_NEIGHBOR) {
            //     if (package->payload == TOS_NODE_ID) {
            //         dbg(NEIGHBOR_CHANNEL, "Package returned to %d by %d; Sequence number: %d\n", TOS_NODE_ID, sendReq.dest, sendReq.seq);
            //     } else {
            //         makePack(&sendReq, TOS_NODE_ID, package->src, MAX_TTL, PROTOCOL_NEIGHBOR, package->seq, neighborPayload, packet);
            //         call SimpleSend.send(sendReq, sendReq.dest);
            //         dbg(NEIGHBOR_CHANNEL, "Returning package to %d from %d; Sequence number: %d\n", sendReq.dest, TOS_NODE_ID, sendReq.seq);
            //     }
            // }
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
        makePack(&sendReq, TOS_NODE_ID, 0, MAX_TTL, PROTOCOL_NEIGHBOR, sequenceNum, neighborPayload, packet); 
        call SimpleSend.send(sendReq, AM_BROADCAST_ADDR);
        dbg(NEIGHBOR_CHANNEL, "Node %d broadcasting package; Sequence number: %d\n", TOS_NODE_ID, sequenceNum);
        sequenceNum++;
    }

    void printNeighbors() {
        dbg(NEIGHBOR_CHANNEL, "Printing Neighbors of Node %d:\n", TOS_NODE_ID);
        for (i = 0; i < MAX_NEIGHBORS; i++) {
            uint8_t lastPing = call Hashmap.get(i);
            uint8_t age = sequenceNum - lastPing;
            if (age <= 5) {
                dbg(NEIGHBOR_CHANNEL, "%d; Time since last ping: %d\n", i, age);
            }
        }
    }
}