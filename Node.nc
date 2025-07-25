/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"
#include "includes/socket.h"


module Node{
   uses interface Boot;

   uses interface SplitControl as AMControl;
   uses interface Receive;

   uses interface SimpleSend as Sender;
   uses interface CommandHandler;

   uses interface Flooding;
   uses interface NeighborDiscovery;

   uses interface LinkState;

   uses interface TCPSend;
   uses interface Transport;
}

implementation{
   pack sendPackage;

   socket_t serverSocket;
   socket_t clientSocket;

   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

   event void Boot.booted(){
      call AMControl.start();

      dbg(GENERAL_CHANNEL, "Booted\n");
      
      call LinkState.advertise();

      call Transport.startTimer();
   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
      dbg(GENERAL_CHANNEL, "Packet Received\n");
      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;
         dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
         return msg;
      }
      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }


   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      dbg(GENERAL_CHANNEL, "PING EVENT \n");
      makePack(&sendPackage, TOS_NODE_ID, destination, 0, 0, 0, payload, PACKET_MAX_PAYLOAD_SIZE);
      call Sender.send(sendPackage, destination);
   }

   event void CommandHandler.printNeighbors(){}

   event void CommandHandler.printRouteTable(){
      dbg(GENERAL_CHANNEL, "PRINTING LINKSTATE ROUTE TABLE... \n");
      call LinkState.printRouteTable();
   }

   event void CommandHandler.printLinkState(){}

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(){
      dbg(TRANSPORT_CHANNEL, "SETTING TEST SERVER... \n");
      call Transport.listen( call Transport.socket() );
   }

   event void CommandHandler.setTestClient(){
      dbg(TRANSPORT_CHANNEL, "SETTING TEST CLIENT... \n");
      call Transport.connect( call Transport.socket(), 0 );
   }

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}

   // new additions
   event void CommandHandler.flood(uint16_t dest){
      dbg(GENERAL_CHANNEL, "FLOODING EVENT \n");
      call Flooding.flood(dest);
   }

   event void CommandHandler.discoverNeighbors(){
      dbg(GENERAL_CHANNEL, "NEIGHBOR DISCOVERY EVENT \n");
      call NeighborDiscovery.discoverNeighbors();
   }

   event void CommandHandler.linkStateAdvertise(){
      dbg(GENERAL_CHANNEL, "LINKSTATE ADVERTISE EVENT \n");
      call LinkState.advertise();
   }

   event void CommandHandler.linkStatePing(uint16_t dest){
      dbg(GENERAL_CHANNEL, "LINKSTATE PING EVENT \n");
      call LinkState.ping(dest);
   }

   event void CommandHandler.serverStart(uint8_t port){
      dbg(GENERAL_CHANNEL, "SERVER START EVENT \n");
      call Transport.serverStart(port);
   }

   event void CommandHandler.clientStart(uint16_t dest, uint8_t srcPort, uint8_t destPort){
      dbg(GENERAL_CHANNEL, "CLIENT START EVENT \n");
      call Transport.clientStart(dest, srcPort, destPort);
   }

   event void CommandHandler.send(uint16_t dest, enum msg_type type, uint8_t* msg){
      dbg(GENERAL_CHANNEL, "MESSAGE SEND EVENT \n");
      call Transport.send(dest, type, msg);
   }
   //end of new additions

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }
}
