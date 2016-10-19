#!/bin/sh
#
# Copyright (C) 2000, 2001, 2004, 2005, 2007, 2011-2016  Internet Systems Consortium, Inc. ("ISC")
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# $Id: tests.sh,v 1.37 2012/02/22 23:47:35 tbox Exp $

SYSTEMTESTTOP=..
. $SYSTEMTESTTOP/conf.sh

DIGOPTS="+tcp +noadd +nosea +nostat +noquest +nocomm +nocmd"

status=0
n=0

n=`expr $n + 1`
echo "I:testing basic zone transfer functionality"
$DIG $DIGOPTS example. \
	@10.53.0.2 axfr -p 5300 > dig.out.ns2 || status=1
grep "^;" dig.out.ns2

#
# Spin to allow the zone to tranfer.
#
for i in 1 2 3 4 5
do
tmp=0
$DIG $DIGOPTS example. \
	@10.53.0.3 axfr -p 5300 > dig.out.ns3 || tmp=1
	grep "^;" dig.out.ns3 > /dev/null
	if test $? -ne 0 ; then break; fi
	echo "I: plain zone re-transfer"
	sleep 5
done
if test $tmp -eq 1 ; then status=1; fi
grep "^;" dig.out.ns3

$PERL ../digcomp.pl dig1.good dig.out.ns2 || status=1

$PERL ../digcomp.pl dig1.good dig.out.ns3 || status=1

n=`expr $n + 1`
echo "I:testing TSIG signed zone transfers"
$DIG $DIGOPTS tsigzone. \
    	@10.53.0.2 axfr -y tsigzone.:1234abcd8765 -p 5300 \
	> dig.out.ns2 || status=1
grep "^;" dig.out.ns2

#
# Spin to allow the zone to tranfer.
#
for i in 1 2 3 4 5
do
tmp=0
$DIG $DIGOPTS tsigzone. \
    	@10.53.0.3 axfr -y tsigzone.:1234abcd8765 -p 5300 \
	> dig.out.ns3 || tmp=1
	grep "^;" dig.out.ns3 > /dev/null
	if test $? -ne 0 ; then break; fi
	echo "I: plain zone re-transfer"
	sleep 5
done
if test $tmp -eq 1 ; then status=1; fi
grep "^;" dig.out.ns3

$PERL ../digcomp.pl dig.out.ns2 dig.out.ns3 || status=1

echo "I:reload servers for in preparation for ixfr-from-differences tests"

$RNDC -c ../common/rndc.conf -s 10.53.0.1 -p 9953 reload 2>&1 | sed 's/^/I:ns1 /'
$RNDC -c ../common/rndc.conf -s 10.53.0.2 -p 9953 reload 2>&1 | sed 's/^/I:ns2 /'
$RNDC -c ../common/rndc.conf -s 10.53.0.3 -p 9953 reload 2>&1 | sed 's/^/I:ns3 /'
$RNDC -c ../common/rndc.conf -s 10.53.0.6 -p 9953 reload 2>&1 | sed 's/^/I:ns6 /'
$RNDC -c ../common/rndc.conf -s 10.53.0.7 -p 9953 reload 2>&1 | sed 's/^/I:ns7 /'

sleep 2

echo "I:updating master zones for ixfr-from-differences tests"

$PERL -i -p -e '
	s/0\.0\.0\.0/0.0.0.1/;
	s/1397051952/1397051953/
' ns1/slave.db

$RNDC -c ../common/rndc.conf -s 10.53.0.1 -p 9953 reload 2>&1 | sed 's/^/I:ns1 /'

$PERL -i -p -e '
	s/0\.0\.0\.0/0.0.0.1/;
	s/1397051952/1397051953/
' ns2/example.db

$RNDC -c ../common/rndc.conf -s 10.53.0.2 -p 9953 reload 2>&1 | sed 's/^/I:ns2 /'

