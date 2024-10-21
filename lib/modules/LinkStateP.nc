module LinkStateP{
    provides interface LinkState;
}

implementation {
    command void LinkState.dummy() {
        uint8_t i = 1;
    }
}