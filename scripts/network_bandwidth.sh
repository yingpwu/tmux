#!/bin/bash
RXB=0
TXB=0
for rxbytes in /sys/class/net/*/statistics/rx_bytes ; do
  let RXB+=$(<$rxbytes)
done
for txbytes in /sys/class/net/*/statistics/tx_bytes ; do
  let TXB+=$(<$txbytes)
done

sleep 2

RXBN=0
TXBN=0
for rxbytes in /sys/class/net/*/statistics/rx_bytes ; do
  let RXBN+=$(<$rxbytes)
done
for txbytes in /sys/class/net/*/statistics/tx_bytes ; do
  let TXBN+=$(<$txbytes)
done
#divide by two for the period, multiply by 10 to allow a correct decimal place
RXDIF=$(echo $(((RXBN - RXB) * 5  )))
TXDIF=$(echo $(((TXBN - TXB) * 5  )))

SPEEDU="^B/s"
SPEEDD="vB/s"
if [ $RXDIF -ge 10240 ]; then
	SPEEDD="vKi/s"
	RXDIF=$(echo $((RXDIF / 10240 )) )
fi

if [ $TXDIF -ge 10240 ]; then
	SPEEDU="vKi/s"
	TXDIF=$(echo $((TXDIF / 10240 )) )
fi

if [ $RXDIF -ge 10240 ]; then
	SPEEDD="vMi/s"
	RXDIF=$(echo $((RXDIF / 10240 )) )
fi

if [ $TXDIF -ge 10240 ]; then
	SPEEDU="vMi/s"
	TXDIF=$(echo $((TXDIF / 10240 )) )
fi

if [ $RXDIF -ge 10240 ]; then
	SPEEDD="vGi/s"
	RXDIF=$(echo $((RXDIF / 10240 )) )
fi

if [ $TXDIF -ge 10240 ]; then
	SPEEDU="vGi/s"
	TXDIF=$(echo $((TXDIF / 10240 )) )
fi

RXDIFF=$(($RXDIF % 10 ))
RXDIFI=$(( $RXDIF / 10 ))
RXDIF="$RXDIFI"

if [ $RXDIFF -ne 0 ]; then
	RXDIF=$( echo  "$RXDIFI.$RXDIFF" )
fi

TXDIFF=$(($TXDIF % 10 ))
TXDIFI=$(( $TXDIF / 10 ))
TXDIF="$TXDIFI"

if [ $TXDIFF -ne 0 ]; then
	TXDIF=$( echo  "$TXDIFI.$TXDIFF" )
fi


echo "$RXDIF $SPEEDD $TXDIF $SPEEDU"