$PERL -i -p -e '
	s/0\.0\.0\.0/0.0.0.1/;
	s/1397051952/1397051953/
' ns6/master.db

$RNDC -c ../common/rndc.conf -s 10.53.0.6 -p 9953 reload 2>&1 | sed 's/^/I:ns6 /'

$PERL -i -p -e '
	s/0\.0\.0\.0/0.0.0.1/;
	s/1397051952/1397051953/
' ns7/master2.db

$RNDC -c ../common/rndc.conf -s 10.53.0.7 -p 9953 reload 2>&1 | sed 's/^/I:ns7 /'

sleep 3

echo "I:testing zone is dumped after successful transfer"
$DIG $DIGOPTS +noall +answer +multi @10.53.0.2 -p 5300 \
	slave. soa > dig.out.ns2 || tmp=1
grep "1397051952 ; serial" dig.out.ns2 > /dev/null 2>&1 || tmp=1
grep "1397051952 ; serial" ns2/slave.db > /dev/null 2>&1 || tmp=1
if test $tmp != 0 ; then echo "I:failed"; fi
status=`expr $status + $tmp`

n=`expr $n + 1`
echo "I:testing ixfr-from-differences yes;"
tmp=0
for i in 0 1 2 3 4 5 6 7 8 9
do
	$DIG $DIGOPTS @10.53.0.3 -p 5300 +noall +answer soa example > dig.out.soa.ns3
	grep "1397051953" dig.out.soa.ns3 > /dev/null && break;
	sleep 1
done

$DIG $DIGOPTS example. \
	@10.53.0.3 axfr -p 5300 > dig.out.ns3 || tmp=1
grep "^;" dig.out.ns3

$PERL ../digcomp.pl dig2.good dig.out.ns3 || tmp=1

# ns3 has a journal iff it received an IXFR.
test -f ns3/example.bk || tmp=1 
test -f ns3/example.bk.jnl || tmp=1 

if test $tmp != 0 ; then echo "I:failed"; fi
status=`expr $status + $tmp`

n=`expr $n + 1`
echo "I:testing ixfr-from-differences master; (master zone)"
tmp=0

$DIG $DIGOPTS master. \
	@10.53.0.6 axfr -p 5300 > dig.out.ns6 || tmp=1
grep "^;" dig.out.ns6

$DIG $DIGOPTS master. \
	@10.53.0.3 axfr -p 5300 > dig.out.ns3 || tmp=1
grep "^;" dig.out.ns3 && cat dig.out.ns3

$PERL ../digcomp.pl dig.out.ns6 dig.out.ns3 || tmp=1

# ns3 has a journal iff it received an IXFR.
test -f ns3/master.bk || tmp=1 
test -f ns3/master.bk.jnl || tmp=1 

if test $tmp != 0 ; then echo "I:failed"; fi
status=`expr $status + $tmp`

n=`expr $n + 1`
echo "I:testing ixfr-from-differences master; (slave zone)"
tmp=0

$DIG $DIGOPTS slave. \
	@10.53.0.6 axfr -p 5300 > dig.out.ns6 || tmp=1
grep "^;" dig.out.ns6

$DIG $DIGOPTS slave. \
	@10.53.0.1 axfr -p 5300 > dig.out.ns1 || tmp=1
grep "^;" dig.out.ns1

$PERL ../digcomp.pl dig.out.ns6 dig.out.ns1 || tmp=1

# ns6 has a journal iff it received an IXFR.
test -f ns6/slave.bk || tmp=1 
test -f ns6/slave.bk.jnl && tmp=1 

if test $tmp != 0 ; then echo "I:failed"; fi
status=`expr $status + $tmp`

n=`expr $n + 1`
echo "I:testing ixfr-from-differences slave; (master zone)"
tmp=0

# ns7 has a journal iff it generates an IXFR.
test -f ns7/master2.db || tmp=1 
test -f ns7/master2.db.jnl && tmp=1 

