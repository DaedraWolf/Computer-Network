#define MAX_NUM_OF_SOCKETS 1
#define NULL_SOCKET 255
#define SLIDING_WINDOW_SIZE 1
#define TCP_TIMER_LENGTH 2000
#define TEST_SERVER_NODE 1
#define MAX_RETRIES 100
#define TEST_STRING "abcdefg"

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
    void sendSyn(uint16_t addr);
    void sendSynAck(uint16_t addr);
    void sendAck(uint16_t addr, uint8_t seq);

    // Project 4
    void sendMsg(uint16_t addr);
    void sendMsgEnd(uint16_t addr);

    void startTimer();
    uint8_t synRetry = 0;
    uint16_t destination;
    pack sendReq;
    uint16_t seqNum = 1;
    uint16_t rcvdSeq[MAX_NEIGHBORS][MAX_NEIGHBORS];

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);
    socket_t getSocket(uint16_t node);
    void sendData(socket_t fd);
    error_t receiveData(socket_t fd, uint8_t seq, uint8_t* data);

    command void Transport.startTimer() {
        call sendTimer.startPeriodic(TCP_TIMER_LENGTH);
    }
    
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

    // Binds socket with an address and port
    command error_t Transport.bind(socket_t fd, socket_addr_t *addr){
        socket_store_t *currentSocket = &sockets[fd];

        dbg(TRANSPORT_CHANNEL, "[Transport.bind] Socket %d current state: %d\n", fd, currentSocket->state);
        if (currentSocket->state == LISTEN){
            // addr->addr = TOS_NODE_ID; 
            currentSocket->src = TOS_NODE_ID;
            currentSocket->dest.addr = addr->addr;
            // addr->port = 80; 
            dbg(TRANSPORT_CHANNEL, "Socket binds to address %d, port %d\n", TOS_NODE_ID, addr->port);

            makePack(&sendReq, TOS_NODE_ID, addr->addr, MAX_TTL, PROTOCOL_TCP, 0, (uint8_t*)currentSocket, sizeof(socket_store_t));
            call LinkState.send(sendReq);
            dbg(TRANSPORT_CHANNEL, "LSP packet sent for socket %d\n", fd);
            
            return SUCCESS; // Able to bind            
        }

        dbg(TRANSPORT_CHANNEL, "[Transport.bind] Unable to bind\n");
        return FAIL; // Unable to bind
    }


    // Accepts incoming connectivity
    command socket_t Transport.accept(socket_t fd){
        socket_store_t *currentSocket = &sockets[fd];
        
        dbg(TRANSPORT_CHANNEL, "[Transport.accept] Socket %d state: %d\n", fd, currentSocket->state);
        
        if (currentSocket->state == SYN_RCVD) {
            currentSocket->state = ESTABLISHED;
            // dbg(TRANSPORT_CHANNEL, "[Transport.accept] Socket %d now waiting for SYN\n", fd);

            dbg(TRANSPORT_CHANNEL, "[Transport.accept] Socket %d now established connection with %d\n", fd, currentSocket->dest.addr);
                return fd;
        }
        // dbg(TRANSPORT_CHANNEL, "[Transport.accept] Socket %d cannot accept connection (no SYN recieved)\n", fd);
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
        tcp_pack* rcvdPayload;
        socket_t fd;
        socket_addr_t addr;
        socket_t serverSocket;
        uint16_t i;

        addr.addr = package->src;
        
        if (package->protocol != PROTOCOL_TCP)
            return FAIL;

        rcvdPayload = (tcp_pack*)package->payload;
        fd = getSocket(package->src);

        switch (rcvdPayload->flag) {
            // Project 4
            case MSG:
                if (fd == NULL_SOCKET)
                    return FAIL;

                sockets[fd].state = SENDING;
                sockets[fd].rcvType = sockets[fd].sendType; // Get type from socket
                dbg(TRANSPORT_CHANNEL, "Received MSG \n");

                break;

            case MSG_END:
                if (fd == NULL_SOCKET)
                    return FAIL;

                sockets[fd].state = ESTABLISHED;
                dbg(TRANSPORT_CHANNEL, "Received MSG_END \n");

                break;

            case SYN:

                dbg(TRANSPORT_CHANNEL, "Received SYN from %d\n", package->src);

                for (i = 0; i < MAX_NUM_OF_SOCKETS; i++) {
                    if (sockets[i].state == LISTEN) {
                        serverSocket = i;
                        break;
                    }
                }

                if (serverSocket == NULL_SOCKET) {
                    serverSocket = call Transport.socket();
                }

                if (call Transport.bind(serverSocket, &addr) == SUCCESS) {
                    dbg(TRANSPORT_CHANNEL, "Server socket bound successfully\n");
  
                    sendSynAck(package->src);
                    sockets[serverSocket].state = SYN_RCVD;
                    // dbg(TRANSPORT_CHANNEL, "%d: %d\n", serverSocket, sockets[fd].state);
                } else {
                    dbg(TRANSPORT_CHANNEL, "Failed to bind server socket\n");
                }
                
                break;

            case SYN_ACK:
                if (fd == NULL_SOCKET)
                    return FAIL;

                if (call Transport.accept(fd) == SUCCESS) {
                    dbg(TRANSPORT_CHANNEL, "Received SYN_ACK from %d\n", package->src);
                    sendAck(package->src, 0);
                }

                break;

            case ACK:
                if (fd == NULL_SOCKET)
                    return FAIL;
                dbg(TRANSPORT_CHANNEL, "Received ACK[%d] from %d \n", rcvdPayload->seq, package->src);

                if (sockets[fd].state == SYN_SENT || sockets[fd].state == SYN_RCVD) {
                    sockets[fd].state = ESTABLISHED;
                    dbg(TRANSPORT_CHANNEL, "Server established\n");
                    sendAck(package->src, 0);
                } else if (sockets[fd].state == ESTABLISHED) {
                    // dbg(TRANSPORT_CHANNEL, "Received ACK[%d]\n", rcvdPayload->seq);
                    sockets[fd].lastAck++;
                    
                }

                break;

            case DATA:
                if (fd == NULL_SOCKET)
                    return FAIL;

                dbg(TRANSPORT_CHANNEL, "Received DATA from %d; seq: %d; data: '%c'\n", package->src, rcvdPayload->seq, rcvdPayload->data);

                receiveData(fd, rcvdPayload->seq, rcvdPayload->data);
                sendAck(package->src, sockets[fd].lastRcvd);
                break;

            case FIN:
                dbg(TRANSPORT_CHANNEL, "Received FIN packet from %d\n", package->src);
                sendAck(package->src, 0);  // Acknowledge the FIN
                call Transport.close(fd);   // Close our side
                break;

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
        pack package;
    
        // Initial SYN
        synPack.flag = SYN;
        synPack.data = NULL; // No data in SYN pack
        sockets[fd].dest.addr = TEST_SERVER_NODE;

        //Replace all with new helper function sendSYN()
        synPack.flag = SYN;
        sockets[fd].state = SYN_SENT;

        call Transport.write(fd, TEST_STRING, sizeof(TEST_STRING));
        
        makePack(&package, TOS_NODE_ID, TEST_SERVER_NODE, MAX_TTL, PROTOCOL_TCP, 0, (uint8_t*)&synPack, sizeof(tcp_pack));

        call LinkState.send(package);
        
        return SUCCESS;
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

    command void Transport.serverStart(uint8_t port){
        socket_t serverSocket;
        socket_addr_t addr;

        if(serverSocket == NULL_SOCKET){
            serverSocket = call Transport.socket();
        }
        
        if(serverSocket != NULL_SOCKET){
            addr.port = port;
            addr.addr = TOS_NODE_ID;
        }
    }

    command void Transport.clientStart(uint16_t dest, uint8_t srcPort, uint8_t destPort){
        socket_t clientSocket;
        socket_addr_t addr;

        if(clientSocket == NULL_SOCKET){
            clientSocket = call Transport.socket();
        }

        if(clientSocket != NULL_SOCKET){
            sockets[clientSocket].src = srcPort;
            addr.port = destPort;
            addr.addr = dest;
        }
    }

    command void Transport.send(uint16_t dest, enum msg_type type, uint8_t* msg){
        uint16_t i;
        socket_store_t *currentSocket;
        socket_t fd = getSocket(dest);
        tcp_pack sendPack;
        pack package;

        if (fd == NULL_SOCKET)
            currentSocket = &sockets[0];
        else
            currentSocket = &sockets[fd];

        sendPack.flag = MSG;
        sendPack.data[0] = type;
        sendPack.data[1] = dest;
        currentSocket->state = MSG_START;
        currentSocket->cache = &sendPack;

        makePack(&package, TOS_NODE_ID, TEST_SERVER_NODE, MAX_TTL, PROTOCOL_TCP, 0, (uint8_t*)&sendPack, sizeof(tcp_pack));
        call LinkState.send(package);
    }

    event message_t* Receiver.receive(message_t* msg, void* payload, uint8_t len) {
        if (len == sizeof(pack)) {
            pack* package = (pack*)payload;
            if (package->protocol == PROTOCOL_TCP){
                // if (package->seq <= rcvdSeq[package->src][package->dest]) {
                //     dbg(TRANSPORT_CHANNEL, "Dropping duplicate package from %d; Seq %d\n", package->src, package->seq);
                //     return msg;
                // }

                if (package->TTL <= 0)
                    return msg;

                rcvdSeq[package->src][package->dest] = package->seq;

                if (package->dest == TOS_NODE_ID) {
                    dbg(TRANSPORT_CHANNEL, "TCP Package received at %d from %d\n", TOS_NODE_ID, package->src);
                    call Transport.receive(package);
                } else {
                    dbg(TRANSPORT_CHANNEL, "Forwarding TCP Package\n");
                    package->TTL--;
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

                // Project 4
                case SENDING:
                    sendMsg(currentSocket.dest.addr);
                    break;

                case SYN_SENT:
                    // Retransmit SYN if waiting
                    if (synRetry < MAX_RETRIES){
                        sendSyn(currentSocket.dest.addr);
                        synRetry++;
                    }
                    break;

                case SYN_RCVD:
                    // Retransmit SYN_ACK if waiting
                    sendSyn(currentSocket.dest.addr);
                    break;

                case ESTABLISHED:
                    // if (currentSocket.src == TOS_NODE_ID) {
                        sendData(i);
                    // }
                    break;

                case LISTEN:
                    // sendSyn(i);
                    break;
                    
            }
            
        }
    }

    // Added new helper functions for sending messages / ending (Project 4)

    void sendMsg(uint16_t addr){
        tcp_pack msgPacket;
        pack msgPack;

        msgPacket.flag = MSG;
        
        makePack(&msgPack, TOS_NODE_ID, addr, MAX_TTL, PROTOCOL_TCP, seqNum++, (uint8_t*)&msgPacket, sizeof(tcp_pack));
        call LinkState.send(msgPack);
        
        dbg(TRANSPORT_CHANNEL, "Sending MSG packet to %d\n", addr);
    }

    void sendMsgEnd(uint16_t addr){
        tcp_pack endPacket;
        pack endPack;

        endPacket.flag = MSG_END;
        
        makePack(&endPack, TOS_NODE_ID, addr, MAX_TTL, PROTOCOL_TCP, seqNum++, (uint8_t*)&endPacket, sizeof(tcp_pack));
        call LinkState.send(endPack);
        
        dbg(TRANSPORT_CHANNEL, "Sending MSG_END packet to %d\n", addr);
        }
    // New additions for Project 4 above

    void sendSyn(uint16_t addr){
        tcp_pack synPacket;
        pack synPack;

        synPacket.flag = SYN;
        
        makePack(&synPack, TOS_NODE_ID, addr, MAX_TTL, PROTOCOL_TCP, seqNum++, (uint8_t*)&synPacket, sizeof(tcp_pack));
        call LinkState.send(synPack);
        
        dbg(TRANSPORT_CHANNEL, "Sending SYN packet\n");
    }
        
    void sendSynAck(uint16_t addr){
        tcp_pack synAckPacket;
        pack synAckPack;

        synAckPacket.flag = SYN_ACK;

        makePack(&synAckPack, TOS_NODE_ID, addr, MAX_TTL, PROTOCOL_TCP, seqNum++, (uint8_t*)&synAckPacket, sizeof(tcp_pack));
        call LinkState.send(synAckPack);

        dbg(TRANSPORT_CHANNEL, "Sending SYN-ACK packet\n");
    }

    void sendAck(uint16_t addr, uint8_t seq){
        tcp_pack ackPacket;
        pack ackPack;

        ackPacket.flag = ACK;
        ackPacket.seq = seq;

        makePack(&ackPack, TOS_NODE_ID, addr, MAX_TTL, PROTOCOL_TCP, seqNum++, (uint8_t*)&ackPacket, sizeof(tcp_pack));
        call LinkState.send(ackPack);

        dbg(TRANSPORT_CHANNEL, "Sending ACK packet\n");
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
        tcp_pack dataPack;  // Changed from pointer to struct
        pack package;
        uint8_t dataLength = sizeof(TEST_STRING) - 1;  // -1 to exclude null terminator
        
        // Check if we've sent all data
        if (currentSocket->lastSent >= dataLength) {
            dbg(TRANSPORT_CHANNEL, "All data sent (%d bytes). Sending FIN.\n", currentSocket->lastSent);
            dataPack.flag = FIN;
            dataPack.seq = 0;
            dataPack.data = NULL;
            
            makePack(&package, TOS_NODE_ID, currentSocket->dest.addr, MAX_TTL, PROTOCOL_TCP, seqNum++, (uint8_t*)&dataPack, sizeof(tcp_pack));
            call LinkState.send(package);
            sockets[fd].state = CLOSED;
            return;
        }

        if (currentSocket->lastSent >= currentSocket->lastAck + SLIDING_WINDOW_SIZE) {
            return;  // Window full, wait for ACKs
        }

        dataPack.seq = ++currentSocket->lastSent;
        dataPack.flag = DATA;
        dataPack.data = currentSocket->sendBuff[dataPack.seq - 1];  // -1 because arrays are 0-based

        dbg(TRANSPORT_CHANNEL, "Sending Data to %d; data_seq: %d; data: %c\n", 
            currentSocket->dest.addr, dataPack.seq, dataPack.data);

        makePack(&package, TOS_NODE_ID, currentSocket->dest.addr, MAX_TTL, PROTOCOL_TCP, seqNum++, (uint8_t*)&dataPack, sizeof(tcp_pack));
        call LinkState.send(package);
    }

    error_t receiveData(socket_t fd, uint8_t seq, uint8_t* data) {
        socket_store_t *currentSocket = &sockets[fd];
        uint8_t lastRcvd = currentSocket->lastRcvd;

        if (seq <= lastRcvd || seq > lastRcvd + SLIDING_WINDOW_SIZE) {
            dbg(TRANSPORT_CHANNEL, "DATA[%d] not accepted, outside window\n", seq);
            return FAIL;
        }

        currentSocket->rcvdBuff[seq] = data;
        if (seq == lastRcvd + 1)
            currentSocket->lastRcvd++;

        dbg(TRANSPORT_CHANNEL, "DATA[%d] accepted\n", seq);
            
        return SUCCESS;
    }
}