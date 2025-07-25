#ifndef __TCPPACKET_H__
#define __TCPPACKET_H__

enum tcp_flag{
    DATA,
    ACK,
    SYN,
    SYN_ACK,
    FIN,
    MSG_START,  // messaging packets
    MSG_END     // end of message
};

typedef struct tcp_pack{
  enum tcp_flag flag;
  uint8_t seq;
  uint8_t* data;
}tcp_pack;

#endif