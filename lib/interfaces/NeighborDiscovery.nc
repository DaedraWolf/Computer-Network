interface NeighborDiscovery {
    command void discoverNeighbors();
    // Created for neighbor information when flooding
    command uint8_t* getNeighbors();
    command uint8_t getNeighborCount();
}