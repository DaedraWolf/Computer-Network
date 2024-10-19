interface Flooding {
    command void flood(uint16_t dest);
    command void receivePack(pack *Package);
    // command void updateNeighborList();
}