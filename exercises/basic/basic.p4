/* -*- P4_16 -*- */
#include <core.p4>
#include <sume_switch.p4>

const bit<16> TYPE_IPV4 = 0x800;

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<8>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<8>    diffserv;
    bit<16>   totalLen;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdrChecksum;
    ip4Addr_t srcAddr;
    ip4Addr_t dstAddr;
}

// List of all recognized headers
struct Parsed_packet {
    ethernet_t ethernet;
    ipv4_t ipv4;
}

// user defined metadata: can be used to share information between
// TopParser, TopPipe, and TopDeparser
struct user_metadata_t {
    bit<8> unused;
}

// digest data, MUST be 256 bits
struct digest_data_t {
    bit<256>  unused;
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

@Xilinx_MaxPacketRegion(1024)
parser TopParser(packet_in b,
                out Parsed_packet p,
                out user_metadata_t user_metadata,
                out digest_data_t digest_data,
                inout sume_metadata_t sume_metadata) {
    state start {
        /* TODO: add parser logic */
        transition accept;
    }
}

/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control TopPipe(inout Parsed_packet p,
                inout user_metadata_t user_metadata,
                inout digest_data_t digest_data,
                inout sume_metadata_t sume_metadata) {
    action drop() {
        sume_metadata.dst_port = 0;
    }

    action ipv4_forward(macAddr_t dstAddr, egressSpec_t port) {
        /* TODO: fill out code in action body */
    }

    table ipv4_lpm {
        key = {
            p.ipv4.dstAddr: lpm;
        }
        actions = {
            ipv4_forward;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = NoAction();
    }

    apply {
        /* TODO: fix ingress control logic
         *  - ipv4_lpm should be applied only when IPv4 header is valid
         */
        ipv4_lpm.apply();
    }
}

/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

@Xilinx_MaxPacketRegion(1024)
control TopDeparser(packet_out b,
                    in Parsed_packet p,
                    in user_metadata_t user_metadata,
                    inout digest_data_t digest_data,
                    inout sume_metadata_t sume_metadata) {
    apply {
        /* TODO: add deparser logic */
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

SimpleSumeSwitch(TopParser(), TopPipe(), TopDeparser()) main;
