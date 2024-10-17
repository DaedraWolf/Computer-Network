interface NeighborDiscovery {
    command void discoverNeighbors();
    // Created for neighbor information when flooding
    command uint32_t* getNeighbors();
    command uint16_t getNeighborCount();
}