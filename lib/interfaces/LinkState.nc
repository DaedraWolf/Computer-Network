interface LinkState{
    command void advertise();
    command uint16_t getNextHop(uint16_t dest);
}