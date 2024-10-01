#define MAX_SEQ 20
#define MAX_TTL 40
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
    uint16_t ttl = MAX_TTL;
    uint16_t sequenceNum = 0; // Tracks packets by giving each a unique #, increases whenever a packet is sent
    uint8_t* floodPayload[MAX_PAYLOAD];
    uint8_t i;

    pack sendReq;

    // Store a history of sequence numbers to avoid rebroadcasting the same message
    uint16_t receivedSeq[MAX_SEQ]; // Store sequence numbers of received packets
    uint8_t receivedSeqCount = 0;  // Count of received sequence numbers

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);
    void sendPack();

    command void Flooding.flood(){
        dbg(GENERAL_CHANNEL, "Starting Flood\n");
        call sendTimer.startPeriodic(5000);
    }

    command void Flooding.receivePack(pack *Package){
        dbg(FLOODING_CHANNEL, "Received packet at node: %d, from node: %d, with TTL: %d\n", 
        TOS_NODE_ID, Package->src, Package->TTL);


    }

    event message_t* Receiver.receive(message_t* msg, void* payload, uint8_t len) {
        if (len == sizeof(pack)) {
            pack* package = (pack*)payload; // Correct variable name to package
            dbg(NEIGHBOR_CHANNEL, "Node %d received package from %d; Sequence number: %d\n", TOS_NODE_ID, package->src, package->seq);

            for (i = 0; i < receivedSeqCount; i++) {
                if (receivedSeq[i] == package->seq) { // Use lowercase package
                    dbg(FLOODING_CHANNEL, "Duplicate packet, dropping\n");
                    return msg; // Return the message
                }
            }

            receivedSeq[receivedSeqCount++] = package->seq;
            if (receivedSeqCount >= MAX_SEQ) {
                receivedSeqCount = 0; 
            }

            // Check if the current node is the destination
            if (package->dest == TOS_NODE_ID) {
                dbg(GENERAL_CHANNEL, "Packet received at destination: %d, Payload: %s\n", TOS_NODE_ID, package->payload);
            } else {
                if (package->TTL > 0) {
                    package->TTL--; // Decrease TTL
                    dbg(FLOODING_CHANNEL, "Forwarding packet from node: %d, TTL: %d\n", TOS_NODE_ID, package->TTL);
                    call SimpleSend.send(*package, AM_BROADCAST_ADDR);
                } else {
                    dbg(FLOODING_CHANNEL, "TTL expired, dropping packet\n");
                }
            }
        }
        return msg; // Return the message at the end
    }

    event void sendTimer.fired(){
        sendPack();

    }

    void sendPack(){
        if(sequenceNum < MAX_SEQ){
            makePack(&sendReq, TOS_NODE_ID, 0, MAX_TTL, PROTOCOL_PING, sequenceNum, floodPayload, packet); 
            call SimpleSend.send(sendReq, AM_BROADCAST_ADDR);
            dbg(FLOODING_CHANNEL, "Package sent from: %d,Sequence number: %d\n", TOS_NODE_ID, sequenceNum);
            sequenceNum++;
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