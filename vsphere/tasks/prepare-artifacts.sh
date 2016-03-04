#!/usr/bin/env bash

set -e

if [ "$download" == "true" ] then
  : ${bosh_init_version:?}
  : ${bosh_init_sha1:?}
  : ${bosh_version:?}
  : ${bosh_sha1:?}
  : ${bosh_cpi_version:?}
  : ${bosh_cpi_sha1:?}
  : ${stemcell_version:?}
  : ${stemcell_sha1:?}

  download \
    http://bosh.io/d/github.com/cloudfoundry-incubator/bosh-vsphere-cpi-release?v=${bosh_cpi_version} \
    bosh-cpi-release.tgz
  echo "${bosh_cpi_sha1} bosh-cpi-release.tgz" | sha1sum -c -

  download \
    https://bosh.cloudfoundry.org/d/github.com/cloudfoundry/bosh?v=${bosh_version} \
    bosh-release.tgz
  echo "${bosh_sha1} bosh-release.tgz" | sha1sum -c -

  download \
    https://bosh.io/d/stemcells/bosh-vsphere-esxi-ubuntu-trusty-go_agent?v=${stemcell_version} \
    stemcell.tgz
  echo "${stemcell_sha1} stemcell.tgz" | sha1sum -c -

  download \
    https://s3.amazonaws.com/bosh-init-artifacts/bosh-init-${bosh_init_version}-linux-amd64 \
    bosh-init
  echo "${bosh_init_sha1} bosh-init" | sha1sum -c -

  mv bosh-cpi-release.tgz releases/
  mv bosh-release.tgz     releases/
  mv stemcell.tgz         stemcells/
  mv bosh-init            executables/
else
  cp bosh-cpi-release/*.tgz releases/bosh-cpi-release.tgz
  cp bosh-release/*.tgz releases/bosh-release.tgz
  cp stemcell/*.tgz stemcells/stemcell.tgz
  cp bosh-init/bosh-init* executables/bosh-init
fi
