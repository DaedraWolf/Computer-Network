#define WINDOW_SIZE 10

#include "../../includes/am_types.h"

typedef struct {
   bool data[WINDOW_SIZE];
   uint16_t lastSequence;
} Array8_t;

configuration NeighborDiscoveryC{
   provides interface NeighborDiscovery;
}

implementation{
   components NeighborDiscoveryP;
   NeighborDiscovery = NeighborDiscoveryP.NeighborDiscovery;

   components new TimerMilliC() as sendTimer;
   NeighborDiscoveryP.sendTimer -> sendTimer;

   components new SimpleSendC(AM_PACK);
   NeighborDiscoveryP.SimpleSend -> SimpleSendC;

   components new AMReceiverC(AM_PACK) as Receiver;
	NeighborDiscoveryP.Receiver -> Receiver;

   components new HashmapC(Array8_t, 20);
   NeighborDiscoveryP.Hashmap -> HashmapC;
}