if test $tmp != 0 ; then echo "I:failed"; fi
status=`expr $status + $tmp`

n=`expr $n + 1`
echo "I:testing ixfr-from-differences slave; (slave zone)"
tmp=0

$DIG $DIGOPTS slave. \
	@10.53.0.1 axfr -p 5300 > dig.out.ns1 || tmp=1
grep "^;" dig.out.ns1

$DIG $DIGOPTS slave. \
	@10.53.0.7 axfr -p 5300 > dig.out.ns7 || tmp=1
grep "^;" dig.out.ns1

$PERL ../digcomp.pl dig.out.ns7 dig.out.ns1 || tmp=1

# ns7 has a journal iff it generates an IXFR.
test -f ns7/slave.bk || tmp=1 
test -f ns7/slave.bk.jnl || tmp=1 

if test $tmp != 0 ; then echo "I:failed"; fi
status=`expr $status + $tmp`

echo "I:check that a multi-message uncompressable zone transfers"
$DIG axfr . -p 5300 @10.53.0.4 | grep SOA > axfr.out
if test `wc -l < axfr.out` != 2
then
	 echo "I:failed"
	 status=`expr $status + 1`
fi

# now we test transfers with assorted TSIG glitches
DIGCMD="$DIG $DIGOPTS @10.53.0.4 -p 5300"
SENDCMD="$PERL ../send.pl 10.53.0.5 5301"
RNDCCMD="$RNDC -s 10.53.0.4 -p 9953 -c ../common/rndc.conf"

echo "I:testing that incorrectly signed transfers will fail..."
echo "I:initial correctly-signed transfer should succeed"

$SENDCMD < ans5/goodaxfr
sleep 1

# Initially, ns4 is not authoritative for anything.
# Now that ans is up and running with the right data, we make ns4
# a slave for nil.

cat <<EOF >>ns4/named.conf
zone "nil" {
	type slave;
	file "nil.db";
	masters { 10.53.0.5 key tsig_key; };
};
EOF

cur=`awk 'END {print NR}' ns4/named.run`

$RNDCCMD reload | sed 's/^/I:ns4 /'

for i in 0 1 2 3 4 5 6 7 8 9
do
	$DIGCMD nil. SOA > dig.out.ns4
	grep SOA dig.out.ns4 > /dev/null && break
	sleep 1
done

sed -n "$cur,\$p" < ns4/named.run | grep "Transfer status: success" > /dev/null || {
    echo "I: failed: expected status was not logged"
    status=1
}
cur=`awk 'END {print NR}' ns4/named.run`

$DIGCMD nil. TXT | grep 'initial AXFR' >/dev/null || {
    echo "I:failed"
    status=1
}

echo "I:unsigned transfer"

$SENDCMD < ans5/unsigned
sleep 1

$RNDCCMD retransfer nil | sed 's/^/I:ns4 /'

sleep 2

sed -n "$cur,\$p" < ns4/named.run | grep "Transfer status: expected a TSIG or SIG(0)" > /dev/null || {
    echo "I: failed: expected status was not logged"
    status=1
}
cur=`awk 'END {print NR}' ns4/named.run`

$DIGCMD nil. TXT | grep 'unsigned AXFR' >/dev/null && {
    echo "I:failed"
    status=1
}

echo "I:bad keydata"

$SENDCMD < ans5/badkeydata
sleep 1

$RNDCCMD retransfer nil | sed 's/^/I:ns4 /'

sleep 2

sed -n "$cur,\$p" < ns4/named.run | grep "Transfer status: tsig verify failure" > /dev/null || {
    echo "I: failed: expected status was not logged"
    status=1
}
cur=`awk 'END {print NR}' ns4/named.run`

$DIGCMD nil. TXT | grep 'bad keydata AXFR' >/dev/null && {
    echo "I:failed"
    status=1
}

echo "I:partially-signed transfer"

$SENDCMD < ans5/partial
sleep 1

