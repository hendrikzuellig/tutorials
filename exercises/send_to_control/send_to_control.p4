/* -*- P4_16 -*- */
#include <core.p4>
#include <sume_switch.p4>

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<8>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

const port_t CPU_PORT = 8w0b00000010;

typedef bit<8> digCode_t;
const digCode_t DIG_LOCAL_IP = 1;
const digCode_t DIG_ARP_MISS = 2;
const digCode_t DIG_ARP_REPLY = 3;
const digCode_t DIG_TTL_EXCEEDED = 4;
const digCode_t DIG_NO_ROUTE = 5;

header digest_header_t {
    bit<8>   src_port;
    bit<8>   digest_code;
    bit<240> unused;
}

header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

// List of all recognized headers
struct Parsed_packet {
    digest_header_t digest;
    ethernet_t ethernet;
}

// user defined metadata: can be used to share information between
// TopParser, TopPipe, and TopDeparser
struct user_metadata_t {
    bit<8> unused;
}

// digest data to be sent to CPU if desired. MUST be 256 bits!
struct digest_data_t {
    bit<240>  unused;
    bit<8>   digest_code;
    bit<8>   src_port;
}

/***************************************************************
*********************** P A R S E R  *************************
***************************************************************/

@Xilinx_MaxPacketRegion(1024)
parser TopParser(packet_in b,
                out Parsed_packet p,
                out user_metadata_t user_metadata,
                out digest_data_t digest_data,
                inout sume_metadata_t sume_metadata) {

    state start {
        user_metadata.unused = 0;
        digest_data.src_port = 0;
        digest_data.digest_code = 0;
        digest_data.unused = 0;
        transition parse_ethernet;
    }

    state parse_ethernet {
        b.extract(p.ethernet);
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

    apply {
        sume_metadata.dst_port = CPU_PORT;
        p.digest.setValid();
        p.digest.unused = 0; 
        p.digest.digest_code = DIG_NO_ROUTE; 
        p.digest.src_port = sume_metadata.src_port;
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
        b.emit(p.digest);
        b.emit(p.ethernet);
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

SimpleSumeSwitch(TopParser(), TopPipe(), TopDeparser()) main;
