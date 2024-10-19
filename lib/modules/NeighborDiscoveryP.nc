#define MAX_NEIGHBORS 20
#define WINDOW_SIZE 5

#include "../../includes/channels.h"

module NeighborDiscoveryP{
    provides interface NeighborDiscovery;
    uses interface SimpleSend;
    uses interface Timer<TMilli> as sendTimer;
    uses interface Receive as Receiver;
    uses interface Hashmap<Array8_t>; //key = node #, value = sequenceNum at time of last neighbor discovery ping
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

    // NOT IMPLEMENTED
    command uint32_t* NeighborDiscovery.getNeighbors() { 
        return neighbors;
    }

    command uint16_t NeighborDiscovery.getNeighborCount() {
        return neighborCount;
    }

    // To-Do
    // function that deletes any disconnected neighbors from hashmap

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);
    void sendPack();
    void printNeighbors();
    void updateNeighbor(uint16_t node, bool value);
    uint16_t getConnectionStrength(uint16_t node);
    void printConnectionStrength(uint16_t node);
    void initializeNeighborMap();

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
                dbg(NEIGHBOR_CHANNEL, "Node %d received neighbor discovery request from %d; Sequence number: %d\n", TOS_NODE_ID, package->src, package->seq);
                makePack(&sendReq, TOS_NODE_ID, package->src, MAX_TTL, PROTOCOL_NEIGHBORREPLY, package->seq, neighborPayload, packet);
                call SimpleSend.send(sendReq, sendReq.dest);
                dbg(NEIGHBOR_CHANNEL, "Node %d sending acknowledgement to %d; Sequence number: %d\n", TOS_NODE_ID, package->src, package->seq);
            }
            if (package->protocol == PROTOCOL_NEIGHBORREPLY) {
                dbg(NEIGHBOR_CHANNEL, "Node %d received acknowledgement from %d; Sequence number: %d\n", TOS_NODE_ID, package->src, package->seq);
                updateNeighbor(package->src, 1);
            }
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
            uint16_t conStr = getConnectionStrength(i);
            if (conStr > 0) {
                dbg(NEIGHBOR_CHANNEL, "%d -> %d; Connection strength: %d\n", TOS_NODE_ID, i, conStr);
            }
        }
    }

    void updateNeighbor(uint16_t node, bool value) {
        Array8_t v = call Hashmap.get(node);
        for (i = v.lastSequence+1; i < sequenceNum; i++) {
            v.data[i%WINDOW_SIZE] = 0;
        }
        v.data[sequenceNum % WINDOW_SIZE] = value;
        v.lastSequence = sequenceNum;
        call Hashmap.insert(node, v);
    }

    uint16_t getConnectionStrength(uint16_t node) {
        Array8_t v = call Hashmap.get(node);
        uint16_t sum = 0;
        for (i = 0; i < WINDOW_SIZE; i++) {
            sum += v.data[i];
        }
        return sum;
    }

    void printConnectionStrength(uint16_t node) {
        dbg(NEIGHBOR_CHANNEL, "%d -> %d; Connection strength: %d\n", TOS_NODE_ID, node, getConnectionStrength(node));
    }
}