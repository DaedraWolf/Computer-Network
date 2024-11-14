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
        // Check if currentSocket is valid
        // if (currentSocket == NULL){
        //     dbg(TRANSPORT_CHANNEL, "Bind failed (No active sockets)\n");
        //     return FAIL;
        // }

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
        return 0;
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

}