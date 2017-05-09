#!/bin/bash
VERSION=$1
TEMPBSE=/tmp/tapasco_temp
TEMPDIR=$TEMPBSE/tapasco/$VERSION
ZIP=Tapasco-$1.tar.xz
CURRDIR=`pwd`
cd $TAPASCO_HOME && cat Release-$1 | xargs tar cvJf $ZIP && pushd /tmp && mkdir -p $TEMPDIR && cd $TEMPDIR && tar xvJf $CURRDIR/$ZIP && cd ../.. && rm $CURRDIR/$ZIP && tar cvJf $CURRDIR/$ZIP tapasco && cd .. && rm -rf $TMPBSE && popd

