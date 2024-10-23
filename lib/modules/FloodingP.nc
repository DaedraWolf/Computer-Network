#define MAX_SEQ 25
#define MAX_TTL 25
#define MIN_STABLE_NEIGHBOR_TIME 5
#define MAX_NEIGHBORS 20

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
    uint16_t ttl = MAX_TTL; // Time value for packets (before destroyed)
    uint16_t seqNumCount = 0; // Tracks packets by giving each a unique #, increases whenever a packet is sent
    uint8_t floodPayload[MAX_NEIGHBORS]; // buffer to store payload data
    uint8_t packetPayloadLen = sizeof(floodPayload); // Len of payload (current)
    uint8_t seqIndex;   // Iterate through seq number's
    uint16_t destination;
    uint8_t neighborGraph[MAX_NEIGHBORS][MAX_NEIGHBORS];

    // Array to store a list of sequence #'s of recieved packets (duplication)
    uint16_t receivedSeq[MAX_SEQ]; // Store sequence numbers of received packets
    // uint8_t recievedSeqCount = 0;  // # of seq num stored in array

    uint8_t stabilityCounter = 0;
    uint8_t neighbors[MAX_NEIGHBORS];
    uint8_t numNeighbors;


    pack packetInfo;   // holds packet infomation
      
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);
    void sendReply(uint16_t dest, uint16_t seq);
    void sendPack();

    // Start flooding process
    command void Flooding.flood(uint16_t dest){
        destination = dest;
        dbg(GENERAL_CHANNEL, "Starting Flood\n");
        call sendTimer.startPeriodic(5000);
        call NeighborDiscovery.discoverNeighbors();
    }

    // handle a recieved packet
    command void Flooding.receivePack(pack *Package){
        dbg(FLOODING_CHANNEL, "Received packet at node: %d, from node: %d\n\t\t | TTL: %d |\n", 
        TOS_NODE_ID, Package->src, Package->TTL); // prints debug info about recieved packet
    }

    command uint8_t* Flooding.getNeighborGraph() {
        return (uint8_t*) neighborGraph;
    }

    // event starts when packet is recieved
    event message_t* Receiver.receive(message_t* msg, void* payload, uint8_t len) {
        // checks len of packet size
        if (len == sizeof(pack)) {
            // payload is now in a 'pack' struct
            pack* package = (pack*)payload;

            if (package->protocol == PROTOCOL_FLOODING) {
                uint8_t i;
                bool isDuplicate = FALSE;
                
                dbg(FLOODING_CHANNEL, "Node %d received package info from %d; SEQUENCE NUMBER: %d\n", TOS_NODE_ID, package->src, package->src);

                dbg(FLOODING_CHANNEL, "Checking destination - Packet dest: %d, Current node: %d\n", package->dest, TOS_NODE_ID);

                if (package->dest == TOS_NODE_ID || package->dest == 0) {
                    uint8_t j;

                    dbg(FLOODING_CHANNEL, "\n>>> Packet received at destination: %d <<<\n", TOS_NODE_ID); // Packet reached

                    dbg(FLOODING_CHANNEL, "Node %d Stores List of Neighbors from floodPayload:\n", TOS_NODE_ID);
                    for (i = 0; i < MAX_NEIGHBORS; i++){
                        // Store Neighbor Graph 
                        neighborGraph[package->src][i] = package->payload[i];
                        dbg(FLOODING_CHANNEL, "%d\n", package->payload[i]);
                    }

                    dbg(FLOODING_CHANNEL, "Neighbor Graph: \n");
                    for (i = 0; i < MAX_NEIGHBORS; i++) {
                        dbg(FLOODING_CHANNEL, "Node %d Neighbors: \n", i);
                        for (j = 0; j < MAX_NEIGHBORS; j++) {
                            dbg(FLOODING_CHANNEL, "%d\n", neighborGraph[i][j]);
                        }
                        dbg(FLOODING_CHANNEL, "\n");
                    }

                    if (package->dest == 0)
                        call SimpleSend.send(*package, AM_BROADCAST_ADDR);

                    sendReply(package->src, package->seq);

                    // if flooding packet then keep flooding
                    // if (package->protocol == PROTOCOL_FLOODING && package->TTL > 0) {
                    //     package->TTL--;
                    //     dbg(FLOODING_CHANNEL, "Node %d recieved package info from %d; Package sent from: %d\n", TOS_NODE_ID, package->src, package->src);
                    //     call SimpleSend.send(*package, AM_BROADCAST_ADDR);
                    // } 
                } else {
                    call SimpleSend.send(*package, AM_BROADCAST_ADDR);
                }
            }
            if (package->protocol == PROTOCOL_FLOODINGREPLY) {
                if (package->dest == TOS_NODE_ID) {
                    uint8_t i;
                    uint8_t j;

                    for (i = 0; i < MAX_NEIGHBORS; i++){
                        // Store Neighbor Graph 
                        neighborGraph[package->src][i] = package->payload[i];
                        dbg(FLOODING_CHANNEL, "%d\n", package->payload[i]);
                    }

                    dbg(FLOODING_CHANNEL, "Flooding Reply Received; Printing Neighbor Graph: \n");
                    for (i = 0; i < MAX_NEIGHBORS; i++) {
                        dbg(FLOODING_CHANNEL, "Node %d Neighbors: \n", i);
                        for (j = 0; j < MAX_NEIGHBORS; j++) {
                            dbg(FLOODING_CHANNEL, "%d\n", neighborGraph[i][j]);
                        }
                        dbg(FLOODING_CHANNEL, "\n");
                    }
                } else {
                    call SimpleSend.send(*package, AM_BROADCAST_ADDR);
                }
            }
            return msg;
        }
    }

    event void sendTimer.fired() {
        uint8_t* updatedNeighbors = call NeighborDiscovery.getNeighbors();

        uint8_t neighborIndex = 0;
        uint8_t graphIndex = 0;
        uint8_t i;
        bool isStable = TRUE;

        // debug check neighbor list
        dbg(FLOODING_CHANNEL, "Updated Neighbor List: ");
        for (i = 0; i < MAX_NEIGHBORS; i++) {
            dbg(FLOODING_CHANNEL, "%d\n ", neighbors[i]);
        }
        dbg(FLOODING_CHANNEL, "\n");

        for (i = 0; i < MAX_NEIGHBORS; i++){
            if (neighbors[i] != updatedNeighbors[i]) {
                isStable = FALSE; // mismatch
                break;
            }
        }
        if (isStable) {
            if (stabilityCounter == 0) {
                dbg(FLOODING_CHANNEL, "Copying Neighbor array to floodPayload\n");
                for (i = 0; i < MAX_NEIGHBORS; i++) {
                    floodPayload[i] = neighbors[i];
                    neighborGraph[TOS_NODE_ID][i] = neighbors[i];
                    dbg(FLOODING_CHANNEL, "%d -> \n", floodPayload[i]);
                }
            }
            stabilityCounter++;
            dbg(FLOODING_CHANNEL, "Neighbor List stable for %d cycle(s)\n", stabilityCounter);
        } else {
            dbg(FLOODING_CHANNEL, "Neighbor List unstable. Retrieving updated neighbor list.\n");
            for (i = 0; i < MAX_NEIGHBORS; i++) {
                neighbors[i] = updatedNeighbors[i];
            }
            stabilityCounter = 0;
        }
        
        if (stabilityCounter >= MIN_STABLE_NEIGHBOR_TIME) {
            neighborIndex = 0;  // Reset index for printing
            dbg(FLOODING_CHANNEL, "PRINTING LIST OF ND: \n");
            while (neighborIndex < MAX_NEIGHBORS) {
                dbg(FLOODING_CHANNEL, "%d -> \n", neighborGraph[TOS_NODE_ID][neighborIndex]);
                neighborIndex++;
            }

            neighborIndex = 0;
            dbg(FLOODING_CHANNEL, "Node %d sending flood with payload: [ ", TOS_NODE_ID);
            while(neighborIndex < MAX_NEIGHBORS) {
                dbg(FLOODING_CHANNEL, "%d ", floodPayload[neighborIndex]);
                neighborIndex++;
            }
            dbg(FLOODING_CHANNEL, "]\n");
            
            sendPack();

            // reset floodPayload
            neighborIndex = 0;
            while(neighborIndex < MAX_NEIGHBORS) {
                floodPayload[neighborIndex] = 0;
                neighborIndex++;
            }
            dbg(FLOODING_CHANNEL, "DUMPING flood payload AFTER\n");
            // packetPayloadLen = 0;
        }
    }

    void sendPack(){
        if(seqNumCount < MAX_SEQ){ // seq number doesn't exceed limit [20]
            makePack(&packetInfo, TOS_NODE_ID, destination, MAX_TTL, PROTOCOL_FLOODING, seqNumCount, floodPayload, packetPayloadLen); 
            call SimpleSend.send(packetInfo, AM_BROADCAST_ADDR); // Broadcast packet
            dbg(FLOODING_CHANNEL, " NEW Package sent from: %d,\n\t *****(Sequence number: %d)*****\n", TOS_NODE_ID, seqNumCount);
            seqNumCount++;  // Increment seqNum for next packet
        }
    }

    void sendReply(uint16_t dest, uint16_t seq){
        dbg(FLOODING_CHANNEL, "Sending flooding reply to %d\n", dest);
        makePack(&packetInfo, TOS_NODE_ID, dest, MAX_TTL, PROTOCOL_FLOODINGREPLY, seq, floodPayload, packetPayloadLen); 
        call SimpleSend.send(packetInfo, AM_BROADCAST_ADDR);
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