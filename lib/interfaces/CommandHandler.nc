#include "../../includes/socket.h"

interface CommandHandler{
   // Events
   event void ping(uint16_t destination, uint8_t *payload);
   event void printNeighbors();
   event void printRouteTable();
   event void printLinkState();
   event void printDistanceVector();
   event void setTestServer();
   event void setTestClient();
   event void setAppServer();
   event void setAppClient();
   
   // New Additions
   event void flood(uint16_t dest);
   event void discoverNeighbors();
   event void linkStateAdvertise();
   event void linkStatePing(uint16_t dest);

   event void serverStart(uint8_t port);
   event void clientStart(uint16_t dest, uint8_t srcPort, uint8_t destPort);
   event void send(uint16_t dest, enum msg_type type, uint8_t* msg);
}
