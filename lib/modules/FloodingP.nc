#define MAX_SEQ 20
#define MAX_TTL 25
#define MAX_PAYLOAD 40

#include "../../includes/channels.h"

module FloodingP{
    provides interface Flooding;
    uses interface SimpleSend;
    uses interface Timer<TMilli> as sendTimer;
    uses interface Receive as Receiver;
    uses interface NeighborDiscovery;
    uses interface Hashmap<uint8_t> as NeighborMap;
}

implementation{
    uint8_t packetPayloadLen = 0; // Len of payload (current)
    uint16_t ttl = MAX_TTL; // Time value for packets (before destroyed)
    uint16_t seqNumCount = 0; // Tracks packets by giving each a unique #, increases whenever a packet is sent
    uint8_t* floodPayload[MAX_PAYLOAD]; // buffer to store payload data
    uint8_t seqIndex;   // Iterate through seq number's
    uint16_t destination;

    // Array to store a list of sequence #'s of recieved packets (duplication)
    uint16_t receivedSeq[MAX_SEQ]; // Store sequence numbers of received packets
    uint8_t recievedSeqCount = 0;  // # of seq num stored in array

    pack packetInfo;   // holds packet infomation
      
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);
    void sendPack();

    // NOT IMPLEMENTED YET (Look at NeighborDiscoveryP.nc)
    void updateNeighborList() {
        // This will be called periodically to update the neighbor list
        uint8_t* neighbors = call NeighborDiscovery.getNeighbors();
        uint8_t numNeighbors = call NeighborDiscovery.getNeighborCount();
        
        // Use these neighbors in your flooding algorithm
        // For example, you might store them in a local array or use them directly
        dbg(GENERAL_CHANNEL, "Updated neighbor list. Number of neighbors: %d\n", numNeighbors);
    }

    // Start flooding process
    command void Flooding.flood(uint16_t dest){
        destination = dest;
        dbg(GENERAL_CHANNEL, "Starting Flood\n");
        call sendTimer.startPeriodic(5000);
        call sendTimer.startPeriodic(10000);
    }

    // handle a recieved packet
    command void Flooding.receivePack(pack *Package){
        dbg(FLOODING_CHANNEL, "Received packet at node: %d, from node: %d\n\t\t | TTL: %d |\n", 
        TOS_NODE_ID, Package->src, Package->TTL); // prints debug info about recieved packet
    }

    // event starts when packet is recieved
    event message_t* Receiver.receive(message_t* msg, void* payload, uint8_t len) {
        // checks len of packet size
        if (len == sizeof(pack)) {

            // payload is inow in a 'pack' struct
            pack* package = (pack*)payload;

            if (package->protocol == PROTOCOL_FLOODING) {
                dbg(FLOODING_CHANNEL, "Node %d received package info from %d; SEQUENCE NUMBER: %d\n", TOS_NODE_ID, package->src, package->src);

                // checks if packet is a duplicate (from recievedSeqCount)
                while (seqIndex < recievedSeqCount) {
                    if (receivedSeq[seqIndex] == package->seq) { // Checks for duplicates
                        dbg(FLOODING_CHANNEL, "Dropping.. Duplicate packet\n");
                        return msg; 
                    }
                    seqIndex++;
                }

                // Store new sequence number in the recieved sequence array 
                receivedSeq[recievedSeqCount++] = package->seq;
                if (recievedSeqCount >= MAX_SEQ) {
                    recievedSeqCount = 0; 
                }

                // Case 1: if package destination is the Node 
                if (package->dest == TOS_NODE_ID) {
                    dbg(FLOODING_CHANNEL, "\n>>> Packet received at destination: %d <<<\n", TOS_NODE_ID); // Packet reached

                    // if flooding packet then keep flooding
                    if (package->protocol == PROTOCOL_FLOODING && package->TTL > 0) {
                        package->TTL--;
                        dbg(FLOODING_CHANNEL, "Node %d recieved package info from %d; Package sent from: %d\n", TOS_NODE_ID, package->src, package->src);
                        call SimpleSend.send(*package, AM_BROADCAST_ADDR);
                    } 
                        // Link state info processed & handled locally
                    else if (package->protocol == PROTOCOL_LINKSTATE) {
                        dbg(FLOODING_CHANNEL, "LINK STATE PACKET reached at node %d\n", TOS_NODE_ID);
                    }
                }

                // Case 2: Broadcast Packet
                else if (package->dest == AM_BROADCAST_ADDR) {
                    dbg(FLOODING_CHANNEL, "Broadcasting packet from node: %d\n", TOS_NODE_ID);

                    if(package->protocol == PROTOCOL_LINKSTATE) {
                        dbg(FLOODING_CHANNEL, "Process LS Info to Node %d\n", TOS_NODE_ID);
                        // process LS info
                    }

                    // Check TTL expired or not
                    if (package->TTL > 0) { 
                        package->TTL--; 
                        dbg(FLOODING_CHANNEL, "Forwarding packet info from node: %d\n\t\t | TTL: %d |\n", TOS_NODE_ID, package->TTL);
                        call SimpleSend.send(*package, AM_BROADCAST_ADDR); // Forward to all neighbors
                    } 
                    else {
                        dbg(FLOODING_CHANNEL, "TTL expired... DROP PACKET\n");
                    }
                }
                else {
                    if (package->TTL > 0) {
                        // Broadcasting until route table is complete
                        uint8_t nextHop = AM_BROADCAST_ADDR; 

                        // GET NEXT HOP FROM ROUTING TABLE
                        // nextHop = getNextHop(package->dest);

                        package->TTL--;
                        dbg(FLOODING_CHANNEL, "Routing packet from node: %d to next hop\n\t\t | TTL: %d |\n", 
                                TOS_NODE_ID, package->TTL);
                            call SimpleSend.send(*package, nextHop); // Forward to next hop
                    } 
                    else {
                        dbg(FLOODING_CHANNEL, "TTL expired... DROP PACKET\n");
                    }
                }
            }
            return msg;
        }
    }

    event void sendTimer.fired(){
        sendPack(); // Send new packet
        updateNeighborList();

    }

    void sendPack(){
        if(seqNumCount < MAX_SEQ){ // seq number doesn't exceed limit [20]
            makePack(&packetInfo, TOS_NODE_ID, destination, MAX_TTL, PROTOCOL_FLOODING, seqNumCount, floodPayload, packetPayloadLen); 
            call SimpleSend.send(packetInfo, AM_BROADCAST_ADDR); // Broadcast packet
            dbg(FLOODING_CHANNEL, " NEW Package sent from: %d,\n\t *****(Sequence number: %d)*****\n", TOS_NODE_ID, seqNumCount);
            seqNumCount++;  // Increment seqNum for next packet
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