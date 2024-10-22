configuration LinkStateC{
    provides interface LinkState;
}

implementation{
    components LinkStateP;
    LinkState = LinkStateP.LinkState;

    components new TimerMilliC() as LSATimer;
    LinkStateP.LSATimer -> LSATimer;

    components NeighborDiscoveryC;
    LinkStateP.NeighborDiscovery -> NeighborDiscoveryC;

    components FloodingC;
    LinkStateP.Flooding -> FloodingC;

    components new SimpleSendC(AM_PACK);
    LinkStateP.SimpleSend -> SimpleSendC;

    components new AMReceiverC(AM_PACK) as Receiver;
	LinkStateP.Receiver -> Receiver;
}