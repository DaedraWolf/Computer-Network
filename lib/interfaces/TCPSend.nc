#include "../../includes/socket.h"

interface TCPSend{
    command void startConnection(uint16_t dest, socket_port_t srcPort);
    command void send(uint16_t dest);
}