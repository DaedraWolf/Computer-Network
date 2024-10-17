interface Flooding {
    command void flood();
    command void receivePack(pack *Package);
    command void updateNeighborList();
}