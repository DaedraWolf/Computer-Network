#include "../../includes/am_types.h"

configuration FloodingC{
   provides interface Flooding;
}

implementation{
   components FloodingP;
   Flooding = FloodingP.Flooding;

   components TimerMilliC() as sendTimer;
   FloodingP.sendTimer -> sendTimer;
}