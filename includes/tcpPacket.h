#ifndef __TCPPACKET_H__
#define __TCPPACKET_H__

enum tcp_flag{
    DATA,
    ACK,
    SYN,
    SYN_ACK,
    FIN
};

// Add tracking for packet timing and sequence
typedef struct tcp_timers {
    uint32_t sentTime;      // When packet was sent
    uint32_t timeout;       // Timeout = sentTime + 2*RTT
    uint16_t seqNum;        // Sequence number of this packet
    uint16_t ackNum;        // Expected acknowledgment number
}tcp_timer;

typedef struct tcp_pack{
  enum tcp_flag flag;
  uint8_t* data;
  uint8_t seq;
}tcp_pack;

#endif