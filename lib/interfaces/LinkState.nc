interface LinkState{
    command void advertise();
    command void printRouteTable();
    command void send(pack packet, uint16_t destination);
    command void ping(uint16_t destination);
}