$RNDCCMD retransfer nil | sed 's/^/I:ns4 /'

sleep 2

sed -n "$cur,\$p" < ns4/named.run | grep "Transfer status: expected a TSIG or SIG(0)" > /dev/null || {
    echo "I: failed: expected status was not logged"
    status=1
}
cur=`awk 'END {print NR}' ns4/named.run`

$DIGCMD nil. TXT | grep 'partially signed AXFR' >/dev/null && {
    echo "I:failed"
    status=1
}

echo "I:unknown key"

$SENDCMD < ans5/unknownkey
sleep 1

$RNDCCMD retransfer nil | sed 's/^/I:ns4 /'

sleep 2

sed -n "$cur,\$p" < ns4/named.run | grep "tsig key 'tsig_key': key name and algorithm do not match" > /dev/null || {
    echo "I: failed: expected status was not logged"
    status=1
}
cur=`awk 'END {print NR}' ns4/named.run`

$DIGCMD nil. TXT | grep 'unknown key AXFR' >/dev/null && {
    echo "I:failed"
    status=1
}

echo "I:incorrect key"

$SENDCMD < ans5/wrongkey
sleep 1

$RNDCCMD retransfer nil | sed 's/^/I:ns4 /'

sleep 2

sed -n "$cur,\$p" < ns4/named.run | grep "tsig key 'tsig_key': key name and algorithm do not match" > /dev/null || {
    echo "I: failed: expected status was not logged"
    status=1
}
cur=`awk 'END {print NR}' ns4/named.run`

$DIGCMD nil. TXT | grep 'incorrect key AXFR' >/dev/null && {
    echo "I:failed"
    status=1
}

n=`expr $n + 1`
echo "I:check that we ask for and get a EDNS EXPIRE response ($n)"
# force a refresh query
$RNDC -s 10.53.0.7 -p 9953 -c ../common/rndc.conf refresh edns-expire 2>&1 | sed 's/^/I:ns7 /'
sleep 10

# there may be multiple log entries so get the last one.
expire=`awk '/edns-expire\/IN: got EDNS EXPIRE of/ { x=$9 } END { print x }' ns7/named.run`
test ${expire:-0} -gt 0 -a ${expire:-0} -lt 1814400 || {
    echo "I:failed (expire=${expire:-0})"
    status=1
}

n=`expr $n + 1`
echo "I:test smaller transfer TCP message size ($n)"
$DIG $DIGOPTS example. @10.53.0.8 axfr -p 5300 \
	-y key1.:1234abcd8765 > dig.out.msgsize || status=1

$DOS2UNIX dig.out.msgsize >/dev/null

bytes=`wc -c < dig.out.msgsize`
if [ $bytes -ne 459357 ]; then
	echo "I:failed axfr size check"
	status=1
fi

num_messages=`cat ns8/named.run | grep "sending TCP message of" | wc -l`
if [ $num_messages -le 300 ]; then
	echo "I:failed transfer message count check"
	status=1
fi

n=`expr $n + 1`
echo "I:test mapped zone with out of zone data ($n)"
tmp=0
$DIG -p 5300 txt mapped @10.53.0.3 > dig.out.1.$n
grep "status: NOERROR," dig.out.1.$n > /dev/null || tmp=1
$PERL $SYSTEMTESTTOP/stop.pl . ns3
$PERL $SYSTEMTESTTOP/start.pl --noclean --restart . ns3
$DIG -p 5300 txt mapped @10.53.0.3 > dig.out.2.$n
grep "status: NOERROR," dig.out.2.$n > /dev/null || tmp=1
$DIG -p 5300 axfr mapped @10.53.0.3 > dig.out.3.$n
$PERL ../digcomp.pl knowngood.mapped dig.out.3.$n || tmp=1
if test $tmp != 0 ; then echo "I:failed"; fi
status=`expr $status + $tmp`

echo "I:exit status: $status"
[ $status -eq 0 ] || exit 1
