interface Flooding {
    command void flood(uint16_t dest);
    command void receivePack(pack *Package);
    command uint8_t* getNeighborGraph();
    // command void updateNeighborList();
}