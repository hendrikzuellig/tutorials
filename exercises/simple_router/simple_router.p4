//
// Copyright (c) 2017 Stephen Ibanez
// All rights reserved.
//
// This software was developed by Stanford University and the University of Cambridge Computer Laboratory
// under National Science Foundation under Grant No. CNS-0855268,
// the University of Cambridge Computer Laboratory under EPSRC INTERNET Project EP/H040536/1 and
// by the University of Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249 ("MRC2"),
// as part of the DARPA MRC research programme.
//
// @NETFPGA_LICENSE_HEADER_START@
//
// Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
// license agreements.  See the NOTICE file distributed with this work for
// additional information regarding copyright ownership.  NetFPGA licenses this
// file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
// "License"); you may not use this file except in compliance with the
// License.  You may obtain a copy of the License at:
//
//   http://www.netfpga-cic.org
//
// Unless required by applicable law or agreed to in writing, Work distributed
// under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations under the License.
//
// @NETFPGA_LICENSE_HEADER_END@
//


#include <core.p4>
#include <sume_switch.p4>


typedef bit<48> EthAddr_t;
typedef bit<32> IPv4Addr_t;

const bit<16> IP_TYPE = 16w0x0800;
const bit<16> ARP_TYPE = 16w0x0806;

const bit<4> IPv4 = 4w0x4;

const bit<16> ARP_OP_REQ = 16w0x0001;
const bit<16> ARP_OP_REPLY = 16w0x0002;

const port_t CPU_PORT = 8w0b00000010;
const port_t PHYSICAL_INTERFACES = 8w0b01010101;

typedef bit<8> digCode_t;
const digCode_t DIG_LOCAL_IP = 1;
const digCode_t DIG_ARP_MISS = 2;
const digCode_t DIG_ARP_REPLY = 3;
const digCode_t DIG_TTL_EXCEEDED = 4;
const digCode_t DIG_NO_ROUTE = 5;

#define REG_READ 8w0
#define REG_WRITE 8w1
#define REG_ADD  8w2

#define ETHERTYPE_INDEX_WIDTH 2

const bit<ETHERTYPE_INDEX_WIDTH> IPv4_REG_INDEX = 0;
const bit<ETHERTYPE_INDEX_WIDTH> ARP_REG_INDEX = 1;
const bit<ETHERTYPE_INDEX_WIDTH> INVALID_REG_INDEX = 2;

// Counters for the number of IPv4 and ARP packets received
@Xilinx_MaxLatency(64)
@Xilinx_ControlWidth(ETHERTYPE_INDEX_WIDTH)
extern void ethertype_reg_raw(in bit<ETHERTYPE_INDEX_WIDTH> index,
                              in bit<8> newVal,
                              in bit<8> incVal,
                              in bit<8> opCode,
                              out bit<8> result);

#define CP_INDEX_WIDTH 1

const bit<CP_INDEX_WIDTH> CP_REG_INDEX = 0;

// Counter for the number of packets sent to the control plane
@Xilinx_MaxLatency(64)
@Xilinx_ControlWidth(CP_INDEX_WIDTH)
extern void cp_reg_raw(in bit<CP_INDEX_WIDTH> index,
                       in bit<8> newVal,
                       in bit<8> incVal,
                       in bit<8> opCode,
                       out bit<8> result);

// IP checksum extern
@Xilinx_MaxLatency(3)
@Xilinx_ControlWidth(0)
extern void ck_ip_chksum(in bit<4> version,
                         in bit<4> ihl,
                         in bit<8> tos,
                         in bit<16> totalLen,
                         in bit<16> identification,
                         in bit<3> flags,
                         in bit<13> fragOffset,
                         in bit<8> ttl,
                         in bit<8> protocol,
                         in bit<16> hdrChecksum,
                         in bit<32> srcAddr,
                         in bit<32> dstAddr,
                         out bit<16> result);

// IP checksum extern
@Xilinx_MaxLatency(3)
@Xilinx_ControlWidth(0)
extern void compute_ip_chksum(in bit<4> version,
                              in bit<4> ihl,
                              in bit<8> tos,
                              in bit<16> totalLen,
                              in bit<16> identification,
                              in bit<3> flags,
                              in bit<13> fragOffset,
                              in bit<8> ttl,
                              in bit<8> protocol,
                              in bit<16> hdrChecksum,
                              in bit<32> srcAddr,
                              in bit<32> dstAddr,
                              out bit<16> result);

