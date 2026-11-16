# Measurement

Each edge measures what it carries: its tunnels, the underlay paths
under them, and, when asked, the service's own traffic. The figures
are RFC 9375's (one-way delay, its variation, loss, in microseconds
and counts) and go three ways: into the edge's own decisions (a tunnel
down, a threshold crossed, a policy's tunnel changed), into the
**Paths** tab and `arcanactl sdwan`, and into the console's RFC 9375
view of each service. [Probes, rules and steering](steering.md) shows
what the page draws of them; this chapter says how each is made.

## What is measured

An apply gives each edge a list of targets (arcana-probe):

- **a tunnel**: the far end's inner address, probed through the
  service's table (its FIB), with the service's probe settings;
- **an underlay path**: one for each pair of UCS End Points a tunnel
  joins, the far edge's WAN address (the tunnel's outer address) in the
  near end's own table, FIB 0 where it has none. It is measured as a
  tunnel is, but it is no tunnel: its no answer is a fault of its own
  (`underlay`), not `tunnel`, and it steers nothing;
- **a class of service** of a tunnel: each of the service's probe
  `classes` (`voice=46, bulk=10`, eight at most) a session of its own,
  with its own socket and DSCP, so a class a queue or a policer treats
  apart is seen apart. A class's session raises no fault and steers
  nothing: the tunnel's state is its own DSCP's.

## STAMP, and ICMP echo when it must

Between two Arcana edges the probe is STAMP (RFC 8762, with RFC 8972's
TLVs): a UDP flow to the far end's reflector, `stampd(8)` from the
`stamp` submodule. The agent runs no reflector itself: when the FIBs
its targets use change, it writes `stampd_enable` and `stampd_fibs` in
rc.conf and runs `service stampd reload`, which starts one `stampd` a
FIB through rc.subr's `stampd_fib` (setfib(1)), the base's way of
binding a daemon to a table. Each `stampd` gives up root once bound,
runs in a chroot as `_stampd`, takes T2 from the kernel
(`SO_TS_REALTIME`) and answers from the address the request came to.

A target's `kind` says how it is probed:

