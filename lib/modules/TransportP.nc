#define MAX_NUM_OF_SOCKETS 1
#define NULL_SOCKET 255
#define SLIDING_WINDOW_SIZE 1

#include "../../includes/socket.h"
#include "../../includes/tcpPacket.h"

module TransportP{
    provides interface Transport;
    uses interface SimpleSend;
    uses interface Receive as Receiver;
    uses interface Timer<TMilli> as sendTimer;
    uses interface LinkState; // call LinkState.send(packet, destination);
}

implementation{
    // Manage multiple sockets 
    socket_store_t sockets[MAX_NUM_OF_SOCKETS];
    // uint8_t responseData[SOCKET_BUFFER_SIZE];
    void forwardSYN(uint16_t src, uint16_t dest, tcp_pack* synPack);
    uint16_t destination;
    pack sendReq;
    uint16_t seqNum;

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);
    socket_t getSocket(uint16_t node);
    void sendData(socket_t fd);
    error_t receiveData(socket_t fd, uint8_t seq, uint8_t* data);
    
    // Allocates new socket(s)
    command socket_t Transport.socket(){
        uint16_t i;
        for(i = 0; i < MAX_NUM_OF_SOCKETS; i++){
            if (sockets[i].state == CLOSED){
                // listen state
                sockets[i].state = LISTEN;
                dbg(TRANSPORT_CHANNEL, "[Transport.socket] Socket allocated with ID: %d\n", i);
                return i; // Return socket ID
            }
        }
        dbg(TRANSPORT_CHANNEL, "[Transport.socket] No sockets available\n");
        return NULL_SOCKET; // No Sockets available
    }


    // SYN and ACK 

    // Binds socket with an address and port
    command error_t Transport.bind(socket_t fd, socket_addr_t *addr){

        dbg(TRANSPORT_CHANNEL, "[Transport.bind] Socket %d current state: %d\n", fd, sockets[fd].state);

        if (sockets[fd].state == LISTEN){

            addr->addr = TOS_NODE_ID;
            sockets[fd].src = 80; 
            addr->port = 80;
            dbg(TRANSPORT_CHANNEL, "Socket binds to address %d, port %d\n", TOS_NODE_ID, addr->port);

            makePack(&sendReq, TOS_NODE_ID, addr->addr, MAX_TTL, PROTOCOL_TCP, 0, (uint8_t*)&sockets[fd], sizeof(socket_store_t));
            call LinkState.send(sendReq);
            dbg(TRANSPORT_CHANNEL, "LSP packet sent for socket %d\n", fd);

            return SUCCESS; // Able to bind            
        }

        dbg(TRANSPORT_CHANNEL, "[Transport.bind] Unable to bind\n");
        return FAIL; // Unable to bind
    }


    // Accepts incoming connectivity
    command socket_t Transport.accept(socket_t fd){
        dbg(TRANSPORT_CHANNEL, "[Transport.accept] Socket %d state: %d\n", fd, sockets[fd].state);
        
        if (sockets[fd].state == LISTEN) {
            // Check if SYN packet is ready to accept
            sockets[fd].state = SYN_RCVD;
            dbg(TRANSPORT_CHANNEL, "[Transport.accept] Socket %d now waiting for SYN\n", fd);
                // ESTABLISHED transition 
                // sockets[fd].state = ESTABLISHED; 
                dbg(TRANSPORT_CHANNEL, "[Transport.accept] Socket %d accepted connection from %d\n", fd, sockets[fd].dest.addr);
                return fd;
        }
        dbg(TRANSPORT_CHANNEL, "[Transport.accept] Socket %d cannot accept connection (no SYN recieved)\n", fd);
        return NULL_SOCKET;
    }

    // Send data from buffer through the socket
    command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen){
        socket_store_t *currentSocket = &sockets[getSocket(fd)];
        uint16_t combinedData = 0;
        uint16_t i;

        for (i = 0; i < bufflen; i++) {
            currentSocket->sendBuff[i] = buff[i];

            combinedData <<= 8; //8 is the size of uint8_t
            combinedData += buff[i];
        }

        return combinedData;
    }


    command error_t Transport.receive(pack* package){
        pack* p = (pack*)package;
        tcp_pack* rcvdPayload;
        socket_t fd;
        
        if (p->protocol != PROTOCOL_TCP)
            return FAIL;

        rcvdPayload = (tcp_pack*)p->payload;
        fd = getSocket(p->src);

        if (fd == NULL_SOCKET)
            return FAIL;

        if (rcvdPayload->flag == DATA) {
            
        } else if (rcvdPayload->flag == ACK) {
            
        } else if (rcvdPayload->flag == SYN) {
            
        } else if (rcvdPayload->flag == SYN_ACK) {
            
        } else if (rcvdPayload->flag == FIN) {
            
        }

        return SUCCESS;
    }

    command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen){
        socket_store_t currentSocket = sockets[getSocket(fd)];
        uint16_t combinedData = 0;
        uint16_t i;

        for (i = 0; i < bufflen; i++) {
            buff[i] = currentSocket.rcvdBuff[i];

            combinedData <<= 8; //8 is the size of uint8_t
            combinedData += buff[i];
        }

        return combinedData;
    }

    command error_t Transport.connect(socket_t fd, socket_addr_t * addr){
        /* Goal: Intiates a connection a remote socket
        > 3-way handshake (sending SYN and wait for SYN-ACK)
        > Set state to SYN_SENT during handshake
        */ 
        tcp_pack synPack;
    
        // Initial SYN
        synPack.flag = SYN;
        synPack.data = NULL; // No data in SYN pack
        
        sockets[fd].dest = *addr; // Does nothing right now

        synPack.flag = SYN;
        sockets[fd].state = SYN_SENT;
        makePack(&sendReq, TOS_NODE_ID, addr->addr, MAX_TTL, PROTOCOL_TCP, 0, (uint8_t*)&synPack, sizeof(tcp_pack));
                
        call LinkState.send(sendReq);
        // Start timer for retransmission
    }

    command error_t Transport.close(socket_t fd){
        /* Goal: Close a socket
        > Clears buffers, resets variables
        */
        socket_store_t *currentSocket;
        pack *closePackage;
        uint16_t dest;
        uint8_t *payload;

        if (fd >= MAX_NUM_OF_SOCKETS)
            return FAIL;

        currentSocket = &sockets[fd];

        if (currentSocket->state == CLOSED)
            return SUCCESS;

        dest = currentSocket->dest.addr;
        
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

        makePack(closePackage, TOS_NODE_ID, dest, MAX_TTL, PROTOCOL_TCP, 0, (uint8_t*)currentSocket, sizeof(socket_store_t));
        call LinkState.send(*closePackage);

        dbg(TRANSPORT_CHANNEL, "Closed socket %d\n", fd);
        return SUCCESS;
    }

    command error_t Transport.release(socket_t fd){
        socket_store_t *currentSocket = &sockets[fd];

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

        return SUCCESS;
    }

    command error_t Transport.listen(socket_t fd){
        socket_store_t *currentSocket = &sockets[fd];

        if (currentSocket->state != CLOSED)
            return FAIL;
        
        currentSocket->state = LISTEN;
        return SUCCESS;
    }

    event message_t* Receiver.receive(message_t* msg, void* payload, uint8_t len) {
        if (len == sizeof(pack)) {
            pack* package = (pack*)payload;
            if (package->protocol == PROTOCOL_TCP){
                if (package->dest == TOS_NODE_ID) {
                    dbg(ROUTING_CHANNEL, "TCP Package received at %d from %d\n", TOS_NODE_ID, package->src);
                    call Transport.receive(package);
                } else {
                    dbg(ROUTING_CHANNEL, "Forwarding TCP Package\n");
                    call LinkState.send(*package);
                }
            }
        }
        return msg;
    }

    event void sendTimer.fired(){ 
        uint16_t i;
        socket_store_t currentSocket;

        for (i = 0; i < MAX_NUM_OF_SOCKETS; i++) {
            currentSocket = sockets[i];
            switch (currentSocket.state){

                case ESTABLISHED:
                    if (currentSocket.src == TOS_NODE_ID) {
                        sendData(i);
                    }
                    break;

                case LISTEN:
                    sendListen(i);
                    break;
                    
            }
            
        }
    }

    void forwardSYN(uint16_t src, uint16_t dest, tcp_pack* synPack) {
        pack forwardPacket;

        if (synPack == NULL || synPack->flag != SYN) {
            dbg(TRANSPORT_CHANNEL, "Invalid SYN packet received\n");
        }

        makePack(&forwardPacket, src, dest, MAX_TTL, PROTOCOL_TCP, 0, (uint8_t*)synPack, sizeof(tcp_pack));
        call LinkState.send(forwardPacket);

        dbg(TRANSPORT_CHANNEL, "Forwarded SYN packet from %d to %d\n", src, dest);
    }

    // Constructs a TCP packet, encapsulate data with headers
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
        Package->src = src; // Link Layer Head
        Package->dest = dest; // Link Layer Head
        Package->TTL = TTL; // Flooding Header
        Package->seq = seq; // Flooding Header
        Package->protocol = protocol; // Flooding Header
        memcpy(Package->payload, payload, length);
    }

    // returns the fd of the socket that has to do with the given node
    socket_t getSocket(uint16_t node) {
        uint16_t i;
        for(i = 0; i < MAX_NUM_OF_SOCKETS; i++) {
            if(sockets[i].dest.addr == node || sockets[i].src == node)
                return i;
        }
        return NULL_SOCKET;
    }

    void sendData(socket_t fd) {
        socket_store_t *currentSocket = &sockets[fd];
        tcp_pack *dataPack;
        pack package;

        if (currentSocket->lastSent >= currentSocket->lastAck + SLIDING_WINDOW_SIZE) {
            dataPack->seq = currentSocket->lastAck + 1;
        } else {
            dataPack->seq = ++currentSocket->lastSent;
        }

        dataPack->flag = DATA;
        dataPack->data = currentSocket->sendBuff[dataPack->seq];

        // may need to change length in the future, depending on how much data is being sent
        makePack(&package, TOS_NODE_ID, currentSocket->dest.addr, MAX_TTL, PROTOCOL_TCP, seqNum++, (uint8_t*)dataPack, 1);
        call LinkState.send(package);
    }

    error_t receiveData(socket_t fd, uint8_t seq, uint8_t* data) {
        socket_store_t *currentSocket = &sockets[fd];
        uint8_t lastRcvd = currentSocket->lastRcvd;

        if (seq <= lastRcvd || seq > lastRcvd + SLIDING_WINDOW_SIZE) {
           return FAIL;
        }

        currentSocket->rcvdBuff[seq] = data;
        if (seq == lastRcvd + 1)
            currentSocket->lastRcvd++;
            
        return SUCCESS;
    }
}