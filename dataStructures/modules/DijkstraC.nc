#include "../../includes/channels.h"
generic module Dijkstra(int vertices){
   provides interface Dijkstra<>;
}

implementation{
    uint16_t graph[vertices][vertices];

    uint16_t minDistance(uint16_t dist[], bool sptSet[]);

    command void initialize(uint16_t g[vertices][vertices]) {
        graph = g;
    }

    command uint16_t* getShortestPaths(uint16_t src) {
        uint16_t i;
        uint16_t v;
        uint16_t count;
        uint16_t dist[vertices];
        bool sptSet[vertices];
        
        for (i = 0; i < V; i++)
            dist[i] = INT_MAX, sptSet[i] = false;

        dist[src] = 0;

        for (count = 0; count < V - 1; count++) {
            int u = minDistance(dist, sptSet);
            sptSet[u] = true;
            for (v = 0; v < V; v++)
                if (!sptSet[v] && graph[u][v]
                    && dist[u] != INT_MAX
                    && dist[u] + graph[u][v] < dist[v])
                    dist[v] = dist[u] + graph[u][v];
        }

        return dist;
    }

    uint16_t minDistance(uint16_t dist[], bool sptSet[]) {
        uint8_t v = 0;
        int min = UINT16_MAX, min_index;

        for (v = 0; v < vertices; v++)
            if (sptSet[v] == false && dist[v] <= min)
                min = dist[v], min_index = v;

        return min_index;
    }
}