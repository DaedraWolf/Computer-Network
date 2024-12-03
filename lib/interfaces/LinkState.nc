interface LinkState{
    command void advertise();
    command void printRouteTable();
    command void send(pack package);
    command void ping(uint16_t destination);
}