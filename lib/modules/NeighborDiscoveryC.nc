#include "../../includes/am_types.h"

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

   components new HashmapC(uint8_t, 20);
   NeighborDiscoveryP.Hashmap -> HashmapC;
}