// standard Ethernet header
header Ethernet_h {
    EthAddr_t dstAddr;
    EthAddr_t srcAddr;
    bit<16> etherType;
}

// IPv4 header without options
header IPv4_h {
    bit<4> version;
    bit<4> ihl;
    bit<8> tos;
    bit<16> totalLen;
    bit<16> identification;
    bit<3> flags;
    bit<13> fragOffset;
    bit<8> ttl;
    bit<8> protocol;
    bit<16> hdrChecksum;
    IPv4Addr_t srcAddr;
    IPv4Addr_t dstAddr;
}

// ARP header
header ARP_h {
    bit<16> hwType;
    bit<16> protoType;
    bit<8> hwAddrLen;
    bit<8> protoAddrLen;
    bit<16> opcode;
    // assumes hardware type is ethernet and protocol is IP
    EthAddr_t srcEth;
    IPv4Addr_t srcIP;
    EthAddr_t dstEth;
    IPv4Addr_t dstIP;
}

header digest_header_h {
    bit<8>   src_port;
    bit<8>   digest_code;
    bit<240> unused;
}

// List of all recognized headers
struct Parsed_packet {
    Ethernet_h ethernet;
    // Only one of ARP or IP will be valid
    ARP_h arp;
    IPv4_h ip;
    digest_header_h digest;
}

// user defined metadata: can be used to shared information between
// TopParser, TopPipe, and TopDeparser
struct user_metadata_t {
    bit<8>  unused;
}

// digest data to be sent to CPU if desired. MUST be 256 bits!
struct digest_data_t {
    bit<256>  unused;
}

// Parser Implementation
@Xilinx_MaxPacketRegion(16384)
parser TopParser(packet_in b,
                 out Parsed_packet p,
                 out user_metadata_t user_metadata,
                 out digest_data_t digest_data,
                 inout sume_metadata_t sume_metadata) {
    state start {
        b.extract(p.ethernet);
        user_metadata.unused = 0;
        digest_data.unused = 0;
        transition select(p.ethernet.etherType) {
            IP_TYPE: parse_ipv4;
            ARP_TYPE: parse_arp;
            default: accept;
        }
    }

    state parse_ipv4 {
        b.extract(p.ip);
        transition accept;
    }

    state parse_arp {
        b.extract(p.arp);
        transition accept;
    }
}

