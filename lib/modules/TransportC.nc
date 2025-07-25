#include "../../includes/am_types.h"

configuration TransportC{
   provides interface Transport;
}

implementation{
   components TransportP;

   Transport = TransportP.Transport;

   components new TimerMilliC() as sendTimer;
   TransportP.sendTimer -> sendTimer;

   components new SimpleSendC(AM_PACK);
   TransportP.SimpleSend -> SimpleSendC;

   components new AMReceiverC(AM_PACK) as Receiver;
   TransportP.Receiver -> Receiver;

   components LinkStateC;
   TransportP.LinkState -> LinkStateC;
}