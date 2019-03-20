# Basic IPv4 Forwarding

## Introduction

The objective of this exercise is to write a P4 program that
implements basic forwarding. To keep things simple, we will just
implement forwarding for IPv4.

With IPv4 forwarding, the switch will perform the following actions
for every packet: (i) update the source and destination MAC addresses,
(ii) decrement the time-to-live (TTL) in the IP header, (iii) update
the IP checksum, and (iv) forward the packet out the appropriate port.

To update the IP checksum you can use the fact that decrementing the
TTL field by one corresponds to incrementing the checksum by 256 (plus
the overflow bit).

Your switch will have a single table, which the control plane will
populate with static rules. Each rule will map an IP address to the
MAC address and output port for the next hop. We have already defined
the control plane rules, so you only need to implement the data plane
logic of your P4 program.

> **Spoiler alert:** There is a reference solution in the `solution`
> sub-directory. Feel free to compare your implementation to the
> reference.

## Step 1: Run the (incomplete) starter code

The directory with this README also contains a skeleton P4 program,
`basic.p4`, which initially drops all packets. Your job will be to
extend this skeleton program to forward IPv4 packets.

Before that, let's compile the incomplete `basic.p4` and bring
up a switch in Mininet to test its behavior.

1. In your shell, run:
   ```bash
   make
   ```
   This will:
   * compile `basic.p4`, and
   * start a Mininet instance with three switches (`s1`, `s2`, `s3`)
     configured in a triangle, each connected to one host (`h1`, `h2`,
     and `h3`).
   * The hosts are assigned IPs of `10.0.1.1`, `10.0.2.2`, and `10.0.3.3`.

2. You should now see a Mininet command prompt. Open a terminal on `h1`:
   ```bash
   mininet> xterm h1
   ```
3. Try to ping h2 from h1.
   ```bash
   # ping 10.0.2.2
   ```
   Or you can ping directly from the Mininet command line:
   ```bash
   mininet> h1 ping h2
   ```
   The ping will fail.

4. Type `exit` to leave the xterm and the Mininet command line.
   Then, to stop mininet:
   ```bash
   make stop
   ```
   And to delete all pcaps, build files, and logs:
   ```bash
   make clean
   ```

The ping failed because each switch is programmed according to
`basic.p4`, which drops all packets on arrival. Your job is to
extend this file so it forwards packets.

### A note about the control plane

A P4 program defines a packet-processing pipeline, but the rules
within each table are inserted by the control plane. When a rule
matches a packet, its action is invoked with parameters supplied by
the control plane as part of the rule.

In this exercise, we have already implemented the the control plane
logic for you. As part of bringing up the Mininet instance, the
`make run` command will install packet-processing rules in the tables of
each switch. These are defined in the `sX-commands.txt` files, where
`X` corresponds to the switch number.

## Step 2: Implement IPv4 forwarding

The `basic.p4` file contains a skeleton P4 program with key pieces of
logic replaced by `TODO` comments. Your implementation should follow
the structure given in this file---replace each `TODO` with logic
implementing the missing piece.

A complete `basic.p4` will contain the following components:

1. Header type definitions for Ethernet (`ethernet_t`) and IPv4 (`ipv4_t`).
2. **TODO:** Parsers for Ethernet and IPv4 that populate `ethernet_t` and `ipv4_t` fields.
3. An action to drop a packet, using `mark_to_drop()`.
4. **TODO:** An action (called `ipv4_forward`) that:
	1. Sets the egress port for the next hop. 
	2. Updates the ethernet destination address with the address of the next hop. 
	3. Updates the ethernet source address with the address of the switch. 
	4. Decrements the TTL by one.
	4. Updates the checksum by adding 256.
5. **TODO:** A control that:
    1. Defines a table that will read an IPv4 destination address, and
       invoke either `drop` or `ipv4_forward`.
    2. An `apply` block that applies the table.   
6. **TODO:** A deparser that selects the order
    in which fields inserted into the outgoing packet.
7. A `package` instantiation supplied with the parser, control, and deparser.

## Step 3: Run your solution

Follow the instructions from Step 1. This time, the ping should succeed.

### Troubleshooting

There are several problems that might manifest as you develop your program:

1. `basic.p4` might fail to compile. In this case, `make run` will
report the error emitted from the compiler and halt.

2. `basic.p4` might compile but fail to support the control plane
rules in the `s1-commands.txt` through `s3-commands.txt` files that
`make run` tries to install using the control-plane. In this case,
examine the logs/sX_cli_output.log files.

3. `basic.p4` might compile, and the control plane rules might be
installed, but the switch might not process packets in the desired
way. The `logs/sX.log` files contain detailed logs that describing
how each switch processes each packet. The output is detailed and can
help pinpoint logic errors in your implementation.


#### Cleaning up Mininet

In the latter two cases above, `make run` may leave a Mininet instance
running in the background. Use the following command to clean up
these instances:

```bash
make stop
```

## Questions

Please answer the following questions in the README file of your simple_router
project.

1. What would happen if you try to traceroute through this router? Explain
   what the router would need to do differently for traceroute to work.
2. What happens to the number of routing table entries when this router
   is connected to a large L2 network with many hosts? Can you think of a
   way to decouple forwarding decisions from MAC address updates?
3. Explain how MAC address are assigned to router interfaces in this design.
   How should they be assigned to router interfaces on a real router?
4. Why do we need to run `# arp -i eth0 -s <IP> <MAC>` on each host upon
   initializing the topology? What additional functionality needs to be added
   to the router to avoid this?
5. What happens when you try to ping 10.1.2.3 from one of the hosts? What
   should happen if the router was implemented correctly?
6. This design uses a longest-prefix-match to implement the routing table. LPM
   tables are currently not well supported in SDNet, so we will instead use a
   ternary match table. How would you translate the following LPM table into a
   ternary match table?

   LPM Table:

   Prefix   | Prefix length | data
   ---------|---------------|-----
   10.1.0.0 | 16            | XXX
   10.1.2.0 | 24            | YYY
   10.0.0.0 | 8             | ZZZ


   Ternary Table:

   Prefix   |     Mask    | priority | data
   ---------|-------------|----------|-----
            |             |          |
            |             |          |
            |             |          |

