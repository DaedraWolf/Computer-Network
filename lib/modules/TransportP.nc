#include "../../includes/socket.h"

module TransportP{
    provides interface Transport;
    uses interface SimpleSend;
    uses interface Receive as Receiver;
    uses interface Timer<TMilli> as sendTimer;
    uses interface LinkState;
}

implementation{
    command socket_t Transport.socket(){
        return 0;
    }

    command error_t Transport.bind(socket_t fd, socket_addr_t *addr){
        return 0;
    }

    command socket_t Transport.accept(socket_t fd){
        return 0;
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