#define MAX_SEQ 25
#define MAX_TTL 25
#define MAX_PAYLOAD 40
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
    uint8_t packetPayloadLen = 0; // Len of payload (current)
    uint16_t ttl = MAX_TTL; // Time value for packets (before destroyed)
    uint16_t seqNumCount = 0; // Tracks packets by giving each a unique #, increases whenever a packet is sent
    uint8_t floodPayload[MAX_PAYLOAD]; // buffer to store payload data
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
    void sendPack();

    // WIP (Look at NeighborDiscoveryP.nc)
    // void updateNeighborList() {
    //     // Variable declarations must end with semicolons
    //     uint8_t attempts = 0;
    //     uint8_t maxAttempts = 5;  // Number of times to check for neighbors
        
    //     // Run discovery until we find neighbors or max attempts reached
    //     while(attempts < maxAttempts) {
    //         call NeighborDiscovery.discoverNeighbors();
    //         neighbors = call NeighborDiscovery.getNeighbors();
    //         numNeighbors = call NeighborDiscovery.getNeighborCount();
            
    //         if(numNeighbors > 0) {
    //             dbg(GENERAL_CHANNEL, "Updated neighbor list. Number of neighbors: %d\n", numNeighbors);
    //             break;  // Exit loop if we found neighbors
    //         }
    //         attempts++;
    //         if(attempts < maxAttempts) {
    //             dbg(GENERAL_CHANNEL, "No neighbors found, attempt %d of %d\n", attempts, maxAttempts);
    //         }
    //     }
    //     if(numNeighbors == 0) {
    //         dbg(GENERAL_CHANNEL, "No neighbors found after %d attempts\n", maxAttempts);
    //     }
    // }

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

                // checks if packet is a duplicate (from recievedSeqCount)
                //  for(i = 0; i < MAX_SEQ; i++) {
                //     if(receivedSeq[i] == package->seq) {
                //         isDuplicate = TRUE;
                //         dbg(FLOODING_CHANNEL, "Dropping.. Duplicate packet\n");
                //         return msg;
                //     }
                // }

                // Store new sequence number in the recieved sequence array 
                // receivedSeq[seqNumCount % MAX_SEQ] = package->seq;
                // seqNumCount++;

                // Debug destination check
                dbg(FLOODING_CHANNEL, "Checking destination - Packet dest: %d, Current node: %d\n", 
                    package->dest, TOS_NODE_ID);

                // Case 1: if package destination is the Node 
                if (package->dest == TOS_NODE_ID) {
                    // uint8_t i;
                    uint8_t j;
                    uint8_t* translatedPayload = (uint8_t*)package->payload;

                    dbg(FLOODING_CHANNEL, "\n>>> Packet received at destination: %d <<<\n", TOS_NODE_ID); // Packet reached

                    dbg(FLOODING_CHANNEL, "Node %d Stores List of Neighbors from floodPayload: ", TOS_NODE_ID);
                    for (i = 0; i < MAX_NEIGHBORS; i++){
                        // Store Neighbor Graph 
                        neighborGraph[package->src][i] = translatedPayload[i];
                        dbg(FLOODING_CHANNEL, "%d\n", translatedPayload[i]);
                    }

                    dbg(FLOODING_CHANNEL, "Neighbor Graph: \n");
                    for (i = 0; i < MAX_NEIGHBORS; i++) {
                        dbg(FLOODING_CHANNEL, "Node %d Neighbors: \n", i);
                        for (j = 0; j < MAX_NEIGHBORS; j++) {
                            dbg(FLOODING_CHANNEL, "%d\n", neighborGraph[i][j]);
                        }
                        dbg(FLOODING_CHANNEL, "\n");
}

                    // if flooding packet then keep flooding
                    if (package->protocol == PROTOCOL_FLOODING && package->TTL > 0) {
                        package->TTL--;
                        dbg(FLOODING_CHANNEL, "Node %d recieved package info from %d; Package sent from: %d\n", TOS_NODE_ID, package->src, package->src);
                        call SimpleSend.send(*package, AM_BROADCAST_ADDR);
                    } 
                } else {
                    // makePack(&packetInfo, TOS_NODE_ID, destination, MAX_TTL, PROTOCOL_FLOODING, seqNumCount, floodPayload, packetPayloadLen); 
                    call SimpleSend.send(*package, AM_BROADCAST_ADDR);
                }

                // Case 2: Broadcast Packet
        //         else if (package->dest == AM_BROADCAST_ADDR) {
        //             dbg(FLOODING_CHANNEL, "Broadcasting packet from node: %d\n", TOS_NODE_ID);

        //             if(package->protocol == PROTOCOL_LINKSTATE) {
        //                 dbg(FLOODING_CHANNEL, "Process LS Info to Node %d\n", TOS_NODE_ID);
        //                 // process LS info
        //             }

        //             // Check TTL expired or not
        //             if (package->TTL > 0) { 
        //                 package->TTL--; 
        //                 dbg(FLOODING_CHANNEL, "Forwarding packet info from node: %d\n\t\t | TTL: %d |\n", TOS_NODE_ID, package->TTL);
        //                 call SimpleSend.send(*package, AM_BROADCAST_ADDR); // Forward to all neighbors
        //             } 
        //             else {
        //                 dbg(FLOODING_CHANNEL, "TTL expired... DROP PACKET\n");
        //             }
        //         }
        //      // Case 3: Next hop
        //         else {
        //             if (package->TTL > 0) {
        //                 // Broadcasting until route table is complete
        //                 uint8_t nextHop = AM_BROADCAST_ADDR; 

        //                 // GET NEXT HOP FROM ROUTING TABLE
        //                 // nextHop = getNextHop(package->dest);

        //                 package->TTL--;
        //                 dbg(FLOODING_CHANNEL, "Routing packet from node: %d to next hop\n\t\t | TTL: %d |\n", 
        //                         TOS_NODE_ID, package->TTL);
        //                     call SimpleSend.send(*package, nextHop); // Forward to next hop
        //             } 
        //             else {
        //                 dbg(FLOODING_CHANNEL, "TTL expired... DROP PACKET\n");
        //             }
        //         }
            }
            return msg;
        }
    }

    event void sendTimer.fired() {
        uint8_t* updatedNeighbors = call NeighborDiscovery.getNeighbors();
        // uint8_t updatedNeighbors[MAX_NEIGHBORS] = {1, 2, 3, 4, 0, 0, 0, 0}; // Test

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
            }
        }
        if (isStable) {
            stabilityCounter++;
            dbg(FLOODING_CHANNEL, "Neighbor List stable for %d cycle(s)\n", stabilityCounter);
        } else {
            dbg(FLOODING_CHANNEL, "Neighbor List unstable. Retrieving updated neighbor list.\n");
            // neighbors = updatedNeighbors;
            for (i = 0; i < MAX_NEIGHBORS; i++) {
                neighbors[i] = updatedNeighbors[i];
            }
            stabilityCounter = 0;

            // Copy each neighbor to floodPayload
            packetPayloadLen = call NeighborDiscovery.getNeighborCount();
            while(neighborIndex < MAX_NEIGHBORS) {
                floodPayload[neighborIndex] = neighbors[neighborIndex];
                neighborGraph[TOS_NODE_ID][neighborIndex] = neighbors[neighborIndex];
                dbg(FLOODING_CHANNEL, "%d -> \n", neighbors[neighborIndex]);
                neighborIndex++;
                // dbg(FLOODING_CHANNEL, "debug check\n");
            }
            dbg(FLOODING_CHANNEL, "Copied Neighbor to floodPayload\n");
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
            while(neighborIndex < packetPayloadLen) {
                dbg(FLOODING_CHANNEL, "%d ", floodPayload[neighborIndex]);
                neighborIndex++;
            }
            dbg(FLOODING_CHANNEL, "]\n");
            
            sendPack();

            // reset floodPayload
            neighborIndex = 0;
            while(neighborIndex < MAX_PAYLOAD) {
                floodPayload[neighborIndex] = 0;
                neighborIndex++;
            }
            dbg(FLOODING_CHANNEL, "DUMPING flood payload AFTER\n");
            packetPayloadLen = 0;
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

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
        Package->src = src; // Link Layer Head
        Package->dest = dest; // Link Layer Head
        Package->TTL = TTL; // Flooding Header
        Package->seq = seq; // Flooding Header
        Package->protocol = protocol; // Flooding Header
        memcpy(Package->payload, payload, length);
    }
}