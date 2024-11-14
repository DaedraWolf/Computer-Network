#define LSA_REFRESH_INTERVAL 10000
#define LSA_MINIMUM_RECEIVED 3

module LinkStateP{
    provides interface LinkState;
    uses interface NeighborDiscovery;
    uses interface Flooding;
    uses interface SimpleSend;
    uses interface Receive as Receiver;
    uses interface Timer<TMilli> as LSATimer;
    uses interface Dijkstra;
}

implementation {
    typedef struct {
        uint16_t nextHop;
        uint16_t cost;
    } destTuple;
    
    // Structure for link state data
    typedef struct {
        uint8_t src;
        uint8_t seqNum;
        uint8_t neighborsNum;
        destTuple neighbors[MAX_NEIGHBORS];
    } LSAPacket; // Link-State advertise packet

    uint8_t seqNum = 0;
    uint16_t ttl = MAX_TTL;
    uint8_t linkStatePayload[MAX_NEIGHBORS];
    uint8_t payloadLength = sizeof(linkStatePayload);
    pack sendReq;

    uint16_t neighborGraph[MAX_NEIGHBORS][MAX_NEIGHBORS];

    uint8_t* tempPayload = ""; // just for testing


    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);
    void initializeLSAPackage();
    bool isNeighborGraphFilled();
    void loadDistanceTable();
    
    command void LinkState.advertise() {
        dbg(GENERAL_CHANNEL, "Initializing Link State Advertise at node %d\n", TOS_NODE_ID);
        initializeLSAPackage();
        call Flooding.flood(0);
        call LSATimer.startPeriodic(LSA_REFRESH_INTERVAL);
    }

    command void LinkState.printRouteTable() {
        uint8_t i;

        for (i = 0; i < MAX_NEIGHBORS; i++) {
            dbg(ROUTING_CHANNEL, "%d -> %d\n", i, call Dijkstra.getNextHop(i));
        }
    }

    // handles recieved LSA packets
    event message_t* Receiver.receive(message_t* msg, void* payload, uint8_t len) {
        if (len == sizeof(pack)) {
            pack* package = (pack*)payload;
            if (package->protocol == PROTOCOL_LINKSTATE) {
                dbg(ROUTING_CHANNEL, "LSA Package Received at Node %d\n", TOS_NODE_ID);
            }
        }
    }

    // periodic timer event for LSA updates
    event void LSATimer.fired() {
        // makePack(&sendReq, TOS_NODE_ID, 0, MAX_TTL, PROTOCOL_LINKSTATE, seqNum, linkStatePayload, payloadLength);
        // call SimpleSend.send(sendReq, AM_BROADCAST_ADDR);
        // seqNum++;
        uint8_t i;
        uint8_t j;

        // tempGraph represents 1D array that represents connectivity between nodes
        uint8_t* tempGraph = call Flooding.getNeighborGraph();
        // dbg(ROUTING_CHANNEL, "Printing Neighbor Graph\n");

        // check if there is enough topology info is available
        for (i = 0; i < MAX_NEIGHBORS; i++) {
            for (j = 0; j < MAX_NEIGHBORS; j++) {
                neighborGraph[i][j] = tempGraph[i * MAX_NEIGHBORS + j];
                // dbg(ROUTING_CHANNEL, "Neighbors[%d][%d] = %d\n", i, j, tempGraph[i * MAX_NEIGHBORS + j]);
            }
        }
        
        // Check if it is available
        if (isNeighborGraphFilled()) {
            dbg(ROUTING_CHANNEL, "Neighbor graph filled; Creating Routing Table\n");
            loadDistanceTable();
        } else {
            dbg(ROUTING_CHANNEL, "Neighbor graph not filled; Waiting until next timer fire\n");
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

    void initializeLSAPackage() {
        // linkStatePayload->src = TOS_NODE_ID;
        // linkStatePayload->seqNum = 0;
        // linkStatePayload->neighborsNum = call NeighborDiscovery.getNeighborCount();
    }

    // void initializeNeighborGraph() {
    //     uint16_t i;
    //     uint16_t j;

    //     for (i = 0; i < MAX_NEIGHBORS; i++) {
    //         for (j = 0; j < MAX_NEIGHBORS; j++) {
    //             routingGraph[i][j] = UINT16_MAX;
    //         }
    //     }
    // }

    // void updateRoutingTable(uint16_t dist[], uint16_t src) {
    //     uint16_t i;
    //     for (i = 0; i < MAX_NEIGHBORS; i++) {
    //         if (i != src && routingTable[i].cost < dist[i] + routing[src].cost) {
    //             routingTable[i].nextHop = src;
    //             routingTable[i].cost = dist[i] + routing[src].cost;
    //         }
    //     }
    // }

    // calculates routing table using dijkstra
    void loadDistanceTable() {
        // run dijkstra algorithm on neighbor graph
        call Dijkstra.make(neighborGraph, TOS_NODE_ID);
        
        // call LinkState.printRouteTable();
    }

    // update neighbor graph with new info
    void updateNeighborGraph(uint16_t neighborTable[], uint16_t src) {
        uint16_t i;

        for (i = 0; i < MAX_NEIGHBORS; i++) {
            if (neighborTable[i] > 0)
                neighborGraph[src][i] = 1; // connection established
            else
                neighborGraph[src][i] = 0; // No connection
        }
    }

    // checks if enough topology info is available
    bool isNeighborGraphFilled() {
        uint8_t i;
        uint8_t j;
        uint8_t receivedCount = 0;

        // counts nodes with at least one neighbor
        for (i = 0; i < MAX_NEIGHBORS; i++) {
            for (j = 0; j < MAX_NEIGHBORS; j++) {
                if (neighborGraph[i][j] != 0) {
                    receivedCount++;
                    break;
                }
            }
        }
        // returns true if at least 5 nodes have neighbors
        return (receivedCount >= LSA_MINIMUM_RECEIVED);
    }
}