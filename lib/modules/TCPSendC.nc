#include "../../includes/am_types.h"

configuration TCPSendC{
   provides interface TCPSend;
}

implementation{
   components TCPSendP;

   TCPSend = TCPSendP.TCPSend;

   components new TimerMilliC() as sendTimer;
   TCPSendP.sendTimer -> sendTimer;

   components new SimpleSendC(AM_PACK);
   TCPSendP.SimpleSend -> SimpleSendC;

   components new AMReceiverC(AM_PACK) as Receiver;
   TCPSendP.Receiver -> Receiver;

   components LinkStateC;
   TCPSendP.LinkState -> LinkStateC;
}