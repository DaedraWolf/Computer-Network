#include "../../includes/am_types.h"

configuration FloodingC{
   provides interface Flooding;
}

implementation{
   components FloodingP;
   Flooding = FloodingP.Flooding;

   components new TimerMilliC() as sendTimer;
   FloodingP.sendTimer -> sendTimer;

   components new SimpleSendC(AM_PACK);
   FloodingP.SimpleSend -> SimpleSendC;

   components new AMReceiverC(AM_PACK) as Receiver;
   FloodingP.Receiver -> Receiver;
}