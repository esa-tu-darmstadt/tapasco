#!/bin/bash
VERSION=$1
TEMPBSE=/tmp/tpc_temp
TEMPDIR=$TEMPBSE/threadpoolcomposer/$VERSION
ZIP=ThreadPoolComposer-$1.tar.xz
CURRDIR=`pwd`
cd $TPC_HOME && cat Release-$1 | xargs tar cvJf $ZIP && pushd /tmp && mkdir -p $TEMPDIR && cd $TEMPDIR && tar xvJf $CURRDIR/$ZIP && cd ../.. && rm $CURRDIR/$ZIP && tar cvJf $CURRDIR/$ZIP threadpoolcomposer && cd .. && rm -rf $TMPBSE && popd

