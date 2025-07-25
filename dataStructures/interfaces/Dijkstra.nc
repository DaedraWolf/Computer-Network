interface Dijkstra{
    command void make(uint16_t graph[MAX_NEIGHBORS][MAX_NEIGHBORS], uint16_t src);
    command uint16_t getNextHop(uint16_t dest);
}