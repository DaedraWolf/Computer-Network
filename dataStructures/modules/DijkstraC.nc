#include "../../includes/channels.h"
generic module DijkstraC(uint16_t vert){
   provides interface Dijkstra;
}

implementation{
    uint16_t vertices = MAX_NEIGHBORS;
    uint16_t graph[][];

    uint16_t minDistance(uint16_t dist[], bool sptSet[]);

    command void Dijkstra.initialize(uint16_t g[MAX_NEIGHBORS][MAX_NEIGHBORS]) {
        uint16_t i;
        uint16_t j;

        for (i = 0; i < vertices; i++) {
            for (j = 0; j < vertices; j++) {
                graph[i][j] = g[i][j];
            }
        }
    }

    command uint16_t* Dijkstra.getShortestPaths(uint16_t src) {
        uint16_t i;
        uint16_t v;
        uint16_t count;
        uint16_t dist[vertices];
        bool sptSet[vertices];
        
        for (i = 0; i < vertices; i++) {
            dist[i] = UINT16_MAX;
            sptSet[i] = 0;
        }

        dist[src] = 0;

        for (count = 0; count < vertices - 1; count++) {
            int u = minDistance(dist, sptSet);
            sptSet[u] = 1;
            for (v = 0; v < vertices; v++)
                if (!sptSet[v] && graph[u][v]
                    && dist[u] != UINT16_MAX
                    && dist[u] + graph[u][v] < dist[v])
                    dist[v] = dist[u] + graph[u][v];
        }

        return dist;
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