#!/bin/bash

sudo podman run --privileged --network host -it --rm --name frr --volume "${PWD}/frr:/etc/frr" frrouting/frr:latest
