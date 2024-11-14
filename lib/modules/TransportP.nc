#define MAX_NUM_OF_SOCKETS 1
#define NULL_SOCKET 255

#include "../../includes/socket.h"

module TransportP{
    provides interface Transport;
    uses interface SimpleSend;
    uses interface Receive as Receiver;
    uses interface Timer<TMilli> as sendTimer;
    uses interface LinkState;
}

implementation{
    // Manage multiple sockets 
    socket_store_t sockets[MAX_NUM_OF_SOCKETS];
    uint16_t destination;

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);

    command socket_t Transport.socket(){
        uint16_t i;
        for(i = 0; i < MAX_NUM_OF_SOCKETS; i++){
            if (sockets[i].state == CLOSED){
                // listen state
                sockets[i].state = LISTEN;
                dbg(TRANSPORT_CHANNEL, "Socket allocated with ID: %d\n", i);
                return i; // Return socket ID
            }
        }
        dbg(TRANSPORT_CHANNEL, "No sockets available\n");
        return NULL_SOCKET; // No Sockets available
    }

    command error_t Transport.bind(socket_t fd, socket_addr_t *addr){

        if (sockets[fd].state == LISTEN){

            addr->addr = TOS_NODE_ID;
            sockets[fd].src = 80; 
            addr->port = 80;
            dbg(TRANSPORT_CHANNEL, "Socket binds to address %d, port %d\n", TOS_NODE_ID, addr->port);
            return SUCCESS; // Able to bind
        }
        dbg(TRANSPORT_CHANNEL, "Unable to bind\n");
        return FAIL; // Unable to bind
    }

    command socket_t Transport.accept(socket_t fd){
        if (sockets[fd].state == LISTEN) {
            // Check if SYN packet is ready to accept
            if (sockets[fd].state == SYN_RCVD){
                // ESTABLISHED transition 
                sockets[fd].state = ESTABLISHED; 
                dbg(TRANSPORT_CHANNEL, "Socket %d accepted connection from %d\n", fd, sockets[fd].dest.addr);
                return fd;
            }
        }
        dbg(TRANSPORT_CHANNEL, "Socket %d cannot accept connection (no SYN recieved\n", fd);
        return NULL_SOCKET;
    }

    command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen){
        return 0;
    }

    command error_t Transport.receive(pack* package){
        return 0;
    }

    command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen){
        return 0;
    }

    command error_t Transport.connect(socket_t fd, socket_addr_t * addr){
        return 0;
    }

    command error_t Transport.close(socket_t fd){
        socket_store_t *currentSocket;

        if (fd >= MAX_NUM_OF_SOCKETS || fd < 0)
            return FAIL;

        currentSocket = &sockets[fd];

        if (currentSocket->state == CLOSED)
            return SUCCESS;
        
        currentSocket->state = CLOSED;

        memset(currentSocket->sendBuff, 0, SOCKET_BUFFER_SIZE);
        memset(currentSocket->rcvdBuff, 0, SOCKET_BUFFER_SIZE);

        currentSocket->lastWritten = 0;
        currentSocket->lastAck = 0;
        currentSocket->lastSent = 0;
        currentSocket->lastRead = 0;
        currentSocket->lastRcvd = 0;
        currentSocket->nextExpected = 0;
        currentSocket->RTT = 0;
        currentSocket->effectiveWindow = 0;

        currentSocket->src = 0;
        currentSocket->dest.port = 0;
        currentSocket->dest.addr = 0;

        dbg(TRANSPORT_CHANNEL, "Closed socket %d\n", fd);
        return SUCCESS;
    }

    command error_t Transport.release(socket_t fd){
        return 0;
    }

    command error_t Transport.listen(socket_t fd){
        return 0;
    }

    event message_t* Receiver.receive(message_t* msg, void* payload, uint8_t len) {
        return msg;
    }

    event void sendTimer.fired(){
        uint16_t i;
    }

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
        Package->src = src; // Link Layer Head
        Package->dest = dest; // Link Layer Head
        Package->TTL = TTL; // Flooding Header
        Package->seq = seq; // Flooding Header
        Package->protocol = protocol; // Flooding Header
        memcpy(Package->payload, payload, length);
    }
}