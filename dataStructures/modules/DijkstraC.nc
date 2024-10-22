#include "../../includes/channels.h"

generic module DijkstraC(){
   provides interface Dijkstra;
}

implementation{
    typedef struct {
        uint16_t nextHop;
        uint16_t cost;
    } destTuple;

    uint16_t vertices = MAX_NEIGHBORS;
    destTuple destination[MAX_NEIGHBORS];

    uint16_t minDistance(uint16_t dist[], bool sptSet[]);
    uint16_t getNextHop(uint16_t dest);

    command void Dijkstra.make(uint16_t graph[MAX_NEIGHBORS][MAX_NEIGHBORS], uint16_t src) {
        uint16_t i;
        uint16_t v;
        uint16_t count;
        uint16_t dist[vertices];
        uint16_t prev[vertices];
        bool sptSet[vertices];
        
        for (i = 0; i < vertices; i++) {
            dist[i] = UINT16_MAX;
            prev[i] = src;
            sptSet[i] = 0;
        }

        dist[src] = 0;

        for (count = 0; count < vertices - 1; count++) {
            int u = minDistance(dist, sptSet);
            sptSet[u] = 1;
            for (v = 0; v < vertices; v++)
                if (!sptSet[v] && graph[u][v]
                    && dist[u] != UINT16_MAX
                    && dist[u] + graph[u][v] < dist[v]) {
                        dist[v] = dist[u] + graph[u][v];
                        prev[v] = u;
                    }
        }
        
        for (i = 0; i < vertices; i++) {
            destination[i].nextHop = prev[i];
            destination[i].cost = dist[i];
        }
    }

    command uint16_t Dijkstra.getNextHop(uint16_t dest) {
        return destination[dest].nextHop;
    }

    uint16_t minDistance(uint16_t dist[], bool sptSet[]) {
        uint8_t v = 0;
        uint16_t min_index = 0;
        uint16_t min = UINT16_MAX;

        for (v = 0; v < vertices; v++)
            if (!sptSet[v] && dist[v] <= min)
                min = dist[v], min_index = v;

        return min_index;
    }
}