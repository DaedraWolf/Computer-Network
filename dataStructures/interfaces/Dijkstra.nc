interface Dijkstra{
    command void initialize(uint16_t g[MAX_NEIGHBORS][MAX_NEIGHBORS]);
    command uint16_t* getShortestPaths(uint16_t src);
}