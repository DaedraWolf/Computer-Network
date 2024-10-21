interface Dijkstra<>{
    command void initialize(uint16_t g[vertices][vertices]);
    command uint16_t* getShortestPaths(uint16_t src);
}