// match-action pipeline
control TopPipe(inout Parsed_packet p,
                inout user_metadata_t user_metadata,
                inout digest_data_t digest_data,
                inout sume_metadata_t sume_metadata) {

    // Local mac table stores the ethernet addresses
    // of the router, as the router should not process
    // packets unless they are destined for this router
    table local_mac_table {
        key = {
            p.ethernet.dstAddr: exact;
        }
        actions = {
            NoAction;
        }
        default_action = NoAction;
    }

    // Sets the destination port so that the packet is
    // forwarded to the control plane, and initializes
    // the digest_date with the source port and digest code
    action send_to_cpu_cp(bit<8> digest_code) {
        sume_metadata.dst_port = CPU_PORT;
        p.digest.setValid();
        p.digest.unused = 0;
        p.digest.digest_code = digest_code;
        p.digest.src_port = sume_metadata.src_port;
    }

    // Sets the destination port so that the packet is
    // forwarded to the control plane, and initializes
    // the digest_date with the source port and digest code
    action send_to_cpu_dp(in bit<8> digest_code) {
        sume_metadata.dst_port = CPU_PORT;
        p.digest.setValid();
        p.digest.unused = 0;
        p.digest.digest_code = digest_code;
        p.digest.src_port = sume_metadata.src_port;
    }

    // Matches IP packets that are destined to this router
    // so that the control plane can handle them
    bit<8> from_control_plane;
    table local_ip_table {
        key = {
            p.ip.dstAddr: exact;
            from_control_plane: exact;
        }
        actions = {
            send_to_cpu_cp;
            NoAction;
        }
        size = 64;
        default_action = NoAction;
    }

    // Prepares to forward a packet by setting its egress port
    // and finding out the IP address of its next-hop router
    IPv4Addr_t next_hop_ip = 0;
    action ipv4_forward(port_t port, IPv4Addr_t next) {
        sume_metadata.dst_port = port;
        next_hop_ip = next;
    }

    action send_to_cpu_no_route() {
        send_to_cpu_cp(DIG_NO_ROUTE);
    }

    // Determines the port out of which a packet should be
    // routed in order to get to its destination IP
    table routing_table {
        key = {
            p.ip.dstAddr: ternary;
        }
        actions = {
            ipv4_forward;
            send_to_cpu_no_route;
        }
        size = 63;
        default_action = send_to_cpu_no_route;
    }

    action update_src_mac(EthAddr_t src_mac) {
        p.ethernet.srcAddr = src_mac;
    }

    // Determines what the source MAC of a packet should
    // be based on its destination port
    table update_smac_table {
        key = {
            sume_metadata.dst_port: exact;
        }
        actions = {
            update_src_mac;
            NoAction;
        }
        size = 64;
        default_action = NoAction;
    }

    action update_dst_mac(EthAddr_t dst_mac) {
        p.ethernet.dstAddr = dst_mac;
    }

    action send_to_cpu_arp_miss() {
        sume_metadata.dst_port = CPU_PORT;
        p.digest.setValid();
        p.digest.unused = 0;
        p.digest.digest_code = DIG_ARP_MISS;
        p.digest.src_port = sume_metadata.src_port;
    }

    // Matches next hop IP addresses to next hop MACs
    table arp_cache_table {
        key = {
            next_hop_ip: exact;
        }
        actions = {
            update_dst_mac;
            send_to_cpu_arp_miss;
        }
        size = 64;
        default_action = send_to_cpu_arp_miss;
    }

    // Constructs an arp response from an arp request
    action swap_arp_headers(EthAddr_t src_mac) {
        p.ethernet.dstAddr = p.arp.srcEth;
        p.arp.dstEth = p.arp.srcEth;
        p.ethernet.srcAddr = src_mac;
        p.arp.srcEth = src_mac;

        IPv4Addr_t dstIP = p.arp.srcIP;
        p.arp.srcIP = p.arp.dstIP;
        p.arp.dstIP = dstIP;

        p.arp.opcode = ARP_OP_REPLY;

        sume_metadata.dst_port = sume_metadata.src_port;
    }

    // Matches arp requests based on their destination ip and
    // source port to determine if they are meant for this router
    table arp_req_table {
        key = {
            p.arp.dstIP: exact;
            sume_metadata.src_port: exact;
        }
        actions = {
            swap_arp_headers;
            NoAction;
        }
        size = 64;
        default_action = NoAction;
    }

    action send_to_cpu_arp_reply() {
        send_to_cpu_cp(DIG_ARP_REPLY);
    }

    // Matches arp replies based on their destination ip and
    // source port to determine if they are meant for this router
    table arp_reply_table {
        key = {
            p.arp.dstIP: exact;
            sume_metadata.src_port: exact;
        }
        actions = {
            send_to_cpu_arp_reply;
            NoAction;
        }
        size = 64;
        default_action = NoAction;
    }

    action update_dst_port(port_t port) {
        sume_metadata.dst_port = port;
    }

    // Updates the destination port of the packet
    // based on the source ethernet address
    // meant to be used for packets from the control plane
    table update_dport_table {
        key = {
            p.ethernet.srcAddr: exact;
        }
        actions = {
            update_dst_port;
            NoAction;
        }
        size = 64;
        default_action = NoAction;
    }

    apply {
        // Set the destination port to be 0 so that the packet
        // is dropped by default if the destination port isn't
        // set later in the match-action pipeline
        sume_metadata.dst_port = 0;

        from_control_plane = (sume_metadata.src_port & CPU_PORT) >> 1;

        // Check that dst MAC belonds to this router
        if (local_mac_table.apply().hit) {
            if (p.ip.isValid()) {
                bit<1> ip_header_valid = 0;
                ip_header_valid = 1;
                // Verify version
                if (IPv4 != p.ip.version) {
                    ip_header_valid = 0;
                }
                // Verify length fields
                if (p.ip.ihl < 5 || p.ip.totalLen < ((bit<16>)p.ip.ihl << 3)) {
                    ip_header_valid = 0;
                }
                // TODO: temporary for testing ...
                ip_header_valid = 1;
//                // Make sure checksum is correct
//                bit<16> checksum = p.ip.hdrChecksum;
//                bit<16> result;
//                p.ip.hdrChecksum = 0;
//                ck_ip_chksum(p.ip.version, p.ip.ihl, p.ip.tos, p.ip.totalLen,
//                    p.ip.identification, p.ip.flags, p.ip.fragOffset, p.ip.ttl,
//                    p.ip.protocol, p.ip.hdrChecksum, p.ip.srcAddr, p.ip.dstAddr, result);
//                p.ip.hdrChecksum = checksum;
//                if (result != checksum) {
//                    ip_header_valid = 0;
//                }

                if (ip_header_valid == 1 && !local_ip_table.apply().hit) {
                    // Forward packet to next destination
                    if (p.ip.ttl <= 1) {
                        // Send to control plane if time exceeded
                        send_to_cpu_dp(DIG_TTL_EXCEEDED);
                    } else {
                        // Apply routing table to get next hop IP addr
                        if (routing_table.apply().hit) {
                            update_smac_table.apply();
                            // Support for directly attached networks
                            if (next_hop_ip == 0) {
                                next_hop_ip = p.ip.dstAddr;
                            }
                            // Try to lookup next-hop MAC address
                            // If found, decrement TTL and update IP checksum
                            if (arp_cache_table.apply().hit) {
                                // TODO: temporary for testing ...
//                                p.ip.ttl = p.ip.ttl - 1;
//                                bit<16> result;
//                                p.ip.hdrChecksum = 0;
//                                compute_ip_chksum(p.ip.version, p.ip.ihl, p.ip.tos, p.ip.totalLen,
//                                    p.ip.identification, p.ip.flags, p.ip.fragOffset, p.ip.ttl,
//                                    p.ip.protocol, p.ip.hdrChecksum, p.ip.srcAddr, p.ip.dstAddr, result);
//                                p.ip.hdrChecksum = result;
                            }
                        }
                    }
                }
            } else if (p.arp.isValid() && from_control_plane == 0) {
                if (ARP_OP_REQ == p.arp.opcode) {
                    arp_req_table.apply();
                } else if (ARP_OP_REPLY == p.arp.opcode) {
                    arp_reply_table.apply();
                }
            }
        }

        if (from_control_plane == 1 && sume_metadata.dst_port != CPU_PORT) {
            // The packet has been sent by the control plane and there's no reason to send it back
            // We want to send it out of the interface specified by the src MAC address
            update_dport_table.apply();
        }

        // TODO: temporary for testing ...
//        // Increment counters
//        bit<8> result; // unused
//        bit<8> newVal = 0; // unused
//        bit<8> incVal = 1;
//        bit<ETHERTYPE_INDEX_WIDTH> ethertype_index = INVALID_REG_INDEX;
//        if (p.arp.isValid()) {
//            ethertype_index = ARP_REG_INDEX;
//        } else if (p.ip.isValid()) {
//            ethertype_index = IPv4_REG_INDEX;
//        }
//        if (INVALID_REG_INDEX != ethertype_index) {
//            ethertype_reg_raw(ethertype_index, newVal, incVal, REG_ADD, result);
//        }
//        if (CPU_PORT == sume_metadata.dst_port) {
//            cp_reg_raw(CP_REG_INDEX, newVal, incVal, REG_ADD, result);
//        }
    }
}

// Deparser Implementation
@Xilinx_MaxPacketRegion(16384)
control TopDeparser(packet_out b,
                    in Parsed_packet p,
                    in user_metadata_t user_metadata,
                    inout digest_data_t digest_data,
                    inout sume_metadata_t sume_metadata) {
    apply {
        b.emit(p.digest);
        b.emit(p.ethernet);
        b.emit(p.ip);
        b.emit(p.arp);
    }
}

// Instantiate the switch
SimpleSumeSwitch(TopParser(), TopPipe(), TopDeparser()) main;
