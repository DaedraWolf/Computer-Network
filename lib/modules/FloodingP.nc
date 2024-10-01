#define MAX_SEQ 20
#define MAX_TTL 25
#define MAX_PAYLOAD 40

#include "../../includes/channels.h"

module FloodingP{
    provides interface Flooding;
    uses interface SimpleSend;
    uses interface Timer<TMilli> as sendTimer;
    uses interface Receive as Receiver;
}

implementation{
    uint8_t packet = 0;
    uint16_t ttl = MAX_TTL; // Hop
    uint16_t seqTracker = 0; // Tracks packets by giving each a unique #, increases whenever a packet is sent
    uint8_t* floodPayload[MAX_PAYLOAD];
    uint8_t i;
    // Store a list of sequence #'s
    uint16_t receivedSeq[MAX_SEQ]; // Store sequence numbers of received packets
    uint8_t seqCount = 0;  // Count of received sequence numbers

    pack sendReq;
      
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);
    void sendPack();

    command void Flooding.flood(){
        dbg(GENERAL_CHANNEL, "Starting Flood\n");
        call sendTimer.startPeriodic(5000);
    }

    command void Flooding.receivePack(pack *Package){
        dbg(FLOODING_CHANNEL, "Received packet at node: %d, from node: %d\n\t\t | TTL: %d |\n", 
        TOS_NODE_ID, Package->src, Package->TTL);
    }

    event message_t* Receiver.receive(message_t* msg, void* payload, uint8_t len) {
        if (len == sizeof(pack)) {
            pack* package = (pack*)payload;
            dbg(NEIGHBOR_CHANNEL, "Node %d received package info from %d; SEQUENCE NUMBER: %d\n", TOS_NODE_ID, package->src, package->seq);

            while (i < seqCount) {
                if (receivedSeq[i] == package->seq) { // Checks for duplicates
                    dbg(FLOODING_CHANNEL, "Dropping.. Duplicate packet\n");
                    return msg; 
                }
                i++;
            }

            receivedSeq[seqCount++] = package->seq;
            if (seqCount >= MAX_SEQ) {
                seqCount = 0; 
            }

            // Check if the current node is the destination otherwise
            if (package->dest == TOS_NODE_ID) {
                dbg(GENERAL_CHANNEL, "Packet received at destination: %d\n", TOS_NODE_ID, package->payload); //Flooding prevents nodes from discovering
            } else {
                if (package->TTL >= 0) {
                    package->TTL--;
                    dbg(FLOODING_CHANNEL, "Forwarding packet info from node: %d\n\t\t | TTL: %d |\n", TOS_NODE_ID, package->TTL);
                    call SimpleSend.send(*package, AM_BROADCAST_ADDR);
                } else {
                    dbg(FLOODING_CHANNEL, "TTL expired... DROP PACKET\n");
                }
            }
        }
        return msg; 
    }

    event void sendTimer.fired(){
        sendPack();

    }

    void sendPack(){
        if(seqTracker < MAX_SEQ){
            makePack(&sendReq, TOS_NODE_ID, 0, MAX_TTL, PROTOCOL_PING, seqTracker, floodPayload, packet); 
            call SimpleSend.send(sendReq, AM_BROADCAST_ADDR);
            dbg(FLOODING_CHANNEL, "Package sent from: %d,\n\t (Sequence number: %d)\n", TOS_NODE_ID, seqTracker);
            seqTracker++;
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
}