#!/bin/bash

[ ! -d "lounge" ] && git clone https://github.com/thelounge/lounge.git

[ -d "lounge" ] && pushd "lounge" && git pull && popd

pushd "lounge"

	docker build --tag=lounge-img .

popd
