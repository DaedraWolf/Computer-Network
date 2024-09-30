#define MAX_SEQ 40

#include "../../includes/channels.h"

module HashTableP{
    provides interface HashTable;
}

implementation{
    uint16_t sequenceNum = 0;
    uint8_t key = TOS_NODE_ID, sequenceNum;
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);
    // calculate hash value h(k) = k mod m
    // key = src && seq#, size = MAX_SEQ
    void hashFunction()
    {
    dbg(FLOODING_CHANNEL, "Key sent from: %d,SequenceMAX: %d\n", key, MAX_SEQ);
    return key % MAX_SEQ;
    }

    command void test(){
        dbg(FLOODING_CHANNEL, "Key sent from: %d,SequenceMAX: %d\n", key, MAX_SEQ);
    }
}