- `auto` (the default; the console's tunnels): STAMP to an Arcana far
  end, and ICMP echo when STAMP gets nothing, so that a tunnel stays up
  while its far `stampd` restarts. After `down` unanswered STAMP probes
  the target is pinged, its misses one short of down, so the first echo
  tells a tunnel down from a reflector gone; one STAMP probe every ten
  seconds brings STAMP back.
- `stamp`: STAMP alone. A silent reflector is a tunnel down. It needs
  no raw socket, so no root.
- `icmp`: an echo alone (the breakout beacons, and the monitors).

At a jail's edge the probes are ICMP echo: the agent has no UDP socket
in a vnet jail's network yet.

`arcanactl sdwan stamp` prints one line for each session: the method
and why not STAMP, the reflector's mode, the round trip, the delay each
way, the loss each way, the DSCP each way, the NAT, and whether it is
authenticated. The Paths tab's **How each end measures** table has the
same, a row for each end of each tunnel.

### Delay and loss each way

A round trip is (T4 − T1) − (T3 − T2): the reflector's own time taken
out, T1 and T4 on the monotonic clock, T4 the kernel's receive time
(`SO_TS_MONOTONIC`). The delay **each way** needs both clocks: the
reflector says its clock's source and error in the Timestamp
Information TLV (from ntp_gettime(2): `ntp` when the kernel says it is
synchronised, else `local`), the sender its own, and the delay forward
(T2 − T1) and backward (T4 − T3) is said only when both errors
together are no more than a tenth of half the round trip, so that what
is said is right to a tenth. Otherwise each way is half the round
trip, marked an estimate (`≈ half RTT` in the table). An
NTP-synchronised pair therefore gives one-way figures only over paths
long against its error; a clock the kernel does not know is
synchronised (PTP without its PLL, GNSS) is said with `--stamp-clock`.

The loss **each way** comes from a stateful reflector: its counter of
requests received, read between two replies, tells lost forward from
lost backward; RFC 8972's Direct Measurement TLV gives the same by both
ends' packet counts all along. A stateless reflector gives the round
trip's loss alone.

### DSCP, NAT and authentication

- **DSCP**: the probe asks, by the Class of Service TLV, for its reply
  to carry the target's DSCP, and the reflector says the DSCP the
  request arrived with (`IP_RECVTOS`, `IPV6_RECVTCLASS`). So each end
  sees whether the path remarks its class, each way: "46 sent, forward
  46, backward 0" is a network that bleaches the reply.
- **NAT**: the Location TLV has the reflector say the addresses and
  ports it saw; against the sender's own, a source or destination
  rewritten on the way is told (`nat`).
- **Authentication**: on a plain tunnel (GRE, gif, GENEVE without
  IPsec) STAMP is authenticated by default (RFC 8762's mode,
  HMAC-SHA-256 truncated to 128 bits, libcrypto). Each end has an
  X25519 pair; the console gives each the other's public half, and both
  derive the same key and SSID by HKDF-SHA256: the key is never on the
  wire and never at the console. WireGuard, uswe and IPsec tunnels
  carry plain STAMP, their packets being authenticated already.

## Measurement intervals

Of each answer the prober keeps a raw sample: the round trip, the delay
each way where it was measured, and the variation of each against the
answer before (RFC 3393's IPDV). Samples are gathered into measurement
intervals aligned to the wall clock (60 s by default, 1 to 3600,
RFC 9375's `measurement-interval`), at most 4096 kept an interval and
beyond them a uniform sample of all (reservoir sampling). Of every
value the least, the most and the mean; of those kept, three
percentiles by the nearest rank, 10, 50 and 90 by default (set on the
service form); the loss as a count and a percentage of those sent. The
Paths tab's **Measurement intervals** table shows the last completed
one for each end of each tunnel; `arcanactl sdwan intervals` prints
it, and arcana-probe's state has the last sixty.

Beside the probes, each edge reads, at each read of its probes' state,
the counters of the interfaces its tunnels and links go over (from
`if_data` through getifaddrs(3), as `netstat -ibn` reads them) and the
number of routes in each of its tables (a netlink(4) `RTM_GETROUTE`
dump, as `netstat -rn -F` reads them, kept 30 s since a full BGP table
is a long dump).

## Alternate marking

Probes measure probes. To measure the service's own packets, a service
may turn on alternate marking (RFC 9341): the service form's
**Alternate marking block, s** (2 to 3600). Time is cut into blocks of
that length; in every other block each packet that goes into a tunnel
has the lowest bit of its DSCP set, and both ends count the packets of
each colour. When a block has ended, what went in at one end and what
came out at the other are the block's loss, of the traffic itself, with
no packet added.

It is ipfw, in the SD-WAN set (30), its rules coming and going with the
set:

- on the way into a tunnel, last (rule 11, before a flow's dummynet
  queue or pipe), a `setdscp tablearg` sets the colour from one of two
  tables, swapped each block with `IP_FW_TABLE_XSWAP` (one atomic
  switch); two `count` rules count each colour; the colour is cleared
  on the outer header of the tunnel's own packets, so the underlay
  never sees it;
- on the way out of a tunnel, first (rule 9), two `count` rules count
  each colour and a `setdscp` clears it before anything else sees the
  packet.

The agent reads the counters through `IP_FW3` in the middle of each
block (when the last block's packets have all arrived and none of the
next's have come) and numbers blocks by the wall clock, so the edges'
clocks must agree within a quarter of a block (ntpd(8) or chronyd); a
block read outside that guard band is marked not valid. A flow's queue
by DSCP matches the class and its coloured neighbour (`dscp 46,47`),
and since the colour comes before dummynet, what dummynet drops (a full
queue, a pipe's rate) counts as lost in the tunnel.

The DSCP's lowest bit is set by none of the standard classes (CS, AF,
EF, VA), but it is by Lower Effort (RFC 8622's 1) and the local and
experimental pools: on a marked tunnel those arrive as their even
neighbour (LE as best effort). A service with alternate marking takes
even DSCPs alone for its probes and classes. An admin's own rule past
Arcana's band that matches a DSCP on the way out by a tunnel sees the
colour in odd blocks: write `dscp 46,47` there.

The console pairs each tunnel's blocks by number and partitions the
service's links into RFC 9342's clusters (§5.1), so that a loss is
localised to the cluster it happened in: the Paths tab's **Alternate
marking** tables have each tunnel's loss each way by block and each
cluster's, and `/restconf/data/arcana-console:sdwan/alt-marking` the
same.

## The services' view: RFC 9375

The console serves each service as RFC 9375's network
(`ietf-network-vpn-pm`) under `/restconf/data/ietf-network:networks`,
beside the SAP network: a node each vpn-node, two links each tunnel
(one each way, over the underlay's link), each link's last completed
interval its `pm` (one-way figures from the source end's forward ones,
else the far end's backward ones), the classes as RFC 9375's
per-class statistics, and `arcana:underlay`, the network of the
underlay paths, with their own figures. RFC 9375's metrics are one-way
alone; the round trip is an augment's (`arcana-network-vpn-pm`), and
it is all an ICMP-measured tunnel has.

## Not measured yet

- **Flow records** (NetFlow v9 by ng_netflow(4) for each service's
  FIB): ipfw hands packets to netgraph by `ngtee`, which needs
  ng_ipfw(4) loaded; and ng_netflow keeps an expired flow in a partly
  filled export datagram until it fills, with no timer to send it.
- **BMP** from BIRD to the console, and a time-series store with a
  retention for each class.
- **The in-band variant of alternate marking**, the far end's block
  counts carried in STAMP's Direct Measurement TLV so that an edge
  could steer on loss without the console: `stampd` knows nothing of
  the agent's blocks yet.
